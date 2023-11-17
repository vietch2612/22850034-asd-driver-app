// 22850034 ASD Customer App Flutter

import 'dart:convert';
import 'dart:math';
import 'package:customer_app/api/backend_api.dart';
import 'package:customer_app/servivces/formatter.dart';
import 'package:customer_app/types/driver_info.dart';
import 'package:flutter/foundation.dart';
import 'package:customer_app/api/google_api.dart';
import 'package:customer_app/types/resolved_address.dart';
import 'package:customer_app/types/trip.dart';
import 'package:customer_app/ui/address_search.dart';
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

import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  LatLngBounds? cameraViewportLatLngBounds;

  ResolvedAddress? from;
  ResolvedAddress? to;

  bool started = false;
  DriverInfo? driverInfo;

  Polyline? tripPolyline;
  int tripDistanceMeters = 0;
  String tripDistanceText = '';
  int tripFare = 0;
  String tripFareText = '';

  void openSocketForNewTrip() {
    final socket = io.io('$backendHost', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    /** Start looking for a Trip */
    socket.on('connect', (_) {
      socket.emit('looking', {});

      logger.i('Looking for a trip!');
    });

    /** Got a trip */
    socket.on('available_trip', (_) {
      logger.i('We got a new trip!');
      showNewTripPopup();
    });

    socket.on('message', (data) {
      logger.i('Received message: $data');
    });

    socket.on('disconnect', (_) {});
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

      tripFare = await ApiService.calculateTripFare(tripDistanceMeters);
      tripFareText = await formatCurrency(tripFare);

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

  void adjustMapViewBoundsByLocation(LatLng from, LatLng to) {
    if (!mounted) return;

    //0.001 ~= 100 m
    const double deltaLatLngPointBound = 0.0015;
    double minx = 180, miny = 180, maxx = -180, maxy = -180;

    if (from!.latitude == to!.latitude && from!.longitude == to!.longitude) {
      double lat = from.latitude;
      double lng = from.longitude;
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
        from,
        to,
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

  void autocompleteAddress(bool isFromAdr, Location searchLocation) async {
    final Prediction? p = await showSearch<Prediction?>(
        context: context,
        delegate: AddressSearch(searchLocation: searchLocation),
        query: (isFromAdr ? from : to)?.mainText ?? '');
    if (p != null) {
      PlacesDetailsResponse placeDetails = await apiGooglePlaces
          .getDetailsByPlaceId(p.placeId!, fields: [
        "address_component",
        "geometry",
        "type",
        "adr_address",
        "formatted_address"
      ]);

      if (!mounted) return;

      final placeAddress = ResolvedAddress(
          location: placeDetails.result.geometry!.location,
          mainText: p.structuredFormatting?.mainText ??
              placeDetails.result.addressComponents.join(','),
          secondaryText: p.structuredFormatting?.secondaryText ?? '');

      setState(() {
        if (isFromAdr) {
          from = placeAddress;
        } else {
          to = placeAddress;
        }
      });

      await recalcRoute();
      adjustMapViewBounds();
      if (mounted) setState(() {});
    }
  }

  void waitForTrip(BuildContext context) async {
    setState(() {
      logger.i("Start looking for a trip");
      started = true;
      openSocketForNewTrip();
    });
  }

  void cancelWait(BuildContext context) async {
    setState(() {
      logger.i("Cancel looking for a trip");
      started = false;
    });
  }

  void startNewTrip(BuildContext context, CustomerInfo customerInfo) async {
    final newTrip = TripDataEntity(
        from: from!,
        to: to!,
        polyline: tripPolyline!,
        distanceMeters: tripDistanceMeters,
        distanceText: tripDistanceText,
        mapLatLngBounds: _mapCameraViewBounds!,
        cameraPosition: _latestCameraPosition,
        customerInfo: customerInfo);

    final trip = TripProvider.of(context, listen: false);
    trip.activateTrip(newTrip);
  }

  void showNewTripPopup() {
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
            padding: EdgeInsets.all(16.0),
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
                  backgroundImage: AssetImage('assets/customer_avatar.png'),
                  radius: 40.0,
                ),
                SizedBox(height: 16.0),
                Text(
                  'Customer Phone Number', // Replace with the actual phone number
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16.0,
                  ),
                ),
                SizedBox(height: 16.0),
                // From and To Addresses
                Text(
                  'From: ${from?.mainText ?? ""}',
                  style: TextStyle(fontSize: 14.0),
                ),
                SizedBox(height: 8.0),
                Text(
                  'To: ${to?.mainText ?? ""}',
                  style: TextStyle(fontSize: 14.0),
                ),
                SizedBox(height: 16.0),
                // Length
                Text(
                  'Length: ${tripDistanceText.isNotEmpty ? tripDistanceText : "Calculating..."}',
                  style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16.0),
                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        // Handle Select button click
                        Navigator.of(context).pop(); // Close the popup
                      },
                      child: Text('Select'),
                    ),
                    SizedBox(width: 16.0),
                    OutlinedButton(
                      onPressed: () {
                        // Handle Cancel button click
                        Navigator.of(context).pop(); // Close the popup
                      },
                      child: Text('Cancel'),
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
                if (from != null &&
                    AssetLoaderProvider.of(context).markerIconFrom != null)
                  Marker(
                    icon: AssetLoaderProvider.of(context).markerIconFrom!,
                    position: from!.toLatLng,
                    markerId: MarkerId(
                        'marker-From${kIsWeb ? DateTime.now().toIso8601String() : ""}'), // Flutter Google Maps for Web does not update marker position properly
                  ),
                if (to != null)
                  Marker(
                    icon: AssetLoaderProvider.of(context).markerIconTo,
                    position: to!.toLatLng,
                    markerId: MarkerId(
                        'marker-To${kIsWeb ? DateTime.now().toIso8601String() : ""}'),
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
                  widget.tripProvider.setMapViewBoundsCallback(
                    (LatLng driverLocation, LatLng passengerLocation) {
                      // Call the adjustMapViewBounds method with driver and passenger locations
                      adjustMapViewBoundsByLocation(
                          driverLocation, passengerLocation);

                      logger.d("mapViewBounds");
                    },
                  );
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
                    from?.mainText ?? "",
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
                      Text(from?.secondaryText ?? "",
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12))
                    ],
                  ),
                  onTap: () => autocompleteAddress(
                      true,
                      LocationProvider.of(context, listen: false)
                          .currentAddress!
                          .location),
                ),
              const SizedBox(
                height: 4,
              ),
              if (to != null)
                ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(
                    to!.mainText,
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
                      Text(to!.secondaryText,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12))
                    ],
                  ),
                  onTap: () => autocompleteAddress(
                      false,
                      LocationProvider.of(context, listen: false)
                          .currentAddress!
                          .location),
                ),
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
                                        ? 'Looking for a trip...'
                                        : 'Please confirm that you are ready for a trip!',
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
                                '$tripDistanceText, Fare: $tripFareText',
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
                              if (started) {
                                cancelWait(context);
                              } else {
                                waitForTrip(context);
                              }
                            },
                            child: Row(children: [
                              const Icon(Icons.taxi_alert_rounded),
                              const SizedBox(width: 10),
                              Text(started ? 'Cancel' : 'Ready')
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