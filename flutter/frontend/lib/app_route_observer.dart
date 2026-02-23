import 'package:flutter/material.dart';

/// Shared route observer for RouteAware screens (e.g. MapScreen dashboard refresh on return).
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();
