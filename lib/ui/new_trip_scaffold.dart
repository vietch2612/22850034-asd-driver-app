// 22850034 ASD Customer App Flutter

import 'dart:math';
import 'package:customer_app/global.dart';
import 'package:customer_app/servivces/formatter.dart';
import 'package:customer_app/servivces/map_service.dart';
import 'package:customer_app/types/driver_info.dart';
import 'package:flutter/foundation.dart';
import 'package:customer_app/types/resolved_address.dart';
import 'package:customer_app/types/trip.dart';
import 'package:customer_app/providers/assets_loader.dart';
import 'package:customer_app/providers/location.dart';
import 'package:customer_app/providers/active_trip.dart';
import 'package:customer_app/ui/common.dart';
import 'package:flutter/material.dart';
import 'package:customer_app/providers/theme.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:google_maps_webservice/directions.dart' as dir;
import 'package:google_maps_webservice/places.dart';
import 'package:logger/logger.dart';
import 'package:shimmer/shimmer.dart';
import 'package:customer_app/global.dart';

import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../api/google_api.dart';
import '../types/customer_info.dart';

final backendHost = dotenv.env['BACKEND_HOST'];
final logger = Logger();

class NewTrip extends StatefulWidget {
  final TripProvider tripProvider;

  const NewTrip({Key? key, required this.tripProvider}) : super(key: key);

  @override
  _NewTripState createState() => _NewTripState();
}

class _NewTripState extends State<NewTrip> {
  late io.Socket socket;
  late Timer locationUpdateTimer;
  TripDataEntity? tripDataEntity;

  LatLngBounds? cameraViewportLatLngBounds;

  ResolvedAddress? from;
  ResolvedAddress? to;

  bool started = false;
  DriverInfo driverInfo = globalDriver!;

  Polyline? tripPolyline;
  int tripDistanceMeters = 0;
  String tripDistanceText = '';
  int tripFare = 0;
  String tripFareText = '';

