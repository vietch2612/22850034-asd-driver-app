import 'dart:convert';

import 'package:customer_app/types/resolved_address.dart';
import 'package:google_maps_webservice/directions.dart' as dir;

class DriverInfo {
  final int id;
  final String name;
  final String licensePlate;
  final String carInfo;
  final String phoneNumber;
  final String avatarUrl;
  final int rating;
  ResolvedAddress currentLocation;

  DriverInfo(
    this.id,
    this.avatarUrl,
    this.rating,
    this.carInfo, {
    required this.phoneNumber,
    required this.name,
    required this.licensePlate,
    required this.currentLocation,
  });

  factory DriverInfo.fromJson(Map<String, dynamic> json) {
    return DriverInfo(
      json['Driver']['id'],
      json['Driver']['avatarUrl'],
      json['Driver']['rating'],
      json['Driver']['Car']['name'],
      phoneNumber: json['Driver']['phoneNumber'],
      name: json['Driver']['name'],
      licensePlate: json['Driver']['licensePlateNumber'],
      currentLocation: ResolvedAddress(
        location: dir.Location(
          lat: json['Driver']['DriverLocations'][0]['lat'],
          lng: json['Driver']['DriverLocations'][0]['long'],
        ),
        mainText: "",
        secondaryText: "",
      ),
    );
  }

  factory DriverInfo.getDummy() {
    return DriverInfo.fromJson({
      "customerId": 1,
      "serviceTypeId": 3,
      "pickupLocation": "S701 Vinhomes Grand Park, Q9",
      "pickupLocationLat": 10.8431537,
      "pickupLocationLong": 106.8369187,
      "dropoffLocationLat": 34.0522,
      "dropoffLocationLong": -118.2437,
      "dropoffLocation": "456 Second St, Another City",
      "startTime": "2023-11-23T12:00:00.000Z",
      "endTime": "2023-11-23T13:30:00.000Z",
      "fare": 25,
      "distance": 10,
      "rating": 4,
      "updatedAt": "2023-11-23T18:46:44.866Z",
      "createdAt": "2023-11-23T18:46:44.866Z",
      "Driver": {
        "id": 1,
        "Car": {"name": "Mercedes"},
        "name": "John Doe",
        "phoneNumber": "+1234567890",
        "licensePlateNumber": "ABC123",
        "rating": 4,
        "avatarUrl": "https://i.pravatar.cc/100",
        "DriverLocations": [
          {"lat": 10.8392465, "long": 106.825292}
        ]
      }
    });
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'avatarUrl': avatarUrl,
      'rating': rating,
      'DriverLocations': {
        'lat': currentLocation.location.lat,
        'long': currentLocation.location.lng,
      },
    };
  }
}
