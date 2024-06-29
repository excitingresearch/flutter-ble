import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceProvider with ChangeNotifier {
  String? _deviceId;
  List<String> _previousDeviceIds = [];

  String? get deviceId {
    print("req devicdeId");
    return _deviceId;
  }

  List<String> get previousDeviceIds => _previousDeviceIds;

  DeviceProvider() {
    _loadDeviceId();
    _loadPreviousDeviceIds();
  }

  Future<void> setDeviceId(String deviceId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _deviceId = deviceId;
    if (!_previousDeviceIds.contains(deviceId)) {
      _previousDeviceIds.insert(0, deviceId); // Add to the top
    } else {
      // Move existing entry to the top
      _previousDeviceIds.remove(deviceId);
      _previousDeviceIds.insert(0, deviceId);
    }
    await prefs.setString('device_id', deviceId);
    await prefs.setStringList('previous_device_ids', _previousDeviceIds);
    notifyListeners();
  }

  Future<void> _loadDeviceId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString('device_id');
    notifyListeners();
  }

  Future<void> _loadPreviousDeviceIds() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _previousDeviceIds = prefs.getStringList('previous_device_ids') ?? [];
    notifyListeners();
  }

  Future<void> deleteDeviceId() async {
    if (_deviceId != null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      _previousDeviceIds.add(_deviceId!);
      _previousDeviceIds =
          _previousDeviceIds.toSet().toList(); // Ensure uniqueness
      await prefs.setStringList('previous_device_ids', _previousDeviceIds);
      await prefs.remove('device_id');
      _deviceId = null;
      notifyListeners();
    }
  }
}
