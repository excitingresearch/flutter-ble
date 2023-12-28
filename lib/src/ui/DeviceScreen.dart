import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class DeviceScreen extends StatefulWidget {
  final BluetoothDevice device;

  const DeviceScreen({Key? key, required this.device}) : super(key: key);

  @override
  _DeviceScreenState createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  StreamSubscription<BluetoothDevice>? _deviceConnection;
  List<BluetoothDevice> _foundDevices = [];
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  List<Color> _gradientColors = [Colors.blue, Colors.white];

  @override
  void initState() {
    super.initState();
    _startContinuousScanning();
    _connectToDevice(
        widget.device); // If you want to auto-connect to the passed device
  }

  @override
  void dispose() {
    _deviceConnection?.cancel();
    _scanSubscription?.cancel();
    super.dispose();
  }

  void _startContinuousScanning() {
    _scanSubscription = FlutterBluePlus.scanResults.listen(
      (results) {
        for (ScanResult result in results) {
          String deviceName = result.device.localName;
          print('>>> Found $deviceName with rssi: ${result.rssi}');
          if (!_foundDevices
              .any((device) => device.remoteId == result.device.remoteId)) {
            setState(() {
              _foundDevices.add(result.device);
            });
          }
        }
      },
      onError: _handleScanError,
    );

    FlutterBluePlus.startScan();
  }

  void _handleScanError(dynamic error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error scanning for BLE devices: $error'),
      ),
    );
    // Handle the error or stop scanning if necessary
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.localName),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _foundDevices.clear();
              });
              _startContinuousScanning();
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _gradientColors,
          ),
        ),
        child: _foundDevices.isEmpty
            ? Center(child: Text('No devices found.'))
            : ListView.builder(
                itemCount: _foundDevices.length,
                itemBuilder: (BuildContext context, int index) {
                  BluetoothDevice device = _foundDevices[index];
                  return ListTile(
                    title: Text(device.localName),
                    subtitle: Text(device.id.toString()),
                    onTap: () => _connectToDevice(device),
                  );
                },
              ),
      ),
    );
  }

  void _connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected to ${device.localName}'),
        ),
      );
      // Navigate to another screen or perform other actions upon connection
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to connect to ${device.localName}: $e'),
        ),
      );
    }
  }
}
