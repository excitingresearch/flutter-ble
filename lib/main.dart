// Copyright 2017, Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:keep_screen_on/keep_screen_on.dart';

import 'package:sensors_plus/sensors_plus.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:flutter_blue/flutter_blue.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:permission_handler/permission_handler.dart';

import 'package:provider/provider.dart';
import 'package:moody/src/providers/DeviceProvider.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:location/location.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moody/src/widgets/toggle_image_button.dart';

final snackBarKeyA = GlobalKey<ScaffoldMessengerState>();
final snackBarKeyB = GlobalKey<ScaffoldMessengerState>();
final snackBarKeyC = GlobalKey<ScaffoldMessengerState>();
final snackBarKeyNFC = GlobalKey<ScaffoldMessengerState>();

//final String serverHost = '192.168.10.139:2000';
final String serverHost = '134.122.18.168:2000';

// final RegExp moodyDeviceNameRegExp = RegExp(r'^m\d{3}$');
final RegExp moodyDeviceNameRegExp = RegExp(
    r'^([mM][0-9]{3}|MOODY_[0-9A-Fa-f]{4}|moody_[0-9A-Fa-f]{4})$'); // new firmware auto generated device names from MAC
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
      runApp(MyApp());
    });
  } else {
    runApp(MyApp());
  }

  // runApp(MyApp());
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
        home: Consumer<DeviceProvider>(
          builder: (context, deviceProvider, child) {
            if (deviceProvider.deviceId == null) {
              return FirstScreen();
            } else {
              return ToggleScreen();
            }
          },
        ),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class ToggleScreen extends StatefulWidget {
  const ToggleScreen({Key? key}) : super(key: key);

  @override
  _ToggleScreenState createState() => _ToggleScreenState();
}

