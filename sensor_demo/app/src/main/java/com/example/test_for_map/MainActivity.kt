package com.example.test_for_map // 1. 본인의 패키지 이름인지 확인

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.Location
import android.os.Bundle
import android.os.Looper
import androidx.preference.PreferenceManager
import android.util.Log
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import org.osmdroid.config.Configuration
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.mylocation.GpsMyLocationProvider
import org.osmdroid.views.overlay.mylocation.MyLocationNewOverlay
import java.util.ArrayList

class MainActivity : AppCompatActivity(), SensorEventListener {

    // 1. companion object (Java의 static final 상수와 비슷함)
    companion object {
        private const val TAG = "MainActivity"
        private const val LOCATION_PERMISSION_REQUEST_CODE = 1
    }

    // 2. 클래스 멤버 변수 선언 (lateinit var 또는 var/val)
    private lateinit var mMapView: MapView
    private var mLocationOverlay: MyLocationNewOverlay? = null // '내 위치' 오버레이

    // Google Location
    private lateinit var mFusedLocationClient: FusedLocationProviderClient
    private lateinit var locationCallback: LocationCallback
    private lateinit var locationRequest: LocationRequest

    // Sensors
    private lateinit var mSensorManager: SensorManager
    private var mAccelerometer: Sensor? = null
    private var mGyroscope: Sensor? = null
    private var isSensorListenerRegistered = false // 센서 리스너 등록 상태 추적

    // 히트맵 오버레이
    private lateinit var mHeatmapOverlay: HeatmapOverlay
    
    // 데이터 클래스: 위치와 울퉁불퉁함 정도를 함께 저장
    data class BumpData(val geoPoint: GeoPoint, val bumpiness: Double)
    private val mBumpDataList = ArrayList<BumpData>() // 울퉁불퉁함 데이터 리스트
    
    // 성능 최적화: 히트맵 갱신 제어
    private var pendingHeatmapUpdate = false
    private val heatmapUpdateHandler = android.os.Handler(android.os.Looper.getMainLooper())
    private val heatmapUpdateRunnable = Runnable {
        if (pendingHeatmapUpdate) {
            mMapView.invalidate()
            pendingHeatmapUpdate = false
        }
    }

    // 울퉁불퉁함 계산을 위한 변수
    private var gravityX: Float = 0.0f
    private var gravityY: Float = 0.0f
    private var gravityZ: Float = 0.0f
    private val ALPHA = 0.8f // 저역 통과 필터 계수
    private var currentAggregatedBumpiness: Double = 0.0
    
    // 자이로센서 데이터 (각속도)
    private var gyroX: Float = 0.0f
    private var gyroY: Float = 0.0f
    private var gyroZ: Float = 0.0f

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // (중요!) osmdroid 초기화. setContentView() 보다 먼저 호출되어야 함
        val ctx: Context = applicationContext
        Configuration.getInstance().load(ctx, PreferenceManager.getDefaultSharedPreferences(ctx))
        Configuration.getInstance().setUserAgentValue(packageName)

        // 3. 레이아웃 설정
        // (참고: enableEdgeToEdge() 및 ViewCompat 리스너는 지도 앱에서는
        //  복잡성을 야기할 수 있으므로, 여기서는 사용하지 않고 바로 setContentView를 호출합니다.)
        setContentView(R.layout.activity_main)

        // 4. MapView 초기화
        mMapView = findViewById(R.id.mapview)
        mMapView.setTileSource(TileSourceFactory.MAPNIK) // 기본 OSM 타일 소스
        mMapView.setMultiTouchControls(true) // 멀티터치 줌
        mMapView.controller.setZoom(15.0) // 초기 줌 레벨

