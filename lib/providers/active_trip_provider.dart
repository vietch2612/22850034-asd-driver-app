import 'package:flutter/material.dart';
import 'package:customer_app/types/trip.dart';
import 'package:customer_app/servivces/map_service.dart';
import 'package:customer_app/types/map_address.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'dart:async';

var logger = Logger(
  printer: PrettyPrinter(
      methodCount: 0, // Number of method calls to be displayed
      errorMethodCount: 8, // Number of method calls if stacktrace is provided
      lineLength: 120, // Width of the output
      colors: true, // Colorful log messages
      printEmojis: false, // Print an emoji for each log message
      printTime: false // Should each log print contain a timestamp
      ),
);

typedef MapViewBoundsCallback = void Function(
    LatLng driverLocation, LatLng passengerLocation);

class TripProvider with ChangeNotifier {
  MapViewBoundsCallback? mapViewBoundsCallback;

  void setMapViewBoundsCallback(MapViewBoundsCallback callback) {
    mapViewBoundsCallback = callback;
  }

  ExTripStatus get currentTripStatus {
    return activeTrip?.status ?? ExTripStatus.allocated;
  }

  TripDataEntity? activeTrip;

  bool get isActive => activeTrip != null;

  Timer? allocatedStateTimer;
  Timer? arrivedStateTimer;
  Timer? drivingStateTimer;
  Timer? completedStateTimer;
  Timer? drivingProgressTimer;

  LatLng? taxiMarkerLatLng;

  LatLng getTaxiDrivePosition(double animationValue) {
    assert(activeTrip != null);
    final points = activeTrip!.polyline.points;
    int pointIndex = ((points.length - 1) * animationValue).round();
    return points[pointIndex];
  }

  void stopTripWorkflow() {
    for (var t in [
      allocatedStateTimer,
      arrivedStateTimer,
      drivingStateTimer,
      completedStateTimer,
      drivingProgressTimer,
    ]) {
      t?.cancel();
    }
    taxiMarkerLatLng = null;
  }

  void setTripStatus(ExTripStatus newStatus) {
    if (activeTrip == null) return;
    if (tripIsFinished(newStatus)) stopTripWorkflow();
    activeTrip!.status = newStatus;
    notifyListeners();
  }

  void cancelTrip() => setTripStatus(ExTripStatus.cancelled);

  void deactivateTrip() {
    if (activeTrip == null) return;
    if (!tripIsFinished(activeTrip!.status)) {
      cancelTrip();
    }
    activeTrip = null;
    notifyListeners();
  }

  Future<void> activateTrip(TripDataEntity trip) async {
    stopTripWorkflow();
    activeTrip = trip;
    setTripStatus(ExTripStatus.allocated);
  }

  static TripProvider of(BuildContext context, {bool listen = true}) =>
      Provider.of<TripProvider>(context, listen: listen);
}