  void initSocket() {
    socket = io.io('$backendHost', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    socket.on('connect', (_) async {});

    /** Got a trip */
    socket.on('trip_driver_allocate', (data) async {
      logger.i('We got a new trip!', data);

      CustomerInfo customerInfo = CustomerInfo.fromJson(data['Customer']);
      ResolvedAddress from = ResolvedAddress(
        location: Location(
          lat: data['pickupLocationLat'],
          lng: data['pickupLocationLong'],
        ),
        mainText: data['pickupLocation'],
        secondaryText: data['pickupLocation'],
      );

      ResolvedAddress to = ResolvedAddress(
        location: Location(
          lat: data['dropoffLocationLat'],
          lng: data['dropoffLocationLong'],
        ),
        mainText: data['dropoffLocation'],
        secondaryText: data['dropoffLocation'],
      );

      // Asynchronously get Polyline
      Polyline polyline = await MapHelper.getPolyline(from, to);

      // Extract other trip details
      tripDataEntity = TripDataEntity(
        tripId: data['id'],
        from: from,
        to: to,
        polyline: polyline,
        distanceMeters: data['distance'],
        distanceText: data['distance'].toString(),
        status: ExTripStatus.submitted,
        driverInfo: null,
        customerInfo: customerInfo,
        mapLatLngBounds: LatLngBounds(
          southwest: const LatLng(37.7749, -122.4194),
          northeast: const LatLng(37.8049, -122.3894),
        ),
        fare: data['fare'],
      );

      driverInfo = globalDriver!;
      tripFare = tripDataEntity!.fare;

      showNewTripPopup(tripDataEntity!);
    });
  }

  Future<void> recalcRoute() async {
    tripPolyline = null;
    tripDistanceText = '';
    tripDistanceMeters = 0;
    tripFare = 0;
    tripFareText = '';

    if (from == null || to == null) {
      return;
    }
    dir.DirectionsResponse response = await apiDirections
        .directionsWithLocation(from!.location, to!.location);
    if (response.isOkay) {
      tripDistanceMeters =
          response.routes.first.legs.first.distance.value.round();
      tripDistanceText = response.routes.first.legs.first.distance.text;

      if (!response.isOkay) {
        final error =
            'Directions API error. Status: ${response.status} ${response.errorMessage ?? ""}';
        showScaffoldSnackBarMessage(error);

        if (mounted) setState(() {});
      }

      tripFareText = await formatCurrency(tripDataEntity!.fare);

      final polylinePoints = createPolylinePointsFromDirections(response)!;

      tripPolyline = Polyline(
          polylineId: const PolylineId('polyline-1'),
          width: 5,
          color: Colors.blue,
          points: polylinePoints);
      adjustMapViewBounds();
      if (mounted) setState(() {});
    }
  }

  LatLngBounds? _mapCameraViewBounds;

  void adjustMapViewBounds() {
    if (!mounted) return;

    //0.001 ~= 100 m
    const double deltaLatLngPointBound = 0.0015;

    double minx = 180, miny = 180, maxx = -180, maxy = -180;
    if (from == null && to == null) return;
    if (from == null ||
        to == null ||
        from!.location.lat == to!.location.lat &&
            from!.location.lng == to!.location.lng) {
      double lat = from?.toLatLng.latitude ?? to?.toLatLng.latitude ?? 0;
      double lng = from?.toLatLng.longitude ?? to?.toLatLng.longitude ?? 0;
      minx = lng - deltaLatLngPointBound;
      maxx = lng + deltaLatLngPointBound;
      miny = lat - deltaLatLngPointBound;
      maxy = lat + deltaLatLngPointBound;

      if (minx < -180) minx = -180;
      if (miny < -90) miny = -90;
      if (maxx > 180) minx = 180;
      if (maxy > 90) maxy = 90;
    } else {
      for (var p in [
        from!.toLatLng,
        to!.toLatLng,
        if (tripPolyline != null) ...tripPolyline!.points
      ]) {
        minx = min(minx, p.longitude);
        maxx = max(maxx, p.longitude);

        miny = min(miny, p.latitude);
        maxy = max(maxy, p.latitude);
      }
    }

    final newCameraViewBounds = LatLngBounds(
      northeast: LatLng(maxy, maxx),
      southwest: LatLng(miny, minx),
    );
    if (_mapCameraViewBounds == null ||
        _mapCameraViewBounds != newCameraViewBounds) {
      _mapCameraViewBounds = newCameraViewBounds;

      if (mapControllerCompleter.isCompleted == false) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _mapCameraViewBounds == null) return;

        mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(
            _mapCameraViewBounds!,
            30,
          ),
        );
      });
    }
  }

  bool isDarkMapThemeSelected = false;
  List<Marker> mapRouteMarkers = List.empty(growable: true);
  List<Marker> avaliableTaxiMarkers = List.empty(growable: true);

  final mapControllerCompleter = Completer<GoogleMapController>();
  GoogleMapController? mapController;
  CameraPosition? _latestCameraPosition;

  void startWait() async {
    initSocket();

    logger.i("DRIVER_ACTIVE: Start looking for a trip!");
    driverInfo.currentLocation = await MapHelper.getCurrentLocation();
    socket.emit('driver_active', driverInfo.toJson());

    setState(() {
      started = true;
    });
  }

  void cancelWait() async {
    if (socket.disconnected) {
      logger.i("Socket is disconnected. Reconnecting...");
      initSocket();
    }

    logger.i("DRIVER_CANCEL: Cancel waiting for a trip!");
    socket.emit("driver_cancel", driverInfo.toJson());

    setState(() {
      started = false;
    });
  }

  void startNewTrip(BuildContext context, CustomerInfo customerInfo,
      TripDataEntity trip) async {
    tripDataEntity = trip;
    from = await MapHelper.getCurrentLocation();
    to = trip.from;
    trip.status = ExTripStatus.allocated;
    await recalcRoute();
    adjustMapViewBounds();

    driverInfo.currentLocation = from!;
    tripDataEntity!.driverInfo = driverInfo;

    logger.i(tripDataEntity!.toJson());
    socket.emit("trip_driver_accept", tripDataEntity!.toJson());

    if (mounted) setState(() {});
    setState(() {});

    startLocationUpdates();
  }

  void declineTrip() async {
    tripDataEntity!.driverInfo = driverInfo;
    socket.emit("trip_driver_decline", tripDataEntity!.toJson());

    tripDataEntity = null;
    from = null;
    to = null;
  }

  void cancelTrip() async {
    from = null;
    to = null;
    tripDataEntity = null;

    socket.disconnect();
  }

  void startTrip() async {
    tripDataEntity!.status = ExTripStatus.driving;
    socket.emit('trip_driver_driving', tripDataEntity!.toJson());
    from = await MapHelper.getCurrentLocation();
    to = tripDataEntity!.to;
    await recalcRoute();
    adjustMapViewBounds();

    if (mounted) setState(() {});
    setState(() {});
  }

  void completeTrip() async {
    from = null;
    to = null;
    tripDataEntity = null;

    stopLocationUpdates();
    logger.i("Trip completed!");
  }

  void sendLocationUpdate() async {
    logger.i("Sending location update!");
    driverInfo.currentLocation = await MapHelper.getCurrentLocation();
    tripDataEntity?.driverInfo = driverInfo;
    from = driverInfo.currentLocation;
    socket.emit("location_update", tripDataEntity?.toJson());

    await recalcRoute();
    adjustMapViewBounds();

    setState(() {});
  }

  void startLocationUpdates() async {
    // Schedule the location update task every 10 seconds
    locationUpdateTimer =
        Timer.periodic(const Duration(seconds: 20), (timer) async {
      sendLocationUpdate();
    });
  }

  void stopLocationUpdates() {
    // Cancel the location update timer
    locationUpdateTimer.cancel();
  }

  String mainButtonTextHandler() {
    if (tripDataEntity != null) {
      switch (tripDataEntity!.status) {
        case ExTripStatus.allocated:
          return "Bắt đầù chuyến đi";
        case ExTripStatus.driving:
          return "Hoàn thành";
        default:
      }
    } else if (started) {
      return "Huỷ";
    } else {
      return "Bắt đầu";
    }

    return "";
  }

  void mainButtonActionHandler() {
    if (started) {
      if (tripDataEntity == null) {
        cancelWait();
      } else {
        if (MapHelper.areAddressesClose(
            driverInfo.currentLocation, tripDataEntity!.to)) {
          completeTrip();
        } else {
          startTrip();
        }
      }
    } else {
      startWait();
    }
  }

  String mainStatusHandler() {
    if (started) {
      if (tripDataEntity == null) {
        return "Đang tìm kiếm";
      } else {
        return "Đang trên chuyến";
      }
    } else {
      return "Waiting for a trip";
    }
  }

  @override
  void dispose() {
    // Dispose of the timer when the widget is disposed
    locationUpdateTimer.cancel();

    super.dispose();
  }

  void showNewTripPopup(TripDataEntity dataEntity) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          elevation: 0.0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.0),
              color: Colors.white,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Customer's Avatar and Phone Number
                CircleAvatar(
                  // Replace with the customer's avatar
                  backgroundImage:
                      NetworkImage(dataEntity.customerInfo.avatarUrl),
                  radius: 40.0,
                ),
                const SizedBox(height: 16.0),
                Text(
                  "${dataEntity.customerInfo.name} - ${dataEntity.customerInfo.phoneNumber}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16.0,
                  ),
                ),
                const SizedBox(height: 16.0),
                // From and To Addresses
                Text(
                  'From: ${dataEntity.from.mainText}',
                  style: const TextStyle(fontSize: 11.0),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8.0),
                Text(
                  'To: ${dataEntity.to.mainText}',
                  style: const TextStyle(fontSize: 11.0),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16.0),
                // Length
                Text(
                  'Length: ${dataEntity.distanceText}',
                  style: const TextStyle(
                      fontSize: 10.0, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16.0),
                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        // Handle Select button click
                        Navigator.of(context).pop();
                        startNewTrip(context, tripDataEntity!.customerInfo,
                            tripDataEntity!);
                        // Close the popup
                      },
                      child: const Text('Đồng ý'),
                    ),
                    const SizedBox(width: 16.0),
                    OutlinedButton(
                      onPressed: () {
                        // Handle Cancel button click
                        Navigator.of(context).pop();
                        declineTrip(); // Close the popup
                      },
                      child: const Text('Không đồng ý'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  BitmapDescriptor? fromMarker;
  BitmapDescriptor? toMarker;

  @override
  void initState() {
    from = LocationProvider.of(context, listen: false).currentAddress;
    isDarkMapThemeSelected = false;

    super.initState();
  }

  @override
  void didChangeDependencies() {
    final isDark = ThemeProvider.of(context, listen: false).isDark;
    if (isDark != isDarkMapThemeSelected && mapController != null) {
      mapController!.setMapStyle(ThemeProvider.of(context, listen: false).isDark
          ? googleMapDarkStyle
          : googleMapDefaultStyle);
      isDarkMapThemeSelected = isDark;
    }

    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return buildAppScaffold(
      context,
      Column(
        children: [
          Expanded(
            child: GoogleMap(
              onCameraMove: (pos) => _latestCameraPosition = pos,
              initialCameraPosition: CameraPosition(
                  target: LocationProvider.of(context, listen: false)
                      .currentAddress!
                      .toLatLng,
                  zoom: 15),
              mapType: MapType.normal,
              myLocationEnabled: true,
              zoomGesturesEnabled: true,
              zoomControlsEnabled: true,
              scrollGesturesEnabled: true,
              markers: {
                if (to != null)
                  Marker(
                    icon: AssetLoaderProvider.of(context).markerIconTo,
                    position: to!.toLatLng,
                    markerId: MarkerId(
                        'marker-To${kIsWeb ? DateTime.now().toIso8601String() : ""}'),
                  ),
                if (from != null)
                  Marker(
                    icon: AssetLoaderProvider.of(context).markerIconTaxi,
                    position: from!.toLatLng,
                    markerId: MarkerId(
                        'marker-Taxi${kIsWeb ? DateTime.now().toIso8601String() : ""}'),
                  ),
              },
              polylines: tripPolyline != null
                  ? <Polyline>{tripPolyline!}
                  : const <Polyline>{},
              onMapCreated: (GoogleMapController controller) {
                mapControllerCompleter.complete(controller);
                mapController = controller;
                if (mounted) {
                  final isDark =
                      ThemeProvider.of(context, listen: false).isDark;
                  if (isDark != isDarkMapThemeSelected) {
                    controller.setMapStyle(
                        ThemeProvider.of(context, listen: false).isDark
                            ? googleMapDarkStyle
                            : googleMapDefaultStyle);
                    isDarkMapThemeSelected = isDark;
                  }
                  setState(() {});
                }
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.background,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.5),
                  spreadRadius: 3,
                  blurRadius: 3,
                  offset: const Offset(0, -3), // changes position of shadow
                ),
              ],
            ),
            child: Column(children: [
              if (to != null)
                ListTile(
                    leading: const Icon(Icons.person_pin_circle),
                    title: Text(
                      tripDataEntity?.from.mainText ?? "",
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Row(
                      children: [
                        const Text(
                          'From',
                          style: TextStyle(color: Colors.green),
                        ),
                        Container(
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.color ??
                                    Colors.white)),
                        Text(tripDataEntity?.from.secondaryText ?? "",
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 8))
                      ],
                    )),
              const SizedBox(
                height: 4,
              ),
              if (to != null)
                ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(
                      tripDataEntity!.to.mainText,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Row(
                      children: [
                        const Text(
                          'To',
                          style: TextStyle(color: Colors.green),
                        ),
                        Container(
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.color ??
                                    Colors.white)),
                        Text(tripDataEntity!.to.secondaryText,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 8))
                      ],
                    )),
              const Divider(height: 1),
              SizedBox(
                  height: 80,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                          child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (from == null || to == null)
                              Shimmer.fromColors(
                                  baseColor: Theme.of(context)
                                          .textTheme
                                          .bodyLarge!
                                          .color ??
                                      Colors.black,
                                  highlightColor:
                                      Theme.of(context).colorScheme.secondary,
                                  child: Text(
                                    started
                                        ? 'Đang tìm kiếm...'
                                        : 'Bấm bắt đầu để tìm chuyến',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).hintColor),
                                  )),
                            if (from != null &&
                                to != null &&
                                tripDistanceText.isEmpty)
                              Text(
                                'Calculating route ... ',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            if (from != null &&
                                to != null &&
                                tripDistanceText.isNotEmpty)
                              Text(
                                mainStatusHandler(),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                          ],
                        ),
                      )),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                        child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  started ? Colors.red : Colors.green,
                            ),
                            onPressed: () {
                              mainButtonActionHandler();
                            },
                            child: Row(children: [
                              const Icon(Icons.taxi_alert_rounded),
                              const SizedBox(width: 10),
                              Text(mainButtonTextHandler())
                            ])),
                      )
                    ],
                  )),
            ]),
          )
        ],
      ),
    );
  }
}
