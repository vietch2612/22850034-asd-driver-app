// 22850034 ASD Customer App Flutter

import 'package:customer_app/global.dart';
import 'package:flutter/material.dart';
import 'package:customer_app/providers/location.dart';
import 'package:customer_app/ui/common.dart';

class LocationScaffold extends StatelessWidget {
  LocationScaffold({Key? key}) : super(key: key);

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
                "Xin chào ${globalDriver?.name ?? 'tài xế'}",
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
