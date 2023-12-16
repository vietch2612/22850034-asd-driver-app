import 'package:customer_app/types/customer_info.dart';
import 'package:customer_app/types/driver_info.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'map_address.dart';

enum ExTripStatus {
  submitted, // New trip submitted
  allocated, // Driver is found
  arrived, // Driver is arrived at the passenger location
  driving, // Driver has started the trip
  completed, // Done
  cancelled, // Either the passenger or driver cancelled the trip
}

final tripStatusDescriptions = <ExTripStatus, String>{
  ExTripStatus.submitted: "Order Submitted",
  ExTripStatus.allocated: "Driver found",
  ExTripStatus.arrived: "Driver arrived",
  ExTripStatus.driving: "Driving...",
  ExTripStatus.completed: "Order completed",
  ExTripStatus.cancelled: "Order cancelled",
};

bool tripIsFinished(ExTripStatus status) =>
    [ExTripStatus.completed, ExTripStatus.cancelled].contains(status);

String getTripStatusDescription(ExTripStatus status) =>
    tripStatusDescriptions[status] ?? status.toString();

class TripDataEntity {
  int? tripId;
  final MapAddress from;
  final MapAddress to;
  Polyline polyline;
  final int distanceMeters;
  final String distanceText;
  ExTripStatus status;
  LatLngBounds mapLatLngBounds;
  CameraPosition? cameraPosition;
  DriverInfo? driverInfo;
  CustomerInfo customerInfo;
  int fare;

  TripDataEntity({
    this.tripId,
    required this.from,
    required this.to,
    required this.polyline,
    required this.distanceMeters,
    required this.distanceText,
    required this.customerInfo,
    required this.fare,
    required this.mapLatLngBounds,
    this.driverInfo,
    this.cameraPosition,
    this.status = ExTripStatus.submitted,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': tripId,
      'driver': {'id': driverInfo?.id},
      'driverLocation': {
        'lat': driverInfo?.currentLocation.location.lat,
        'long': driverInfo?.currentLocation.location.lng,
      }
    };
  }
}
