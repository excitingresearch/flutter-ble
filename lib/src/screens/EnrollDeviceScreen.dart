// Copyright 2017, Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:moody/main.dart';
import 'package:moody/src/providers/DeviceProvider.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class EnrollDeviceScreen extends StatefulWidget {
  const EnrollDeviceScreen({Key? key}) : super(key: key);

  @override
  _EnrollDeviceScreenState createState() => _EnrollDeviceScreenState();
}

class _EnrollDeviceScreenState extends State<EnrollDeviceScreen> {
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
