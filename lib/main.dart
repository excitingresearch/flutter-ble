// Copyright 2017, Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'package:moody/src/screens/AutoConnectScreen.dart';
import 'package:moody/src/screens/EnrollDeviceScreen.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:flutter_blue/flutter_blue.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:permission_handler/permission_handler.dart';

import 'package:provider/provider.dart';
import 'package:moody/src/providers/DeviceProvider.dart';
import 'package:http/http.dart' as http;

final snackBarKeyA = GlobalKey<ScaffoldMessengerState>();
final snackBarKeyB = GlobalKey<ScaffoldMessengerState>();
final snackBarKeyC = GlobalKey<ScaffoldMessengerState>();
final snackBarKeyNFC = GlobalKey<ScaffoldMessengerState>();

final RegExp moodyDeviceNameRegExp = RegExp(
    r'^([mM][0-9]{3}|MOODY_[0-9A-Fa-f]{4}|moody_[0-9A-Fa-f]{4})$'); // new firmware auto generated device names from MAC

const String currentVersion = "20240711-0";
const String appVersionURL = 'https://fgmnts.be/moody_version.txt';

const String newVersionText =
    'A newer version of the app is available. Please visit the website to download the latest APK.';

void main() {
  if (Platform.isAndroid) {
    WidgetsFlutterBinding.ensureInitialized();
    [
      Permission.location,
      Permission.storage,
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan
    ].request().then((status) {
      runApp(const MyApp());
    });
  } else {
    runApp(const MyApp());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => DeviceProvider(),
      child: MaterialApp(
        title: 'Moody',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool showUpdate = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAppVersion();
    });
  }

  Future<void> _checkAppVersion() async {
    try {
      // Fetch the latest version from the URL
      final response = await http.get(Uri.parse(appVersionURL));
      if (response.statusCode == 200) {
        final latestVersion = response.body.trim();

        // Get the current version of the app
        // final packageInfo = await PackageInfo.fromPlatform();

        // Compare versions
        if (latestVersion != currentVersion) {
          _showUpdateAlert();
        }
      } else {
        print('Failed to fetch latest version.');
      }
    } catch (e) {
      print('Error checking app version: $e');
    }
  }

  void _showUpdateAlert() {
    setState(() {
      showUpdate = true;
    });
    // showDialog(
    //   context: context,
    //   builder: (context) => AlertDialog(
    //     title: const Text('Update Available'),
    //     content: const Text(
    //         'A newer version of the app is available. Please visit the website to download the latest APK.'),
    //     actions: [
    //       TextButton(
    //         onPressed: () {
    //           setState(() {
    //             showUpdate = false;
    //           });
    //           Navigator.of(context).pop();
    //         },
    //         child: const Text('OK'),
    //       ),
    //     ],
    //   ),
    // );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Consumer<DeviceProvider>(
            builder: (context, deviceProvider, child) {
              if (deviceProvider.deviceId == null) {
                return const EnrollDeviceScreen();
              } else {
                return const AutoConnectScreen();
              }
            },
          ),
          if (showUpdate)
            AlertDialog(
              title: const Text('Update Available'),
              content: const Text(newVersionText),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      showUpdate = false;
                    });
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class BluetoothAdapterStateObserver extends NavigatorObserver {
  StreamSubscription<BluetoothAdapterState>? _btStateSubscription;

  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    if (route.settings.name == '/deviceScreen') {
      // Start listening to Bluetooth state changes when a new route is pushed
      _btStateSubscription ??= FlutterBluePlus.adapterState.listen((state) {
        if (state != BluetoothAdapterState.on) {
          // Pop the current route if Bluetooth is off
          navigator?.pop();
        }
      });
    }
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    // Cancel the subscription when the route is popped
    _btStateSubscription?.cancel();
    _btStateSubscription = null;
  }
}

String prettyException(String prefix, dynamic e) {
  if (e is FlutterBluePlusException) {
    return '$prefix ${e.errorString}';
  } else if (e is PlatformException) {
    return '$prefix ${e.message}';
  }
  return prefix + e.toString();
}