        // 5. Sensor Manager 초기화
        mSensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        mAccelerometer = mSensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        mGyroscope = mSensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE)

        // 6. Location Client 초기화
        mFusedLocationClient = LocationServices.getFusedLocationProviderClient(this)

        // 7. GPS 위치 업데이트 주기 설정
        createLocationRequest()

        // 8. GPS 위치 콜백 정의 (코틀린 'object' 사용)
        locationCallback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                super.onLocationResult(locationResult)
                val location: Location? = locationResult.lastLocation
                if (location != null) {
                    // osmdroid용 GeoPoint로 변환
                    val currentGeoPoint = GeoPoint(location.latitude, location.longitude)

                    // 위치 정확도 필터링 (정확도가 낮은 위치는 무시)
                    if (location.accuracy > 20.0f) { // 정확도가 20m보다 나쁘면 무시
                        Log.w(TAG, "위치 정확도가 낮아 무시: ${location.accuracy}m")
                        currentAggregatedBumpiness = 0.0
                        return@onLocationResult
                    }
                    
                    if (currentAggregatedBumpiness > 0.1) {
                        // 울퉁불퉁함 데이터 저장
                        val bumpData = BumpData(currentGeoPoint, currentAggregatedBumpiness)
                        mBumpDataList.add(bumpData)
                        
                        // 히트맵 오버레이에 데이터 추가
                        val weightedPoint = HeatmapOverlay.WeightedPoint(
                            currentGeoPoint,
                            currentAggregatedBumpiness
                        )
                        mHeatmapOverlay.addPoint(weightedPoint)
                        
                        // 성능 최적화: 히트맵 갱신을 지연 (배치 업데이트)
                        if (!pendingHeatmapUpdate) {
                            pendingHeatmapUpdate = true
                            heatmapUpdateHandler.postDelayed(heatmapUpdateRunnable, 200) // 200ms 지연
                        }
                    }

                    // 누적 충격량 초기화
                    currentAggregatedBumpiness = 0.0

                    // (선택사항) 지도를 현재 위치로 이동 (처음 한 번만)
                    if (mBumpDataList.size == 1) { // 첫 데이터 수신 시
                        mMapView.controller.animateTo(currentGeoPoint)
                    }
                }
            }
        }

        // 9. 히트맵 오버레이 초기화
        mHeatmapOverlay = HeatmapOverlay(mMapView)
        mHeatmapOverlay.radius = 80.0 // 히트맵 반경 (픽셀)
        mHeatmapOverlay.opacity = 0.6f // 투명도
        mMapView.overlays.add(mHeatmapOverlay)

        // 10. 위치 권한 확인
        checkLocationPermission()
    }

    // --- 1. 권한 처리 ---

    private fun checkLocationPermission() {
        if (ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.ACCESS_FINE_LOCATION
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            // 권한이 없으면 요청
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.ACCESS_FINE_LOCATION),
                LOCATION_PERMISSION_REQUEST_CODE
            )
        } else {
            // 권한이 있으면 위치 및 센서 업데이트 시작
            startLocationAndSensorUpdates()
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == LOCATION_PERMISSION_REQUEST_CODE) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                // 사용자가 권한을 승인한 경우
                startLocationAndSensorUpdates()
            } else {
                // 사용자가 권한을 거부한 경우
                Toast.makeText(this, "위치 권한이 필요합니다.", Toast.LENGTH_LONG).show()
            }
        }
    }

    // --- 2. 위치 및 센서 업데이트 시작/중지 (라이프사이클) ---

    private fun startLocationAndSensorUpdates() {
        Log.d(TAG, "업데이트 시작")
        if (ActivityCompat.checkSelfPermission(
                this,
                Manifest.permission.ACCESS_FINE_LOCATION
            ) != PackageManager.PERMISSION_GRANTED && ActivityCompat.checkSelfPermission(
                this,
                Manifest.permission.ACCESS_COARSE_LOCATION
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            // 권한이 없으면(혹은 다시 확인) return
            Log.d(TAG, "권한이 없어 업데이트 시작 불가")
            return
        }

        // GPS 업데이트 시작
        mFusedLocationClient.requestLocationUpdates(locationRequest, locationCallback, Looper.getMainLooper())

        // 가속도 센서 및 자이로센서 리스너 등록 (null 체크 및 중복 등록 방지)
        if (!isSensorListenerRegistered) {
            var sensorRegistered = false
            
            // 성능 최적화: SENSOR_DELAY_GAME 사용 (SENSOR_DELAY_UI보다 덜 자주 업데이트)
            if (mAccelerometer != null) {
                mSensorManager.registerListener(this, mAccelerometer, SensorManager.SENSOR_DELAY_GAME)
                sensorRegistered = true
                Log.d(TAG, "가속도 센서 리스너 등록 완료 (SENSOR_DELAY_GAME)")
            } else {
                Log.w(TAG, "가속도 센서를 사용할 수 없습니다")
            }
            
            if (mGyroscope != null) {
                mSensorManager.registerListener(this, mGyroscope, SensorManager.SENSOR_DELAY_GAME)
                sensorRegistered = true
                Log.d(TAG, "자이로센서 리스너 등록 완료 (SENSOR_DELAY_GAME)")
            } else {
                Log.w(TAG, "자이로센서를 사용할 수 없습니다")
            }
            
            if (sensorRegistered) {
                isSensorListenerRegistered = true
            } else {
                Toast.makeText(this, "센서를 사용할 수 없습니다", Toast.LENGTH_SHORT).show()
            }
        }

        // '내 위치' 오버레이 설정 (중복 추가 방지)
        if (mLocationOverlay == null) {
            mLocationOverlay = MyLocationNewOverlay(GpsMyLocationProvider(this), mMapView)
            mLocationOverlay?.enableMyLocation() // 내 위치 찾기 활성화
            mMapView.overlays.add(mLocationOverlay) // 지도에 오버레이 추가
        }
    }

    override fun onPause() {
        super.onPause()
        // (중요!) osmdroid 라이프사이클
        mMapView.onPause()
        Log.d(TAG, "업데이트 일시정지")
        mFusedLocationClient.removeLocationUpdates(locationCallback)
        
        // 성능 최적화: 대기 중인 히트맵 업데이트 취소
        heatmapUpdateHandler.removeCallbacks(heatmapUpdateRunnable)
        pendingHeatmapUpdate = false
        
        // 센서 리스너 해제 (등록된 경우에만)
        if (isSensorListenerRegistered) {
            mSensorManager.unregisterListener(this)
            isSensorListenerRegistered = false
            Log.d(TAG, "센서 리스너 해제 완료")
        }

        // '내 위치' 오버레이도 중지 (코틀린 null-safe call)
        mLocationOverlay?.disableMyLocation()
    }

    override fun onResume() {
        super.onResume()
        // (중요!) osmdroid 라이프사이클
        mMapView.onResume()

        if (ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.ACCESS_FINE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED
        ) {
            startLocationAndSensorUpdates()
        }
    }

    // --- 3. 울퉁불퉁함 계산 (Sensor) ---

    override fun onSensorChanged(event: SensorEvent?) {
        when (event?.sensor?.type) {
            Sensor.TYPE_ACCELEROMETER -> {
                val x = event.values[0]
                val y = event.values[1]
                val z = event.values[2]

                // 저역 통과 필터로 중력 추정 (하이패스 필터를 위한 기저선)
                gravityX = ALPHA * gravityX + (1 - ALPHA) * x
                gravityY = ALPHA * gravityY + (1 - ALPHA) * y
                gravityZ = ALPHA * gravityZ + (1 - ALPHA) * z

                // 중력을 제거하여 순수 가속도만 추출
                val linearX = x - gravityX
                val linearY = y - gravityY
                val linearZ = z - gravityZ

                // 3D 가속도 벡터의 크기 계산 (진동 강도)
                val accelerationMagnitude = kotlin.math.sqrt(
                    linearX * linearX + linearY * linearY + linearZ * linearZ
                )

                // GPS가 업데이트 될 때까지 계속 누적
                currentAggregatedBumpiness += accelerationMagnitude
            }
            
            Sensor.TYPE_GYROSCOPE -> {
                // 자이로센서 데이터 수집 (각속도)
                gyroX = event.values[0]
                gyroY = event.values[1]
                gyroZ = event.values[2]

                // 각속도의 크기 계산 (회전 진동)
                val angularVelocityMagnitude = kotlin.math.sqrt(
                    gyroX * gyroX + gyroY * gyroY + gyroZ * gyroZ
                )

                // 각속도도 울퉁불퉁함 지표에 반영 (가중치 0.3)
                currentAggregatedBumpiness += angularVelocityMagnitude * 0.3
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // 센서 정확도 변경 (지금은 무시)
    }

    // --- 4. 히트맵 관리 (Map) ---
    // 히트맵은 HeatmapOverlay 클래스에서 자동으로 처리됨

    // --- 5. 기타 헬퍼 ---

    // GPS 요청 옵션 설정 (정확도 개선)
    private fun createLocationRequest() {
        // 코틀린 스타일 'apply'로 빌더 설정
        locationRequest = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 2000).apply {
            setWaitForAccurateLocation(true) // 정확한 위치를 기다림
            setMinUpdateIntervalMillis(1000) // 최소 1초 (더 빠른 업데이트)
            setMaxUpdateDelayMillis(3000) // 최대 3초
            setMaxUpdateAgeMillis(5000) // 위치 데이터 최대 나이 5초
        }.build()
    }
}