// Copyright 2017, Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:flutter_ble_moody/widgets.dart';

void main() {
  // var x = 0;
  // var period = const Duration(milliseconds: 3500); // 4
  // Timer.periodic(period, (arg) {
  //   x = x + 1;
  //   print(x);

  //   try {
  //     // code that may cause an exception
  //     // FlutterBlue.instance.stopScan();

  //     // sleep(Duration(milliseconds: 1000)); // 1

  //     FlutterBlue.instance.startScan(
  //         timeout:
  //             Duration(milliseconds: 3000)); // timeout: Duration(seconds: 4)
  //   } catch (e) {
  //     // code that handles the exception
  //     print(e);
  //   }
  // });

  runApp(FlutterBlueApp());
}

String intToTimeLeft(int value) {
  int h, m, s, d;

  d = value ~/ (24 * 3600);
  h = (value - d * (24 * 3600)) ~/ 3600;

  m = ((value - d * (24 * 3600) - h * 3600)) ~/ 60;

  s = value - d * (24 * 3600) - (h * 3600) - (m * 60);

  String hourLeft = h.toString().length < 2 ? "0" + h.toString() : h.toString();

  String minuteLeft =
      m.toString().length < 2 ? "0" + m.toString() : m.toString();

  String secondsLeft =
      s.toString().length < 2 ? "0" + s.toString() : s.toString();

  String result = "$d $hourLeft:$minuteLeft:$secondsLeft";

  return result;
}

String getNiceHexArray(List<int> bytes) {
  return '[${bytes.map((i) => i.toRadixString(16).padLeft(2, '0')).join(', ')}]'
      .toUpperCase();
}

String getNiceServiceData(Map<String, List<int>> data) {
  if (data.isEmpty) {
    return 'N/A';
  }
  List<String> res = [];
  data.forEach((id, bytes) {
    res.add('${id.toUpperCase()}: ${getNiceHexArray(bytes)}');
  });
  return res.join(', ');
}

parseManufacturerData(data) {
  print(getNiceHexArray(data));
  var manufacturerData = Uint8List.fromList(new List<int>.from(data));
  //var pressure = ByteData.sublistView(manufacturerData, 6, 10);
  var temperature = ByteData.sublistView(manufacturerData, 4, 6);
  var battery = ByteData.sublistView(manufacturerData, 2, 4);
  //print("Pressure: ${pressure.getUint32(0, Endian.little)/100} psi");
  print("Temperature: ${temperature.getUint16(0, Endian.little)} \u{00B0}C");
  print("Battery: ${battery.getUint16(0, Endian.big)} %");

  var advCount = ByteData.sublistView(manufacturerData, 6, 10);
  print("Adv count: ${advCount.getUint32(0, Endian.big)}");
  var uptime = ByteData.sublistView(manufacturerData, 10, 14);
  print("ms: ${intToTimeLeft((uptime.getUint32(0, Endian.big) ~/ 10))}");
}

class FlutterBlueApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      color: Colors.lightBlue,
      home: StreamBuilder<BluetoothState>(
          stream: FlutterBlue.instance.state,
          initialData: BluetoothState.unknown,
          builder: (c, snapshot) {
            final state = snapshot.data;
            if (state == BluetoothState.on) {
              return FindDevicesScreen();
            }
            return BluetoothOffScreen(state: state);
          }),
    );
  }
}

class BluetoothOffScreen extends StatelessWidget {
  const BluetoothOffScreen({Key? key, this.state}) : super(key: key);

  final BluetoothState? state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.bluetooth_disabled,
              size: 200.0,
              color: Colors.white54,
            ),
            Text(
              'Bluetooth Adapter is ${state != null ? state.toString().substring(15) : 'not available'}.',
              style: Theme.of(context)
                  .primaryTextTheme
                  .headlineMedium
                  ?.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class FindDevicesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Find Devices'),
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            FlutterBlue.instance.startScan(), //timeout: Duration(seconds: 4)
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              StreamBuilder<List<BluetoothDevice>>(
                stream: Stream.periodic(Duration(seconds: 2))
                    .asyncMap((_) => FlutterBlue.instance.connectedDevices),
                initialData: [],
                builder: (c, snapshot) => Column(
                  children: snapshot.data!
                      .map((d) => ListTile(
                            title: Text(d.name),
                            subtitle: Text(d.id.toString()),
                            trailing: StreamBuilder<BluetoothDeviceState>(
                              stream: d.state,
                              initialData: BluetoothDeviceState.disconnected,
                              builder: (c, snapshot) {
                                if (snapshot.data ==
                                    BluetoothDeviceState.connected) {
                                  return ElevatedButton(
                                    child: Text('OPEN'),
                                    onPressed: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                DeviceScreen(device: d))),
                                  );
                                }
                                return Text(snapshot.data.toString());
                              },
                            ),
                          ))
                      .toList(),
                ),
              ),
              StreamBuilder<List<ScanResult>>(
                stream: FlutterBlue.instance.scanResults,
                // stream: Stream.periodic(Duration(seconds: 2))
                //     .asyncMap((_) => FlutterBlue.instance.scanResults),
                initialData: [],
                builder: (c, snapshot) => Column(
                  children: snapshot.data!
                      .where(
                          (r) => r.device.id.toString() == '34:85:18:05:47:96')
                      .map(
                        (r) => ScanResultTile(
                          result: r,
                          onTap:
                              // () {
                              //   print(r.device.id.toString());
                              //   print(
                              //       'Data: ${r.advertisementData.serviceData["0000feaa-0000-1000-8000-00805f9b34fb"]}');
                              //   // Pass it to our previous function
                              //   parseManufacturerData(
                              //       r.advertisementData.serviceData[
                              //           "0000feaa-0000-1000-8000-00805f9b34fb"]);
                              // }

                              //     () async {
                              //   print("CONNCERT");
                              //   await r.device.connect();
                              //   print("SERVICES");
                              //   List<BluetoothService> services =
                              //       await r.device.discoverServices();
                              //   services.forEach((service) async {
                              //     // do something with service
                              //     print(service);

                              //     // Reads all characteristics
                              //     var characteristics = service.characteristics;
                              //     for (BluetoothCharacteristic c
                              //         in characteristics) {
                              //       List<int> value = await c.read();
                              //       print(value);
                              //     }
                              //   });

                              //   print("SERVICES DONE");
                              // }

                              () => Navigator.of(context)
                                  .push(MaterialPageRoute(builder: (context) {
                            r.device.connect();
                            return DeviceScreen(device: r.device);
                          })),
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
        stream: FlutterBlue.instance.isScanning,
        initialData: false,
        builder: (c, snapshot) {
          if (snapshot.data!) {
            return FloatingActionButton(
              child: Icon(Icons.stop),
              onPressed: () => FlutterBlue.instance.stopScan(),
              backgroundColor: Colors.red,
            );
          } else {
            return FloatingActionButton(
                child: Icon(Icons.search),
                onPressed: () => FlutterBlue.instance
                    .startScan()); // timeout: Duration(seconds: 4)
          }
        },
      ),
    );
  }
}

