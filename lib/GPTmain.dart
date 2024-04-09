import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_ble_moody/src/ui/DeviceScreen.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RFID & BLE Scanner App',
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
  bool _isPolling = false;
  String _deviceId = '';

  // Poll for NFC tags
  Future<void> pollRFID() async {
    setState(() {
      _isPolling = true;
    });

    try {
      NFCTag tag = await FlutterNfcKit.poll(
          timeout: Duration(seconds: 3),
          iosMultipleTagMessage: 'Multiple tags found!',
          iosAlertMessage: 'Scan your tag');

      // Check for NFC tag and extract the device id
      if (tag.ndefAvailable != null &&
          tag.ndefAvailable! &&
          _deviceId.isEmpty) {
        // var records = await FlutterNfcKit.readNDEFRecords(cached: false);
        // for (var record in records) {
        //   Uint8List? lastFourBytes =
        //       record.payload?.sublist(record.payload!.length - 4);
        //   if (lastFourBytes != null) {
        //     String payloadAsString = String.fromCharCodes(lastFourBytes);
        //     if (RegExp(r'^m\d{3}$').hasMatch(payloadAsString)) {
        //       setState(() {
        //         _deviceId = payloadAsString;
        //       });
        //       findAndConnectToDevice(payloadAsString);
        //       break;
        //     }
        //   }
        // }
        List records = await FlutterNfcKit.readNDEFRecords(cached: false);
        for (var record in records) {
          Uint8List lastFourBytes =
              record.payload.sublist(record.payload.length - 4);

          String payloadAsString = String.fromCharCodes(lastFourBytes);

          print(record.toString());
          print(record.payload);
          print(lastFourBytes);
          print('Payload: $payloadAsString');

          if (RegExp(r'^m\d{3}$').hasMatch(payloadAsString)) {
            // found = true;
            setState(() {
              _deviceId = payloadAsString;
            });
            findAndConnectToDevice(payloadAsString);
            break;
          }
        }
      }
    } catch (e) {
      // Handle errors from NFC polling
      setState(() {
        _isPolling = false;
      });
      print('Error polling NFC: $e');
    }
  }

  // Find and connect to the BLE device
  void findAndConnectToDevice(String deviceId) async {
    FlutterBluePlus.startScan(timeout: Duration(seconds: 4));

    // Listen to scan results
    var subscription = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult result in results) {
        if (result.device.localName == deviceId) {
          // If device is found, stop scanning and connect
          FlutterBluePlus.stopScan();
          connectToDevice(result.device);
          break;
        }
      }
    });

    // Stop scanning after a timeout, and dispose of the subscription
    Future.delayed(Duration(seconds: 4)).then((_) {
      FlutterBluePlus.stopScan();
      subscription.cancel();
      print('scanning done; device (apparently not found)');
      setState(() {
        _isPolling = false;
      });
    });
  }

  // Connect to the BLE device
  void connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      // Handle successful connection
      // Navigate to the device screen or perform further actions
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DeviceScreen(device: device),
        ),
      );
    } catch (e) {
      // Handle connection error
      print('Error connecting to device: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    pollRFID();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Connect to Device'),
      ),
      body: Center(
        child: _isPolling
            ? CircularProgressIndicator()
            : Text('Tap to scan NFC', style: TextStyle(fontSize: 24)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (!_isPolling) {
            pollRFID();
          }
        },
        tooltip: 'Scan NFC',
        child: Icon(Icons.nfc),
      ),
    );
  }
}
