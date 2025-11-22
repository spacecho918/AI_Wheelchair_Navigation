package com.example.test_for_map

import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RadialGradient
import android.graphics.Shader
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.Projection
import org.osmdroid.views.overlay.Overlay
import kotlin.math.pow
import kotlin.math.sqrt

/**
 * 커스텀 히트맵 오버레이 클래스
 * 울퉁불퉁함 데이터를 히트맵으로 시각화
 */
class HeatmapOverlay(private val mapView: MapView) : Overlay() {
    
    // 히트맵 데이터: 위치와 가중치(울퉁불퉁함 정도)
    data class WeightedPoint(val geoPoint: GeoPoint, val weight: Double)
    
    private val dataPoints = mutableListOf<WeightedPoint>()
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    
    // 히트맵 설정
    var radius = 100.0 // 픽셀 단위 반경
    var opacity = 0.7f // 투명도 (0.0 ~ 1.0)
    var intensity = 1.0 // 강도 배율
    
    // 성능 최적화: 최대 데이터 포인트 수 제한
    private var maxDataPoints = 5000 // 최대 5000개 포인트만 유지
    
    // 색상 그라데이션 (녹색 -> 노란색 -> 빨간색)
    private val colors = intArrayOf(
        Color.argb(0, 0, 255, 0),      // 투명 녹색 (중앙)
        Color.argb(100, 0, 255, 0),    // 반투명 녹색
        Color.argb(150, 255, 255, 0),  // 반투명 노란색
        Color.argb(200, 255, 165, 0),  // 반투명 주황색
        Color.argb(255, 255, 0, 0)      // 불투명 빨간색 (외곽)
    )
    
    private val positions = floatArrayOf(0.0f, 0.3f, 0.6f, 0.8f, 1.0f)
    
    /**
     * 히트맵 데이터 설정
     */
    fun setData(points: List<WeightedPoint>) {
        dataPoints.clear()
        dataPoints.addAll(points)
    }
    
    /**
     * 데이터 추가 (성능 최적화: 최대 개수 제한)
     */
    fun addPoint(point: WeightedPoint) {
        dataPoints.add(point)
        
        // 최대 개수를 초과하면 오래된 데이터 제거
        if (dataPoints.size > maxDataPoints) {
            val removeCount = dataPoints.size - maxDataPoints
            dataPoints.removeAt(0) // 가장 오래된 데이터 제거
        }
    }
    
    /**
     * 여러 데이터를 한번에 추가 (배치 업데이트)
     */
    fun addPoints(points: List<WeightedPoint>) {
        dataPoints.addAll(points)
        
        // 최대 개수를 초과하면 오래된 데이터 제거
        while (dataPoints.size > maxDataPoints) {
            dataPoints.removeAt(0)
        }
    }
    
    /**
     * 모든 데이터 제거
     */
    fun clear() {
        dataPoints.clear()
    }
    
    override fun draw(canvas: Canvas, mapView: MapView, shadow: Boolean) {
        if (shadow || dataPoints.isEmpty()) {
            return
        }
        
        val projection: Projection = mapView.projection
        val screenRect = projection.screenRect
        
        // 화면에 보이는 영역의 데이터만 처리 (성능 최적화)
        val visiblePoints = dataPoints.filter { point ->
            val screenPoint = projection.toPixels(point.geoPoint, null)
            // 화면 영역을 약간 확장하여 경계 근처도 포함
            val expandedRect = android.graphics.Rect(
                screenRect.left - 100,
                screenRect.top - 100,
                screenRect.right + 100,
                screenRect.bottom + 100
            )
            expandedRect.contains(screenPoint.x.toInt(), screenPoint.y.toInt())
        }
        
        if (visiblePoints.isEmpty()) {
            return
        }
        
        // 성능 최적화: 너무 많은 점이 있으면 샘플링
        val pointsToRender = if (visiblePoints.size > 500) {
            // 500개 이상이면 샘플링 (매 N번째 점만 사용)
            val step = visiblePoints.size / 500
            visiblePoints.filterIndexed { index, _ -> index % step == 0 }
        } else {
            visiblePoints
        }
        
        // 가중치 범위 계산 (정규화를 위해)
        val maxWeight = pointsToRender.maxOfOrNull { it.weight } ?: 1.0
        val minWeight = pointsToRender.minOfOrNull { it.weight } ?: 0.0
        val weightRange = (maxWeight - minWeight).coerceAtLeast(0.1)
        
        // 각 데이터 포인트에 대해 히트맵 그리기
        for (point in pointsToRender) {
            val screenPoint = projection.toPixels(point.geoPoint, null)
            
            // 정규화된 가중치 (0.0 ~ 1.0)
            val normalizedWeight = ((point.weight - minWeight) / weightRange).coerceIn(0.0, 1.0)
            
            // 가중치에 따라 반경 조절
            val pointRadius = radius * (0.5 + normalizedWeight * 0.5)
            
            // 그라데이션 생성
            val gradient = RadialGradient(
                screenPoint.x.toFloat(),
                screenPoint.y.toFloat(),
                pointRadius.toFloat(),
                colors,
                positions,
                Shader.TileMode.CLAMP
            )
            
            paint.shader = gradient
            paint.alpha = (opacity * 255).toInt()
            
            // 원형 히트맵 그리기
            canvas.drawCircle(
                screenPoint.x.toFloat(),
                screenPoint.y.toFloat(),
                pointRadius.toFloat(),
                paint
            )
        }
        
        paint.shader = null
    }
}

