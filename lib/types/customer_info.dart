import 'package:customer_app/types/resolved_address.dart';
import 'package:google_maps_webservice/directions.dart' as dir;

class CustomerInfo {
  final String id;
  final String name;
  final String phoneNumber;
  final String avatarUrl;
  final ResolvedAddress currentLocation;

  CustomerInfo(
    this.id,
    this.avatarUrl, {
    required this.phoneNumber,
    required this.name,
    required this.currentLocation,
  });

  factory CustomerInfo.fromJson(Map<String, dynamic> json) {
    return CustomerInfo(
      json['driver']['id'],
      json['driver']['avatarUrl'],
      phoneNumber: json['driver']['phoneNumber'],
      name: json['driver']['name'],
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
}
