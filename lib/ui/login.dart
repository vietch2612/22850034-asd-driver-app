import 'package:customer_app/providers/active_trip.dart';
import 'package:customer_app/providers/location.dart';
import 'package:customer_app/servivces/auth_service.dart';
import 'package:customer_app/types/driver_info.dart';
import 'package:customer_app/types/resolved_address.dart';
import 'package:customer_app/types/trip.dart';
import 'package:customer_app/ui/active_trip_scaffold.dart';
import 'package:customer_app/ui/select_location_scaffold.dart';
import 'package:customer_app/ui/trip_finished_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:customer_app/global.dart';
import 'package:google_maps_webservice/places.dart';

import 'new_trip_scaffold.dart';

class LoginPage extends StatefulWidget {
  final AuthService authService;

  LoginPage({required this.authService});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  TextEditingController _usernameController = TextEditingController();
  TextEditingController _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tài xế vui lòng đăng nhập'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Số điện thoại',
                icon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 20.0),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Mật khẩu',
                icon: Icon(Icons.lock),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 20.0),
            ElevatedButton(
              onPressed: () async {
                String username = _usernameController.text;
                String password = _passwordController.text;

                try {
                  final user =
                      await widget.authService.login(username, password);

                  if (user != null) {
                    await widget.authService.saveToken(user['token']);

                    DriverInfo driver = DriverInfo(
                      user['id'],
                      user['avatarUrl'],
                      user['rating'],
                      "",
                      phoneNumber: user['phoneNumber'],
                      name: user['name'],
                      licensePlate: user['licensePlateNumber'],
                      currentLocation: ResolvedAddress(
                        location: Location(lat: 1, lng: 1),
                        mainText: "tbd",
                        secondaryText: '',
                      ),
                    );

                    // Set the globalDriver
                    globalDriver = driver;

                    // ignore: use_build_context_synchronously
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) {
                          final locProvider = LocationProvider.of(context);

                          // Get Current Trip Provider
                          final currentTrip = TripProvider.of(context);

                          // if Current location is not known
                          if (!locProvider.isDemoLocationFixed) {
                            // show Location Selection screen
                            return LocationScaffold();
                          }

                          // else if there is an Active Trip
                          if (currentTrip.isActive) {
                            // and if this trip is finished
                            return tripIsFinished(
                                    currentTrip.activeTrip!.status)
                                // show Rate the Trip screen
                                ? tripFinishedScaffold(context)
                                // if not finished - show the trip in progress screen
                                : const ActiveTrip(); // Change here to use ActiveTrip instead of const ActiveTrip()
                          }

                          // else if there is no active trip - display UI for new trip creation
                          return NewTrip(tripProvider: currentTrip); //
                        },
                      ),
                    );
                  } else {
                    // Handle login failure
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đăng nhập thất bại. Vui lòng thử lại.'),
                      ),
                    );
                  }
                } catch (e) {
                  print('Error during login: $e');
                  // Handle other errors
                }
              },
              child: const Text('Đăng nhập'),
            ),
          ],
        ),
      ),
    );
  }
}
