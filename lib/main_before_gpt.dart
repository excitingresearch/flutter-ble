// Copyright 2017, Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:sensors_plus/sensors_plus.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:flutter_blue/flutter_blue.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:flutter_ble_moody/widgets.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:location/location.dart';

final snackBarKeyA = GlobalKey<ScaffoldMessengerState>();
final snackBarKeyB = GlobalKey<ScaffoldMessengerState>();
final snackBarKeyC = GlobalKey<ScaffoldMessengerState>();
final snackBarKeyNFC = GlobalKey<ScaffoldMessengerState>();

//final String serverHost = '192.168.10.139:2000';
final String serverHost = '134.122.18.168:2000';

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
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RFID Scanner App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: FirstScreen(),
    );
  }
}

class FirstScreen extends StatefulWidget {
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
    setState(() {
      polling = true;
      pollingEnded = false;
    });
    while (polling && _deviceIdController.text.isEmpty) {
      print('poll');
      try {
        NFCTag tag = await FlutterNfcKit.poll(
            timeout: Duration(seconds: 3),
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

            if (!found && RegExp(r'^m\d{3}$').hasMatch(payloadAsString)) {
              found = true;
              setState(() {
                _deviceIdController.text = payloadAsString;
                polling = false;
              });
            }
          }
        }

        if (!found) {
          print('No moody device');
          final snackBar = SnackBar(content: Text('No MOODY device'));
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
    setState(() {
      pollingEnded = true;
    });
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
            title: Text('Connect MOODY device'),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Column(
                  children: <Widget>[
                    Container(
                      width: 150.0,
                      child: Text(
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
                          setState(
                              () {}); // To ensure the button's onPressed status gets updated.
                        },
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Device ID',
                        ),
                      ),
                    ),
                  ],
                ),
                ElevatedButton(
                  child: Text('Go to second screen'),
                  onPressed: deviceId.isNotEmpty &&
                          RegExp(r'^m\d{3}$').hasMatch(deviceId)
                      ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  FlutterBlueApp(deviceId: deviceId),
                            ),
                          ).then((value) {
                            print('back here');
                            pollRFID();
                          })
                      : null,
                ),
                ElevatedButton(
                  child: !polling ? Text('Scan') : Text('Stop'),
                  onPressed: !polling
                      ? () {
                          //_deviceIdController.clear();
                          if (pollingEnded)
                            pollRFID();
                          else
                            setState(() {
                              polling = true;
                            });
                        }
                      : () {
                          print('stop $polling');
                          //_deviceIdController.clear();
                          setState(() {
                            polling = false;
                          });
                        },
                ),
                ElevatedButton(
                  child: Text('Clear'),
                  onPressed: deviceId.isNotEmpty
                      ? () {
                          _deviceIdController.clear();
                          pollRFID();
                        }
                      : null,
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

class FlutterBlueApp extends StatelessWidget {
  final String deviceId;

  const FlutterBlueApp({Key? key, required this.deviceId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      color: Colors.lightBlue,
      home: StreamBuilder<BluetoothAdapterState>(
          stream: FlutterBluePlus.adapterState,
          initialData: BluetoothAdapterState.unknown,
          builder: (c, snapshot) {
            final adapterState = snapshot.data;
            if (adapterState == BluetoothAdapterState.on) {
              return FindDevicesScreen(deviceId: deviceId);
            } else {
              FlutterBluePlus.stopScan();
              return BluetoothOffScreen(adapterState: adapterState);
            }
          }),
      navigatorObservers: [BluetoothAdapterStateObserver()],
    );
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

class BluetoothOffScreen extends StatelessWidget {
  const BluetoothOffScreen({Key? key, this.adapterState}) : super(key: key);

  final BluetoothAdapterState? adapterState;

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: snackBarKeyA,
      child: Scaffold(
        backgroundColor: Colors.lightBlue,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.bluetooth_disabled,
                size: 200.0,
                color: Colors.white54,
              ),
              Text(
                'Bluetooth Adapter is ${adapterState != null ? adapterState.toString().split('.').last : 'not available'}.',
                style: Theme.of(context)
                    .primaryTextTheme
                    .titleSmall
                    ?.copyWith(color: Colors.white),
              ),
              if (Platform.isAndroid)
                ElevatedButton(
                  child: const Text('TURN ON'),
                  onPressed: () async {
                    try {
                      if (Platform.isAndroid) {
                        await FlutterBluePlus.turnOn();
                      }
                    } catch (e) {
                      final snackBar = SnackBar(
                          content:
                              Text(prettyException('Error Turning On:', e)));
                      snackBarKeyA.currentState?.showSnackBar(snackBar);
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class FindDevicesScreen extends StatefulWidget {
  final String deviceId;
  FindDevicesScreen({Key? key, required this.deviceId}) : super(key: key);
  @override
  _FindDevicesScreenState createState() => _FindDevicesScreenState();
}

class _FindDevicesScreenState extends State<FindDevicesScreen> {
  @override
  void initState() {
    super.initState();
    print('FindDevicesScreen was created');

    try {
      if (FlutterBluePlus.isScanningNow == false) {
        FlutterBluePlus.startScan(
            timeout: const Duration(seconds: 15),
            androidUsesFineLocation: false);
      }
    } catch (e) {
      final snackBar =
          SnackBar(content: Text(prettyException('Start Scan Error:', e)));
      snackBarKeyB.currentState?.showSnackBar(snackBar);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: snackBarKeyB,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Find Device: ${widget.deviceId}'), // + deviceId),
        ),
        body: RefreshIndicator(
          onRefresh: () {
            if (FlutterBluePlus.isScanningNow == false) {
              return FlutterBluePlus.startScan(
                  timeout: const Duration(seconds: 15),
                  androidUsesFineLocation: false);
            }
            return Future.value();
          },
          child: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                StreamBuilder<List<BluetoothDevice>>(
                  stream: Stream.periodic(const Duration(seconds: 5))
                      .asyncMap((_) => FlutterBluePlus.connectedSystemDevices),
                  initialData: const [],
                  builder: (c, snapshot) => Column(
                    children: (snapshot.data ?? [])
                        .map((d) => ListTile(
                              title: Text(d.localName),
                              subtitle: Text(d.remoteId.toString()),
                              trailing: StreamBuilder<BluetoothConnectionState>(
                                stream: d.connectionState,
                                initialData:
                                    BluetoothConnectionState.disconnected,
                                builder: (c, snapshot) {
                                  if (snapshot.data ==
                                      BluetoothConnectionState.connected) {
                                    return ElevatedButton(
                                      child: const Text('OPEN'),
                                      onPressed: () => Navigator.of(context)
                                          .push(MaterialPageRoute(
                                              builder: (context) =>
                                                  DeviceScreen(
                                                      device: d,
                                                      deviceId:
                                                          widget.deviceId),
                                              settings: RouteSettings(
                                                  name: '/deviceScreen'))),
                                    );
                                  }
                                  if (snapshot.data ==
                                      BluetoothConnectionState.disconnected) {
                                    return ElevatedButton(
                                        child: const Text('CONNECT'),
                                        onPressed: () {
                                          Navigator.of(context).push(
                                              MaterialPageRoute(
                                                  builder: (context) {
                                                    d
                                                        .connect(
                                                            timeout: Duration(
                                                                seconds: 4))
                                                        .catchError((e) {
                                                      final snackBar = SnackBar(
                                                          content: Text(
                                                              prettyException(
                                                                  'Connect Error:',
                                                                  e)));
                                                      snackBarKeyB.currentState
                                                          ?.showSnackBar(
                                                              snackBar);
                                                    });
                                                    return DeviceScreen(
                                                        device: d,
                                                        deviceId:
                                                            widget.deviceId);
                                                  },
                                                  settings: RouteSettings(
                                                      name: '/deviceScreen')));
                                        });
                                  }
                                  return Text(snapshot.data
                                      .toString()
                                      .toUpperCase()
                                      .split('.')[1]);
                                },
                              ),
                            ))
                        .toList(),
                  ),
                ),
                StreamBuilder<List<ScanResult>>(
                  stream: FlutterBluePlus.scanResults,
                  initialData: const [],
                  builder: (c, snapshot) => Column(
                    children: (snapshot.data ?? [])
                        .where((r) =>
                            r.device.localName ==
                            widget.deviceId) // Filter based on deviceId

                        .map(
                          (r) => ScanResultTile(
                            result: r,
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (context) {
                                      r.device
                                          .connect(
                                              timeout: Duration(seconds: 4))
                                          .catchError((e) {
                                        final snackBar = SnackBar(
                                            content: Text(prettyException(
                                                'Connect Error:', e)));
                                        snackBarKeyB.currentState
                                            ?.showSnackBar(snackBar);
                                      });
                                      return DeviceScreen(
                                          device: r.device,
                                          deviceId: widget.deviceId);
                                    },
                                    settings:
                                        RouteSettings(name: '/deviceScreen'))),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: StreamBuilder<bool>(
          stream: FlutterBluePlus.isScanning,
          initialData: false,
          builder: (c, snapshot) {
            if (snapshot.data ?? false) {
              return FloatingActionButton(
                child: const Icon(Icons.stop),
                onPressed: () async {
                  try {
                    FlutterBluePlus.stopScan();
                  } catch (e) {
                    final snackBar = SnackBar(
                        content: Text(prettyException('Stop Scan Error:', e)));
                    snackBarKeyB.currentState?.showSnackBar(snackBar);
                  }
                },
                backgroundColor: Colors.red,
              );
            } else {
              return FloatingActionButton(
                  child: const Icon(Icons.search),
                  onPressed: () async {
                    try {
                      if (FlutterBluePlus.isScanningNow == false) {
                        FlutterBluePlus.startScan(
                            timeout: const Duration(seconds: 15),
                            androidUsesFineLocation: false);
                      }
                    } catch (e) {
                      final snackBar = SnackBar(
                          content:
                              Text(prettyException('Start Scan Error:', e)));
                      snackBarKeyB.currentState?.showSnackBar(snackBar);
                    }
                  });
            }
          },
        ),
      ),
    );
  }
}

class DeviceScreen extends StatefulWidget {
  const DeviceScreen({Key? key, required this.device, required this.deviceId})
      : super(key: key);

  final BluetoothDevice device;
  final String deviceId;

  @override
  _DeviceScreenState createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  String receivedData = '';
  double temp = 0.0;
  int r = 255;
  int g = 255;
  int b = 255;
  double bat = 0.0;

  double sliderValue = 0.0;
  bool toggleValue = false;

  List<Color> gradientColors = []; // Color.fromARGB(255,255,255,255)

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
              RegExp(r'^m\d{3}$').hasMatch(deviceName)) {
            deviceRssi[deviceName] = result.rssi;
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

      Future.delayed(Duration(seconds: 15), () async {
        // Stop scanning
        //  _scanSubscription?.cancel();
        print('>>> Stopscan START');
        await FlutterBluePlus.stopScan();
        print('>>> Stopscan END');
      });
    } else {
      print('>>> already scanning');
    }
  }

// Don't forget to cancel the bleSubscription when it's no longer needed
  @override
  void dispose() async {
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

    _streamSubscriptions.add(
      gyroscopeEvents.listen(
        (GyroscopeEvent event) {
          setState(() {
            _gyroscopeValues = <double>[event.x, event.y, event.z];
          });
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
      setState(() {
        _currentPosition = currentLocation;
      });
    });
  }

  connectToDevice() async {
    await widget.device.connect();
    final snackBar = SnackBar(content: Text('Connected'));
    snackBarKeyC.currentState?.showSnackBar(snackBar);
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

              if (splitData.length > 2 && splitData[1] != 'None') {
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

                double _bat = double.parse(splitData[2]);

                print(
                    '${widget.deviceId} >> Temperature: $localTemp, R: $_r, G: $_g, B: $_b, Battery: $_bat'); // Check the parsed values.

                List<Color> updatedColors = List.from(gradientColors)
                  ..insert(0, c); // .add(c);

                while (updatedColors.length > 50) {
                  updatedColors.removeLast(); // removes the first item
                }

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

                // // start background scan
                // startShortScan();
              } else {
                print('Invalid data received: $localReceivedData');
                setState(() {
                  receivedData = localReceivedData;
                });
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

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;
    double AR = screenHeight / screenWidth;

    return ScaffoldMessenger(
      key: snackBarKeyC,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.device.localName),
          actions: <Widget>[
            StreamBuilder<BluetoothConnectionState>(
              stream: widget.device.connectionState,
              initialData: BluetoothConnectionState.connecting,
              builder: (c, snapshot) {
                VoidCallback? onPressed;
                String text;
                switch (snapshot.data) {
                  case BluetoothConnectionState.connected:
                    onPressed = () async {
                      try {
                        await bleSubscription?.cancel();

                        cleanUpScanning();

                        await widget.device.disconnect();
                      } catch (e) {
                        final snackBar = SnackBar(
                            content:
                                Text(prettyException('Disconnect Error:', e)));
                        snackBarKeyC.currentState?.showSnackBar(snackBar);
                      }
                    };
                    text = 'DISCONNECT';
                    break;
                  case BluetoothConnectionState.disconnected:
                    onPressed = () async {
                      try {
                        await widget.device
                            .connect(timeout: Duration(seconds: 4));
                      } catch (e) {
                        final snackBar = SnackBar(
                            content:
                                Text(prettyException('Connect Error:', e)));
                        snackBarKeyC.currentState?.showSnackBar(snackBar);
                      }
                    };
                    text = 'CONNECT';
                    break;
                  default:
                    onPressed = null;
                    text =
                        snapshot.data.toString().split('.').last.toUpperCase();
                    break;
                }
                return TextButton(
                    onPressed: onPressed,
                    child: Text(
                      text,
                      style: Theme.of(context)
                          .primaryTextTheme
                          .labelLarge
                          ?.copyWith(color: Colors.white),
                    ));
              },
            )
          ],
        ),
        body: Container(
          key: ValueKey(gradientColors.length),
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.0, 1.0),
              radius: AR, // 0.5,
              colors: gradientColors,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              SizedBox(height: 10),
              Text('Your Title'),
              Slider(
                value: sliderValue,
                min: 0,
                max: 100,
                onChanged: (double value) {
                  setState(() {
                    sliderValue = value;
                  });
                },
              ),
              Switch(
                value: toggleValue,
                onChanged: (bool value) {
                  setState(() {
                    toggleValue = value;
                  });
                },
              ),
              Text('Device ID: ${widget.device.localName}',
                  style: TextStyle(fontSize: 10)),
              Text('Temperature: $temp', style: TextStyle(fontSize: 24)),
              SizedBox(height: 10),
              Text('Battery: ${bat.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 24)),
              SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
