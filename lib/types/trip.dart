// 22850034 ASD Customer App Flutter

import 'package:customer_app/types/customer_info.dart';
import 'package:customer_app/types/driver_info.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_webservice/directions.dart' as dir;
import 'package:google_maps_webservice/places.dart';

import 'resolved_address.dart';

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
  String? tripId;
  final ResolvedAddress from;
  final ResolvedAddress to;
  Polyline polyline;
  final int distanceMeters;
  final String distanceText;
  ExTripStatus status;
  LatLngBounds mapLatLngBounds;
  CameraPosition? cameraPosition;
  DriverInfo? driverInfo;
  CustomerInfo customerInfo;

  TripDataEntity(
      {this.tripId,
      required this.from,
      required this.to,
      required this.polyline,
      required this.distanceMeters,
      required this.distanceText,
      required this.mapLatLngBounds,
      required this.customerInfo,
      this.driverInfo,
      this.cameraPosition,
      this.status = ExTripStatus.submitted});

  TripDataEntity tripDataEntityFromJson(Map<String, dynamic> json) {
    // Extract customer info
    CustomerInfo customerInfo = CustomerInfo.fromJson(json['customer']);

    // Extract other trip details
    return TripDataEntity(
      tripId: json['tripId'],
      from: ResolvedAddress(
        location: Location(
          lat: json['from']['location']['lat'],
          lng: json['from']['location']['lng'],
        ),
        mainText: json['from']['mainText'],
        secondaryText: json['from']['secondaryText'],
      ),
      to: ResolvedAddress(
        location: Location(
          lat: json['to']['location']['lat'],
          lng: json['to']['location']['lng'],
        ),
        mainText: json['to']['mainText'],
        secondaryText: json['to']['secondaryText'],
      ),
      polyline: Polyline(
        polylineId: PolylineId('polyline-1'),
        width: 5,
        color: Colors.blue,
        points: (json['polyline']['points'] as List<dynamic>)
            .map((point) => LatLng(point['lat'], point['lng']))
            .toList(),
      ),
      distanceMeters: json['distanceMeters'],
      distanceText: json['distanceText'],
      status: ExTripStatus.values.firstWhere(
        (e) => e.toString() == 'ExTripStatus.${json['status']}',
      ),
      mapLatLngBounds: LatLngBounds(
        northeast: LatLng(
          json['mapLatLngBounds']['northeast']['lat'],
          json['mapLatLngBounds']['northeast']['lng'],
        ),
        southwest: LatLng(
          json['mapLatLngBounds']['southwest']['lat'],
          json['mapLatLngBounds']['southwest']['lng'],
        ),
      ),
      cameraPosition: CameraPosition(
        target: LatLng(
          json['cameraPosition']['target']['lat'],
          json['cameraPosition']['target']['lng'],
        ),
        zoom: json['cameraPosition']['zoom'],
      ),
      driverInfo: driverInfo,
      customerInfo: customerInfo,
    );
  }
}
