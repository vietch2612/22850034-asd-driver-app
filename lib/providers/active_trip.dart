// 22850034 ASD Customer App Flutter

import 'package:customer_app/types/driver_info.dart';
import 'package:flutter/material.dart';
import 'package:customer_app/types/trip.dart';
import 'package:customer_app/servivces/map_service.dart';
import 'package:customer_app/types/resolved_address.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import 'dart:convert';

import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter_dotenv/flutter_dotenv.dart';

final backendHost = dotenv.env['BACKEND_HOST'];

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

  void openSocketForNewTrip(TripDataEntity trip) {
    final tripId = trip.tripId;
    final socket = io.io('$backendHost', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    /** Init the trip */
    socket.on('connect', (_) {
      final message = {"tripId": tripId};
      socket.emit('submitted', jsonEncode(message));

      logger.i('[$tripId] Started a new trip!');
    });

    socket.on('message', (data) {
      logger.i('Received message: $data');
    });

    /** The server has received the request */
    socket.on('finding_driver', (data) {
      logger.i('[$data] The server has received! Finding driver!');
      notifyListeners();
    });

    // Driver sends
    socket.on('driving', (data) {
      logger.i('[$tripId] Driving!');
      setTripStatus(ExTripStatus.driving);

      final DriverInfo driverInfo =
          DriverInfo.fromJson(jsonDecode(data)['driver']);

      activeTrip?.driverInfo = driverInfo;

      updateMapPoyline(activeTrip!.from, driverInfo.currentLocation);
      taxiMarkerLatLng = LatLng(driverInfo.currentLocation.location.lat,
          driverInfo.currentLocation.location.lng);

      mapViewBoundsCallback?.call(
        taxiMarkerLatLng!,
        activeTrip!.from.toLatLng,
      );

      notifyListeners();
    });

    socket.on('completed', (data) {
      logger.i('[$tripId] Received completed:');
      setTripStatus(ExTripStatus.completed);
      notifyListeners();
      socket.disconnect();
    });

    socket.on('disconnect', (_) {
      logger.i('[$tripId] Socket disconnected');
    });
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
    updateMapPoyline(await MapHelper.getCurrentLocation(), activeTrip!.from);

    // TODO
    // openSocketForNewTrip(trip);
  }

  void updateMapPoyline(ResolvedAddress from, ResolvedAddress to) async {
    var newPolyline = await MapHelper.getPolyline(from, to);
    activeTrip?.polyline = newPolyline;
    notifyListeners();
  }

  static TripProvider of(BuildContext context, {bool listen = true}) =>
      Provider.of<TripProvider>(context, listen: listen);
}
