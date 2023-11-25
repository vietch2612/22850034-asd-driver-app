// 22850034 ASD Customer App Flutter

import 'package:flutter/material.dart';
import 'package:customer_app/types/resolved_address.dart';
import 'package:customer_app/providers/location.dart';
import 'package:customer_app/ui/common.dart';

import 'package:google_maps_webservice/places.dart';

class LocationScaffold extends StatelessWidget {
  LocationScaffold({Key? key}) : super(key: key);

  final homeAddress = ResolvedAddress(
      location: Location(lat: 10.8428625, lng: 106.8346228),
      mainText: "Vinhomes Grand Park - Origami S7.01",
      secondaryText: "Long Bình, Hồ Chí Minh, Thành phố Hồ Chí Minh, VN");

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
                "Driver",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            Expanded(child: Image.asset('assets/lottie/logo.png')),
            if (pendingDetermineLocation) ...[
              const LinearProgressIndicator(),
              const Text('Đang tìm kiếm toạ độ'),
            ],
            if (!pendingDetermineLocation) ...[
              Text(
                'Chúc tài xế của HCMUBCab ngày mới tốt lành.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              ListTile(
                leading: const Icon(Icons.gps_fixed),
                title: const Text('Vui lòng chia sẻ vị trí để bắt đầu.'),
                onTap: () => LocationProvider.of(context, listen: false)
                    .determineCurrentLocation(),
              )
            ],
          ]),
        ),
        isLoggedIn: false);
  }
}
