import 'package:customer_app/types/resolved_address.dart';
import 'package:google_maps_webservice/directions.dart' as dir;

class DriverInfo {
  final String id;
  final String name;
  final String licensePlate;
  final String carInfo;
  final String phoneNumber;
  final String avatarUrl;
  final String rating;
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

  factory DriverInfo.fromJson(json) {
    return DriverInfo(
      json['driver']['id'],
      json['driver']['avatarUrl'],
      json['driver']['rating'],
      json['driver']['carInfo'],
      phoneNumber: json['driver']['phoneNumber'],
      name: json['driver']['name'],
      licensePlate: json['driver']['licensePlate'],
      currentLocation: ResolvedAddress(
        location: dir.Location(
          lat: json['driver']['currentLocation']['latitude'],
          lng: json['driver']['currentLocation']['longitude'],
        ),
        mainText: json['driver']['currentLocation']['address'],
        secondaryText: json['driver']['currentLocation']['address'],
      ),
    );
  }

  factory DriverInfo.getDummy() {
    return DriverInfo.fromJson({
      "driver": {
        "id": "962a8325-0cfd-4853-9fd9-108e6e0ed155",
        "name": "John Doe",
        "licensePlate": "51B1-123456",
        "carInfo": "Toyota Camry",
        "phoneNumber": "+1234567890",
        "avatarUrl": "https://i.ibb.co/L81BT4w/avatar-portrait.png",
        "rating": "4",
        "currentLocation": {
          "latitude": 10.8398821,
          "longitude": 106.8293289,
          "address": "Some Street, City, Country"
        }
      }
    });
  }
}
