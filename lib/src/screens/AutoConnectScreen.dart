// Copyright 2017, Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:moody/src/providers/DeviceProvider.dart';
import 'package:moody/src/screens/DeviceScreen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AutoConnectScreen extends StatefulWidget {
  const AutoConnectScreen({Key? key}) : super(key: key);

  @override
  _AutoConnectScreenState createState() => _AutoConnectScreenState();
}

class _AutoConnectScreenState extends State<AutoConnectScreen> {
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
