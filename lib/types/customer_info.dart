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

  factory CustomerInfo.fromJson(json) {
    return CustomerInfo(
      json['id'],
      json['avatarUrl'],
      phoneNumber: json['phoneNumber'],
      name: json['name'],
      currentLocation: ResolvedAddress(
        location: dir.Location(
          lat: json['currentLocation']['latitude'],
          lng: json['currentLocation']['longitude'],
        ),
        mainText: json['currentLocation']['address'],
        secondaryText: json['currentLocation']['address'],
      ),
    );
  }
}