class DeviceScreen extends StatelessWidget {
  const DeviceScreen({Key? key, required this.device}) : super(key: key);

  final BluetoothDevice device;

  List<int> _getRandomBytes() {
    final math = Random();
    return [
      math.nextInt(255),
      math.nextInt(255),
      math.nextInt(255),
      math.nextInt(255)
    ];
  }

  List<Widget> _buildServiceTiles(List<BluetoothService> services) {
    return services
        .map(
          (s) => ServiceTile(
            service: s,
            characteristicTiles: s.characteristics
                .map(
                  (c) => CharacteristicTile(
                    characteristic: c,
                    onReadPressed: () => c.read(),
                    onWritePressed: () async {
                      await c.write(_getRandomBytes(), withoutResponse: true);
                      await c.read();
                    },
                    onNotificationPressed: () async {
                      await c.setNotifyValue(!c.isNotifying);
                      await c.read();
                    },
                    descriptorTiles: c.descriptors
                        .map(
                          (d) => DescriptorTile(
                            descriptor: d,
                            onReadPressed: () => d.read(),
                            onWritePressed: () => d.write(_getRandomBytes()),
                          ),
                        )
                        .toList(),
                  ),
                )
                .toList(),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(device.name),
        actions: <Widget>[
          StreamBuilder<BluetoothDeviceState>(
            stream: device.state,
            initialData: BluetoothDeviceState.connecting,
            builder: (c, snapshot) {
              VoidCallback? onPressed;
              String text;
              switch (snapshot.data) {
                case BluetoothDeviceState.connected:
                  onPressed = () => device.disconnect();
                  text = 'DISCONNECT';
                  break;
                case BluetoothDeviceState.disconnected:
                  onPressed = () => device.connect();
                  text = 'CONNECT';
                  break;
                default:
                  onPressed = null;
                  text = snapshot.data.toString().substring(21).toUpperCase();
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
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            StreamBuilder<BluetoothDeviceState>(
              stream: device.state,
              initialData: BluetoothDeviceState.connecting,
              builder: (c, snapshot) => ListTile(
                leading: (snapshot.data == BluetoothDeviceState.connected)
                    ? Icon(Icons.bluetooth_connected)
                    : Icon(Icons.bluetooth_disabled),
                title: Text(
                    'Device is ${snapshot.data.toString().split('.')[1]}.'),
                subtitle: Text('${device.id}'),
                trailing: StreamBuilder<bool>(
                  stream: device.isDiscoveringServices,
                  initialData: false,
                  builder: (c, snapshot) => IndexedStack(
                    index: snapshot.data! ? 1 : 0,
                    children: <Widget>[
                      IconButton(
                        icon: Icon(Icons.refresh),
                        onPressed: () => device.discoverServices(),
                      ),
                      IconButton(
                        icon: SizedBox(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(Colors.grey),
                          ),
                          width: 18.0,
                          height: 18.0,
                        ),
                        onPressed: null,
                      )
                    ],
                  ),
                ),
              ),
            ),
            StreamBuilder<int>(
              stream: device.mtu,
              initialData: 0,
              builder: (c, snapshot) => ListTile(
                title: Text('MTU Size'),
                subtitle: Text('${snapshot.data} bytes'),
                trailing: IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () => device.requestMtu(223),
                ),
              ),
            ),
            StreamBuilder<List<BluetoothService>>(
              stream: device.services,
              initialData: [],
              builder: (c, snapshot) {
                return Column(
                  children: _buildServiceTiles(snapshot.data!),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
