import 'dart:math';

import 'package:customer_app/providers/active_trip.dart';
import 'package:customer_app/types/resolved_address.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_webservice/directions.dart' as dir;
import 'package:customer_app/api/google_api.dart';
import 'package:google_maps_webservice/places.dart';

const double thresholdDistance = 0.05;

class MapHelper {
  static Future<Polyline> getPolyline(
      ResolvedAddress? from, ResolvedAddress? to) async {
    const Polyline temp = Polyline(
      polylineId: PolylineId('polyline-1'),
      width: 5,
      color: Colors.blue,
      points: [],
    );
    if (from == null || to == null) {
      return temp;
    }

    dir.DirectionsResponse response =
        await apiDirections.directionsWithLocation(from.location, to.location);

    if (!response.isOkay) {
      final error =
          'Directions API error. Status: ${response.status} ${response.errorMessage ?? ""}';
      logger.e(error);
    }

    final polylinePoints = createPolylinePointsFromDirections(response);

    if (polylinePoints == null) {
      return temp;
    }

    return Polyline(
      polylineId: const PolylineId('polyline-1'),
      width: 5,
      color: Colors.black,
      points: polylinePoints,
    );
  }

  static void moveCameraToBounds({
    required GoogleMapController controller,
    required LatLngBounds bounds,
    double padding = 30.0,
  }) {
    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        bounds,
        padding,
      ),
    );
  }

  static Future<ResolvedAddress> getCurrentLocation() async {
    final cp = await Geolocator.getCurrentPosition();
    return ResolvedAddress(
        location: Location(lat: cp.latitude, lng: cp.longitude),
        mainText: "mainText",
        secondaryText: "secondaryText");
  }

  static double calculateHaversineDistance(Location from, Location to) {
    const double earthRadius = 6371.0; // Earth's radius in kilometers

    double degreesToRadians(double degrees) {
      return degrees * (pi / 180.0);
    }

    double dLat = degreesToRadians(to.lat - from.lat);
    double dLng = degreesToRadians(to.lng - from.lng);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(degreesToRadians(from.lat)) *
            cos(degreesToRadians(to.lat)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  static bool areAddressesClose(ResolvedAddress from, ResolvedAddress to,
      {double thresholdDistance = thresholdDistance}) {
    double distance = calculateHaversineDistance(
      from.location,
      to.location,
    );

    logger.i("distance: ", distance);

    return distance <= thresholdDistance;
  }
}
