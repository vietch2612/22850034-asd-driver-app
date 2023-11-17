// 22850034 ASD Customer App Flutter

import 'package:flutter/material.dart';
import 'package:customer_app/types/resolved_address.dart';
import 'package:customer_app/providers/location.dart';
import 'package:customer_app/ui/common.dart';

import 'package:google_maps_webservice/places.dart';
import 'package:lottie/lottie.dart';

class LocationScaffold extends StatelessWidget {
  LocationScaffold({Key? key}) : super(key: key);

  final homeAddress = ResolvedAddress(
      location: Location(lat: 10.8428625, lng: 106.8346228),
      mainText: "Vinhomes Grand Park - Origami S7.01",
      secondaryText:
          "RRVP+4VW, Long Bình, Hồ Chí Minh, Thành phố Hồ Chí Minh, Vietnam");

  @override
  Widget build(BuildContext context) {
    bool pendingDetermineLocation =
        LocationProvider.of(context).pendingDetermineCurrentLocation;
    return buildAppScaffold(
        context,
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.only(left: 64, top: 8),
              child: Text(
                "HCMUS CAB",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            Expanded(child: Lottie.asset('assets/lottie/taxi-animation.json')),
            if (pendingDetermineLocation) ...[
              const LinearProgressIndicator(),
              const Text('Finding your location...'),
            ],
            if (!pendingDetermineLocation) ...[
              Text(
                'Welcome! Driver!',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              ListTile(
                leading: const Icon(Icons.gps_fixed),
                title: const Text(
                    'Please share your current location to start a Ride!'),
                onTap: () => LocationProvider.of(context, listen: false)
                    .determineCurrentLocation(),
              )
            ],
          ]),
        ),
        isLoggedIn: false);
  }
}