class _ToggleScreenState extends State<ToggleScreen> {
  BluetoothDevice? _connectedDevice;
  String? _deviceId;

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
    _startScan();
  }

  Future<void> _loadDeviceId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _deviceId = prefs.getString('device_id');
    });
  }

  void _startScan() {
    FlutterBluePlus.scanResults.listen((scanResults) {
      for (ScanResult scanResult in scanResults) {
        if (scanResult.device.platformName.toString() == _deviceId) {
          FlutterBluePlus.stopScan();
          setState(() {
            _connectedDevice = scanResult.device;
          });
        }
      }
    });
    // FlutterBluePlus.isScanning
    FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15), androidUsesFineLocation: false);
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Forget Device'),
          content: Consumer<DeviceProvider>(
            builder: (context, deviceProvider, child) {
              return Text(
                'Are you sure you want to forget the device with ID: ${deviceProvider.deviceId}?',
              );
            },
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Yes'),
              onPressed: () {
                Provider.of<DeviceProvider>(context, listen: false)
                    .deleteDeviceId();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: Text('Toggle Screen'),
      // ),
      body: Column(
        children: [
          Expanded(
            child: _connectedDevice != null && _deviceId != null
                ? DeviceScreen(device: _connectedDevice!, deviceId: _deviceId!)
                : Center(
                    child:
                        // if (!FlutterBluePlus.isScanning)
                        //   ElevatedButton(
                        //     onPressed: _startScan,
                        //     child: Text('Start Scanning Again'),
                        //   ),
                        StreamBuilder<bool>(
                      stream: FlutterBluePlus.isScanning,
                      builder: (context, snapshot) {
                        // return SizedBox
                        //     .shrink(); // Return an empty widget when scanning

                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (snapshot.connectionState !=
                                    ConnectionState.active ||
                                (snapshot.connectionState ==
                                        ConnectionState.active &&
                                    snapshot.data!))
                              const CircularProgressIndicator(),
                            const SizedBox(
                                height:
                                    16), // Add some space between the indicator and the text
                            Text('Connecting to ${_deviceId ?? 'null'}'),
                            if (snapshot.connectionState ==
                                    ConnectionState.active &&
                                !snapshot.data!)
                              ElevatedButton(
                                onPressed: _startScan,
                                child: const Text('Start Scanning Again'),
                              )
                          ],
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: _connectedDevice != null && _deviceId != null
          ? null
          : FloatingActionButton(
              onPressed: () => _showDeleteConfirmationDialog(context),
              child: const Icon(Icons.delete),
              tooltip: 'Forget Device',
            ),
    );
  }
}

class FirstScreen extends StatefulWidget {
  const FirstScreen({Key? key}) : super(key: key);

  @override
  _FirstScreenState createState() => _FirstScreenState();
}

class _FirstScreenState extends State<FirstScreen> {
  TextEditingController _deviceIdController = TextEditingController();
  bool isManualEntry = false;
  String get deviceId => _deviceIdController.text;
  bool polling = false;
  bool pollingEnded = true;
  void pollRFID() async {
    isManualEntry = false;
    if (mounted) {
      setState(() {
        polling = true;
        pollingEnded = false;
      });
    }
    while (polling && _deviceIdController.text.isEmpty) {
      print('poll');
      try {
        NFCTag tag = await FlutterNfcKit.poll(
            timeout: const Duration(seconds: 3),
            iosMultipleTagMessage: 'Multiple tags found!',
            iosAlertMessage:
                'Scan your tag'); //timeout: Duration(milliseconds: 750)
        if (!polling) {
          return;
        }
        var found = false;

        // read NDEF records if available
        if (tag.ndefAvailable == true) {
          List records = await FlutterNfcKit.readNDEFRecords(cached: false);
          for (var record in records) {
            Uint8List lastFourBytes =
                record.payload.sublist(record.payload.length - 4);

            String payloadAsString = String.fromCharCodes(lastFourBytes);

            print(record.toString());
            print(record.payload);
            print(lastFourBytes);
            print('Payload: $payloadAsString');

            if (!found &&
                moodyDeviceNameRegExp.hasMatch(payloadAsString.toUpperCase())) {
              found = true;
              if (mounted) {
                setState(() {
                  _deviceIdController.text = payloadAsString;
                  polling = false;
                });
              }
            }

            Uint8List lastTenBytes =
                record.payload.sublist(record.payload.length - 10);

            String payloadasstringNewId = String.fromCharCodes(lastTenBytes);

            // print(record.toString());
            // print(record.payload);
            print(lastTenBytes);
            print('Payload: $payloadasstringNewId');

            if (!found &&
                moodyDeviceNameRegExp
                    .hasMatch(payloadasstringNewId.toUpperCase())) {
              found = true;
              if (mounted) {
                setState(() {
                  _deviceIdController.text = payloadasstringNewId;
                  polling = false;
                });
              }
            }
          }
        }

        if (!found) {
          print('No moody device');
          final snackBar = const SnackBar(content: Text('No MOODY device'));
          snackBarKeyNFC.currentState?.showSnackBar(snackBar);
        } else {
          if (Platform.isAndroid) {
// Call finish() only once
            await FlutterNfcKit.finish();
          } else {
// iOS only: show alert/error message on finish
            await FlutterNfcKit.finish(iosAlertMessage: 'Success');
          }
        }
      } catch (e) {
        print('Error polling NFC: $e');
        // break;
      }
    }
    if (mounted) {
      setState(() {
        pollingEnded = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    pollRFID();
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
        key: snackBarKeyNFC,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Connect MOODY device'),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Column(
                  children: <Widget>[
                    Container(
                      width: 150.0,
                      child: const Text(
                        'Scan your moody device with your phone, or enter the number',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    Container(
                      width: 150.0,
                      child: TextField(
                        controller: _deviceIdController,
                        textAlign: TextAlign.center,
                        onChanged: (value) {
                          isManualEntry = value.isNotEmpty;
                          // print(
                          //     "change $value, ${moodyDeviceNameRegExp.hasMatch(value.toUpperCase())}");
                          if (mounted) {
                            setState(
                                () {}); // To ensure the button's onPressed status gets updated.
                          }
                        },
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Device ID',
                        ),
                      ),
                    ),
                  ],
                ),
                ElevatedButton(
                  child: const Text('Go to second screen'),
                  onPressed: deviceId.isNotEmpty &&
                          moodyDeviceNameRegExp.hasMatch(deviceId.toUpperCase())
                      ? () {
                          Provider.of<DeviceProvider>(context, listen: false)
                              .setDeviceId(deviceId);

                          // Navigator.push(
                          //   context,
                          //   MaterialPageRoute(
                          //     builder: (context) =>
                          //         FlutterBlueApp(deviceId: deviceId),
                          //   ),
                          // ).then((value) {
                          //   print('back here');
                          //   pollRFID();
                          // });
                        }
                      : null,
                ),
                ElevatedButton(
                  child: !polling ? const Text('Scan') : const Text('Stop'),
                  onPressed: !polling
                      ? () {
                          //_deviceIdController.clear();
                          if (pollingEnded) {
                            pollRFID();
                          } else if (mounted) {
                            setState(() {
                              polling = true;
                            });
                          }
                        }
                      : () {
                          print('stop $polling');
                          //_deviceIdController.clear();
                          if (mounted) {
                            setState(() {
                              polling = false;
                            });
                          }
                        },
                ),
                ElevatedButton(
                  child: const Text('Clear'),
                  onPressed: deviceId.isNotEmpty
                      ? () {
                          _deviceIdController.clear();
                          pollRFID();
                        }
                      : null,
                ),
                Consumer<DeviceProvider>(
                  builder: (context, deviceProvider, child) {
                    return Column(
                      children: [
                        const Text(
                          'Previously connected devices:',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        ...deviceProvider.previousDeviceIds.map(
                          (id) => GestureDetector(
                            onTap: () {
                              _deviceIdController.text = id;
                              if (mounted) {
                                setState(() {
                                  isManualEntry = true;
                                });
                              }
                            },
                            child: Text(
                              id,
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.blue),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ));
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

class DeviceScreen extends StatefulWidget {
  const DeviceScreen({Key? key, required this.device, required this.deviceId})
      : super(key: key);

  final BluetoothDevice device;
  final String deviceId;

  @override
  _DeviceScreenState createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen>
    with SingleTickerProviderStateMixin {
  // String _imagePathButton1 = 'assets/images/NOW.png';
  // String _imagePathButton2 = 'assets/images/spirit2.png';
  // String _imagePathButton0 = 'assets/images/icons-Individual1.png';
  // String _imagePathButton3 = 'assets/images/terrain.png';

  // bool showIndividual = false;
  // bool showHistory = false;
  // bool showSpirit = true;
  // bool showTerrain = true;

  Map<String, bool> buttonStates = {
    "showIndividual": false,
    "showHistory": true,
    "showSpirit": true,
    "showTerrain": false,
  };

  void _handleToggle(bool isToggled, String buttonIndex) {
    setState(() {
      buttonStates[buttonIndex] = isToggled;
    });
  }

  // void _handleToggle(bool isToggled, bool btnValue) {
  //   setState(() {
  //     // switch (buttonIndex) {
  //     //   case 1:
  //     //     showIndividual = isToggled;
  //     //     break;
  //     //   case 2:
  //     //     showHistory = isToggled;
  //     //     break;
  //     //   case 3:
  //     //     showSpirit = isToggled;
  //     //     break;
  //     //   case 4:
  //     //     showTerrain = isToggled;
  //     //     break;
  //     // }
  //   });
  // }

  String receivedData = '';
  double temp = 0.0;
  int r = 255;
  int g = 255;
  int b = 255;
  double bat = 0.0;

  double sliderValue = 0.0;
  bool toggleValue = false;

  List<Color> gradientColors = []; // Color.fromARGB(255,255,255,255)

  static const int windowSize = 10; // Adjust the window size as needed
  List<int> redValues = List.filled(windowSize, 0);
  List<int> greenValues = List.filled(windowSize, 0);
  List<int> blueValues = List.filled(windowSize, 0);
  int index = 0;
  int count = 0;

  Color _currentColor = Colors.black;
  Color _nextColor = Colors.black;
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;

  StreamSubscription<List<ScanResult>>? scanResultsSubscription;
  Map<String, int> deviceRssi = {};

  List<double>? _gyroscopeValues = [0, 0, 0];

  final _streamSubscriptions = <StreamSubscription<dynamic>>[];

  Location location = Location();
  LocationData? _currentPosition;

  StreamSubscription? bleSubscription;

  // FlutterBlue flutterBlue = FlutterBlue.instance;
  StreamSubscription? _scanSubscription;
  // Timer? _timer;

  final _txController = TextEditingController();

  void resetDevicesDataAndScan() async {
    if (scanResultsSubscription == null) {
      scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          String deviceName = result.device.localName;
          print('>>> Found $deviceName with rssi: ${result.rssi}');
          if (deviceName != widget.deviceId &&
              moodyDeviceNameRegExp.hasMatch(deviceName.toUpperCase())) {
            deviceRssi[deviceName] = result.rssi;
            // if (mounted)
            // setState(() {});
          }
        }
      });
    }
    deviceRssi = {};
    if (FlutterBluePlus.isScanningNow == false) {
      print('>>> Startscan START');
      FlutterBluePlus.startScan(
          timeout: const Duration(seconds: 15), androidUsesFineLocation: false);
      print('>>> Startscan END');

      Future.delayed(const Duration(seconds: 15), () async {
        // Stop scanning
        //  _scanSubscription?.cancel();""
        print('>>> Stopscan START');
        await FlutterBluePlus.stopScan();
        print('>>> Stopscan END');
      });
    } else {
      print('>>> already scanning');
    }
  }

  void _animateColorTransition() {
    _colorAnimation =
        ColorTween(begin: _currentColor, end: _nextColor).animate(_controller)
          ..addListener(() {
            setState(() {});
          });

    _controller.reset();
    _controller.forward().then((_) {
      _currentColor = _nextColor;
    });
  }

// Don't forget to cancel the bleSubscription when it's no longer needed
  @override
  void dispose() async {
    KeepScreenOn.turnOff();
    _controller.dispose();

    _scanSubscription?.cancel();
    cleanUpScanning();
    //traverse through each element of list
    for (var i = 0; i < _streamSubscriptions.length.toInt(); i++) {
      await _streamSubscriptions[i].cancel();
    }
    await bleSubscription?.cancel();

    await widget.device.disconnect();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _colorAnimation =
        ColorTween(begin: _currentColor, end: _nextColor).animate(_controller)
          ..addListener(() {
            setState(() {});
          });
    _streamSubscriptions.add(
      gyroscopeEvents.listen(
        (GyroscopeEvent event) {
          if (mounted) {
            setState(() {
              _gyroscopeValues = <double>[event.x, event.y, event.z];
            });
          }
        },
        onError: (e) {
          showDialog(
              context: context,
              builder: (context) {
                return const AlertDialog(
                  title: Text('Sensor Not Found'),
                  content: Text(
                      'It seems that your device doesn\'t support User Accelerometer Sensor'),
                );
              });
        },
        cancelOnError: true,
      ),
    );

    getLoc();
    // scanForDevices();
    resetDevicesDataAndScan();
    connectToDevice();
  }

  void cleanUpScanning() async {
    if (FlutterBluePlus.isScanningNow == true) {
      await FlutterBluePlus.stopScan();
    }
    await scanResultsSubscription?.cancel();
    // if scanning: stop background ble scanning
  }

  getLoc() async {
    bool _serviceEnabled;

    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        return;
      }
    }

    _currentPosition = await location.getLocation();
    location.onLocationChanged.listen((LocationData currentLocation) {
      print('${currentLocation.longitude} : ${currentLocation.longitude}');
      if (mounted) {
        setState(() {
          _currentPosition = currentLocation;
        });
      }
    });
  }

  connectToDevice() async {
    print("pre sharedPrefs: connectToDevice");

    await widget.device.connect();

    // Save the deviceId to SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_id', widget.deviceId);
    print("Set to sharedPrefs: ${widget.deviceId}");

    KeepScreenOn.turnOn();

    final snackBar = const SnackBar(content: Text('Connected'));
    snackBarKeyC.currentState?.showSnackBar(snackBar);

    // await widget.device.requestMtu(128);
    // int mtu = await widget.device.mtu.first;
    // while (mtu != 128) {
    //   print("Waiting for requested MTU");
    //   await Future.delayed(Duration(seconds: 1));
    //   await widget.device.requestMtu(128);

    //   mtu = await widget.device.mtu.first;
    // }
    discoverServices();
  }

  discoverServices() async {
    List<BluetoothService> services = await widget.device.discoverServices();
    services.forEach((service) {
      // UUIDs for the UART service and its RX and TX characteristics
      const uartServiceUuid = '6E400001-B5A3-F393-E0A9-E50E24DCCA9E';
      const rxCharacteristicUuid = '6E400002-B5A3-F393-E0A9-E50E24DCCA9E';
      const txCharacteristicUuid = '6E400003-B5A3-F393-E0A9-E50E24DCCA9E';

      if (service.uuid.toString().toUpperCase() == uartServiceUuid) {
        service.characteristics.forEach((characteristic) {
          if (characteristic.uuid.toString().toUpperCase() ==
              txCharacteristicUuid) {
            // Read and listen to changes to the TX characteristic
            characteristic.setNotifyValue(true);
            print('Listen to service');
            bleSubscription =
                characteristic.lastValueStream.listen((value) async {
              // String receivedData = '2175|(0,225,35)'; // Your received string.
              String localReceivedData = String.fromCharCodes(value);

              List<String> splitData = localReceivedData.split('|');
              var l = splitData.length;
              print('length: $l');
              print('Received $localReceivedData');

              //Received 1829|(0, 80, 174)
// I/flutter (  724): Invalid data received: 1829|(0, 80, 174)

              if (splitData.length == 2 && splitData[1] != 'None') {
                String tempString =
                    splitData[0]; // String representation of TEMP*100.

                String rgbString = splitData[1]
                    .replaceAll('(', '')
                    .replaceAll(')', ''); // String representation of (R,G,B).

                double localTemp = double.parse((tempString)) /
                    100; // Divide by 100 to get the original temperature.

                List<String> rgbStrings = rgbString.split(',');
                int _r = int.parse(rgbStrings[0]);
                int _g = int.parse(rgbStrings[1]);
                int _b = int.parse(rgbStrings[2]);

                Color c = Color.fromARGB(255, _r, _g, _b);
                _updateAverageColor(_r, _g, _b);

                double _bat = 0.0; //double.parse(splitData[2]);

                print(
                    '${widget.deviceId} >> Temperature: $localTemp, R: $_r, G: $_g, B: $_b, Battery: $_bat'); // Check the parsed values.

                List<Color> updatedColors = List.from(gradientColors)
                  ..insert(0, c); // .add(c);

                while (updatedColors.length > 50) {
                  updatedColors.removeLast(); // removes the first item
                }

                if (mounted) {
                  setState(() {
                    receivedData = localReceivedData;
                    temp = localTemp;
                    r = _r;
                    g = _g;
                    b = _b;
                    bat = _bat;
                    gradientColors = updatedColors;

                    // gradientColors.add(c);
                    // gradientColors = List.from(gradientColors)..add(c);
                    // print('Colors after update: $gradientColors');
                  });
                }

                // cleanUpScanning();

                final response = await http.get(
                  Uri.http(serverHost, '/addData', {
                    'moodid': widget.deviceId,
                    'temperature': localTemp.toStringAsFixed(2),
                    'battery': _bat.toStringAsFixed(2),
                    'color': jsonEncode([_r, _g, _b]),
                    'excitement': '0',
                    'location': jsonEncode([
                      _currentPosition?.latitude,
                      _currentPosition?.longitude
                    ]),
                    'proximity': jsonEncode(deviceRssi.entries
                        .map((entry) =>
                            {'id': entry.key, 'distance': entry.value})
                        .toList()),
                    'gyro': jsonEncode(_gyroscopeValues),
                  }),
                );

                if (response.statusCode == 200) {
                  // If the server returns a 200 OK response,
                  // then parse the JSON.
                  print('Response data: ${(response.body)}');
                } else {
                  // If the server did not return a 200 OK response,
                  // then throw an exception.
                  throw Exception('Failed to get data.');
                }

                print('>>> Try resetDevicesDataAndScan');
                resetDevicesDataAndScan();
              } else if (splitData.length > 2 && splitData[1] != 'None') {
                String tempString =
                    splitData[0]; // String representation of TEMP*100.

                String rgbString = splitData[1]
                    .replaceAll('(', '')
                    .replaceAll(')', ''); // String representation of (R,G,B).

                double localTemp = double.parse((tempString)) /
                    100; // Divide by 100 to get the original temperature.

                List<String> rgbStrings = rgbString.split(',');
                int _r = int.parse(rgbStrings[1]);
                int _g = int.parse(rgbStrings[0]);
                int _b = int.parse(rgbStrings[2]);

                Color c = Color.fromARGB(255, _r, _g, _b);
                _updateAverageColor(_r, _g, _b);

                double _bat = double.parse(splitData[2]);

                print(
                    '${widget.deviceId} >> Temperature: $localTemp, R: $_r, G: $_g, B: $_b, Battery: $_bat'); // Check the parsed values.

                List<Color> updatedColors = List.from(gradientColors)
                  ..insert(0, c); // .add(c);

                while (updatedColors.length > 50) {
                  updatedColors.removeLast(); // removes the first item
                }

                if (mounted) {
                  setState(() {
                    receivedData = localReceivedData;
                    temp = localTemp;
                    r = _r;
                    g = _g;
                    b = _b;
                    bat = _bat;
                    gradientColors = updatedColors;

                    // gradientColors.add(c);
                    // gradientColors = List.from(gradientColors)..add(c);
                    // print('Colors after update: $gradientColors');
                  });
                }

                // cleanUpScanning();

                try {
                  final response = await http.get(
                    Uri.http(serverHost, '/addData', {
                      'moodid': widget.deviceId,
                      'temperature': localTemp.toStringAsFixed(2),
                      'battery': _bat.toStringAsFixed(2),
                      'color': jsonEncode([_r, _g, _b]),
                      'excitement': '0',
                      'location': jsonEncode([
                        _currentPosition?.latitude,
                        _currentPosition?.longitude
                      ]),
                      'proximity': jsonEncode(deviceRssi.entries
                          .map((entry) =>
                              {'id': entry.key, 'distance': entry.value})
                          .toList()),
                      'gyro': jsonEncode(_gyroscopeValues),
                    }),
                  );

                  if (response.statusCode == 200) {
                    // If the server returns a 200 OK response,
                    // then parse the JSON.
                    print('Response data: ${(response.body)}');
                  } else {
                    // If the server did not return a 200 OK response,
                    // then throw an exception.
                    throw Exception('Failed to get data.');
                  }
                } on Exception catch (e) {
                  print("Error server $e");
                }

                print('>>> Try resetDevicesDataAndScan');
                resetDevicesDataAndScan();

                // // start background scan
                // startShortScan();
              } else {
                print('Invalid data received: $localReceivedData');
                if (mounted) {
                  setState(() {
                    receivedData = localReceivedData;
                  });
                }
              }
            });
          } else if (characteristic.uuid.toString().toUpperCase() ==
              rxCharacteristicUuid) {
            // Write the text to the RX characteristic when the button is pressed
            if (_txController.text.isNotEmpty) {
              characteristic.write(utf8.encode(_txController.text));
            }
          }
        });
      }
    });
  }

  void _updateAverageColor(int red, int green, int blue) {
    if (count < windowSize) {
      count++;
    }
    redValues[index] = red;
    greenValues[index] = green;
    blueValues[index] = blue;
    index = (index + 1) % windowSize;

    int redSum = redValues.take(count).reduce((a, b) => a + b);
    int greenSum = greenValues.take(count).reduce((a, b) => a + b);
    int blueSum = blueValues.take(count).reduce((a, b) => a + b);

    int avgRed = (redSum / count).toInt();
    int avgGreen = (greenSum / count).toInt();
    int avgBlue = (blueSum / count).toInt();

    print("#> color: _currentColor before: $_currentColor");
    print("#> color: _nextColor before: $_nextColor");
    _currentColor = _nextColor;
    _nextColor = Color.fromARGB(255, avgRed, avgGreen, avgBlue);
    print("#> color: _currentColor after: $_currentColor");
    print("#> color: _nextColor after: $_nextColor");
    _animateColorTransition();
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;
    double AR = screenHeight / screenWidth;

    return ScaffoldMessenger(
      key: snackBarKeyC,
      child: Scaffold(
        // appBar: AppBar(
        //   // title: Text(widget.device.localName),
        //   actions: <Widget>[
        //     StreamBuilder<BluetoothConnectionState>(
        //       stream: widget.device.connectionState,
        //       initialData: BluetoothConnectionState.connecting,
        //       builder: (c, snapshot) {
        //         VoidCallback? onPressed;
        //         String text;
        //         switch (snapshot.data) {
        //           case BluetoothConnectionState.connected:
        //             onPressed = () async {
        //               try {
        //                 await bleSubscription?.cancel();

        //                 cleanUpScanning();

        //                 await widget.device.disconnect();
        //               } catch (e) {
        //                 final snackBar = SnackBar(
        //                     content:
        //                         Text(prettyException('Disconnect Error:', e)));
        //                 snackBarKeyC.currentState?.showSnackBar(snackBar);
        //               }
        //             };
        //             text = 'DISCONNECT';
        //             break;
        //           case BluetoothConnectionState.disconnected:
        //             onPressed = () async {
        //               try {
        //                 await widget.device
        //                     .connect(timeout: Duration(seconds: 4));
        //               } catch (e) {
        //                 final snackBar = SnackBar(
        //                     content:
        //                         Text(prettyException('Connect Error:', e)));
        //                 snackBarKeyC.currentState?.showSnackBar(snackBar);
        //               }
        //             };
        //             text = 'CONNECT';
        //             break;
        //           default:
        //             onPressed = null;
        //             text =
        //                 snapshot.data.toString().split('.').last.toUpperCase();
        //             break;
        //         }
        //         return TextButton(
        //             onPressed: onPressed,
        //             child: Text(
        //               text,
        //               style: Theme.of(context)
        //                   .primaryTextTheme
        //                   .labelLarge
        //                   ?.copyWith(color: Colors.white),
        //             ));
        //       },
        //     )
        //   ],
        // ),
        body: Container(
          key: ValueKey(gradientColors.length),
          decoration: buttonStates["showSpirit"]!
              ? (buttonStates["showHistory"]! && gradientColors.length >= 2
                  ? BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.0, 1.0),
                        radius: AR, // 0.5,
                        colors: gradientColors,
                      ),
                    )
                  : BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.0, 1.0),
                        radius: AR, // 0.5,
                        colors: [_currentColor, _colorAnimation.value!],
                      ),
                    ))
              : null,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const SizedBox(height: 10),
              const Text('Your Title'),
              Slider(
                value: sliderValue,
                min: 0,
                max: 100,
                onChanged: (double value) {
                  if (mounted) {
                    setState(() {
                      sliderValue = value;
                    });
                  }
                },
              ),
              Switch(
                value: toggleValue,
                onChanged: (bool value) {
                  if (mounted) {
                    setState(() {
                      toggleValue = value;
                    });
                  }
                },
              ),
              Text('Device ID: ${widget.device.localName}',
                  style: const TextStyle(fontSize: 10)),
              Text(
                  'Temperature: ${(temp < 1 ? temp * 100 : temp).toStringAsFixed(2)}°C',
                  style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 10),
              Text('Battery: ${bat.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  /*
                    bool showIndividual = false;
  bool showHistory = false;
  bool showSpirit = true;
  bool showTerrain = true;
  */
                  ToggleImageButton(
                    initialImage: 'assets/images/icons-Individual1.png',
                    toggledImage: 'assets/images/icons-group1.png',
                    initialState: buttonStates["showIndividual"]!,
                    onToggle: (isToggled) =>
                        _handleToggle(isToggled, "showIndividual"),
                  ),
                  ToggleImageButton(
                    initialImage: 'assets/images/NOW.png',
                    toggledImage: 'assets/images/NOW+History9.png',
                    initialState: buttonStates["showHistory"]!,
                    onToggle: (isToggled) =>
                        _handleToggle(isToggled, "showHistory"),
                  ),
                  ToggleImageButton(
                    initialImage: 'assets/images/spirit2-grey.png',
                    toggledImage: 'assets/images/spirit2.png',
                    initialState: buttonStates["showSpirit"]!,
                    onToggle: (isToggled) =>
                        _handleToggle(isToggled, "showSpirit"),
                  ),
                  ToggleImageButton(
                    initialImage: 'assets/images/terrain-grey.png',
                    toggledImage: 'assets/images/terrain.png',
                    initialState: buttonStates["showTerrain"]!,
                    onToggle: (isToggled) =>
                        _handleToggle(isToggled, "showTerrain"),
                  ),

                  // ToggleImageButton(
                  //   initialImage: 'assets/images/icons-Individual1.png',
                  //   toggledImage: 'assets/images/icons-group1.png',
                  //   onToggle: (isToggled) => _handleToggle(isToggled, showIndividual),
                  // ),
                  // ToggleImageButton(
                  //   initialImage: 'assets/images/NOW+History9.png',
                  //   toggledImage: 'assets/images/NOW.png',
                  //   onToggle: (isToggled) => _handleToggle(isToggled, showHistory),
                  // ),
                  // ToggleImageButton(
                  //   initialImage: 'assets/images/spirit2.png',
                  //   toggledImage: 'assets/images/spirit2-grey.png',
                  //   onToggle: (isToggled) => _handleToggle(isToggled, showSpirit),
                  // ),
                  // ToggleImageButton(
                  //   initialImage: 'assets/images/terrain-grey.png',
                  //   toggledImage: 'assets/images/terrain.png',
                  //   onToggle: (isToggled) => _handleToggle(isToggled, showTerrain),
                  // ),

                  // Expanded(
                  //   child: GestureDetector(
                  //     onTap: () {
                  //       setState(() {
                  //         showIndividual = !showIndividual;
                  //         _imagePathButton0 = showIndividual
                  //             ? 'assets/images/icons-Individual1.png'
                  //             : 'assets/images/icons-group1.png';
                  //       });
                  //     },
                  //     child: Container(
                  //       height: MediaQuery.of(context).size.width /
                  //           4, // Ensuring the buttons are square
                  //       decoration: BoxDecoration(
                  //         image: DecorationImage(
                  //           image: AssetImage(_imagePathButton0),
                  //           fit: BoxFit.cover,
                  //         ),
                  //         border:
                  //             null, // Optional: add a border to distinguish the buttons
                  //       ),
                  //     ),
                  //   ),
                  // ),
                  // Expanded(
                  //   child: GestureDetector(
                  //     onTap: () {
                  //       setState(() {
                  //         showHistory = !showHistory;
                  //         _imagePathButton1 = showHistory
                  //             ? 'assets/images/NOW+History9.png'
                  //             : 'assets/images/NOW.png';
                  //       });
                  //     },
                  //     child: Container(
                  //       height: MediaQuery.of(context).size.width /
                  //           4, // Ensuring the buttons are square
                  //       decoration: BoxDecoration(
                  //         image: DecorationImage(
                  //           image: AssetImage(_imagePathButton1),
                  //           fit: BoxFit.cover,
                  //         ),
                  //         border:
                  //             null, // Optional: add a border to distinguish the buttons
                  //       ),
                  //     ),
                  //   ),
                  // ),
                  // Expanded(
                  //   child: GestureDetector(
                  //     onTap: () {
                  //       setState(() {
                  //         showSpirit = !showSpirit;
                  //         _imagePathButton2 = showSpirit
                  //             ? 'assets/images/spirit2.png'
                  //             : 'assets/images/spirit2-grey.png';
                  //       });
                  //     },
                  //     child: Container(
                  //       height: MediaQuery.of(context).size.width /
                  //           4, // Ensuring the buttons are square
                  //       decoration: BoxDecoration(
                  //         image: DecorationImage(
                  //           image: AssetImage(_imagePathButton2),
                  //           fit: BoxFit.cover,
                  //         ),
                  //         border:
                  //             null, // Optional: add a border to distinguish the buttons
                  //       ),
                  //     ),
                  //   ),
                  // ),
                  // Expanded(
                  //   child: GestureDetector(
                  //     onTap: () {
                  //       setState(() {
                  //         showTerrain = !showTerrain;
                  //         _imagePathButton3 = showTerrain
                  //             ? 'assets/images/terrain.png'
                  //             : 'assets/images/terrain-grey.png';
                  //       });
                  //     },
                  //     child: Container(
                  //       height: MediaQuery.of(context).size.width /
                  //           4, // Ensuring the buttons are square
                  //       decoration: BoxDecoration(
                  //         image: DecorationImage(
                  //           image: AssetImage(_imagePathButton3),
                  //           fit: BoxFit.cover,
                  //         ),
                  //         border:
                  //             null, // Optional: add a border to distinguish the buttons
                  //       ),
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
