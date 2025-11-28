import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothService {
  BluetoothConnection? _connection;
  bool _isConnected = false;
  
  final StreamController<String> _dataStreamController = StreamController<String>.broadcast();
  Stream<String> get dataStream => _dataStreamController.stream;
  
  bool get isConnected => _isConnected;

  // Request Bluetooth permissions
  Future<bool> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.locationWhenInUse,
    ].request();

    bool allGranted = statuses.values.every((status) => status.isGranted);
    if (!allGranted) {
      print("Some permissions were denied: $statuses");
    }
    return allGranted;
  }
  
  // Get list of paired devices
  Future<List<BluetoothDevice>> getPairedDevices() async {
    // Request permissions first
    bool permissionsGranted = await requestPermissions();
    if (!permissionsGranted) {
      print("Bluetooth permissions not granted");
      return [];
    }

    List<BluetoothDevice> devices = [];
    try {
      devices = await FlutterBluetoothSerial.instance.getBondedDevices();
    } catch (e) {
      print("Error getting paired devices: $e");
    }
    return devices;
  }
  
  // Connect to HC-06 device
  Future<bool> connect(BluetoothDevice device) async {
    try {
      _connection = await BluetoothConnection.toAddress(device.address);
      _isConnected = true;
      
      // Listen for incoming data
      _connection!.input!.listen((Uint8List data) {
        String receivedData = ascii.decode(data);
        _dataStreamController.add(receivedData);
        print("Received: $receivedData");
      }).onDone(() {
        _isConnected = false;
        print("Disconnected by remote device");
      });
      
      print("Connected to ${device.name}");
      return true;
    } catch (e) {
      print("Error connecting: $e");
      _isConnected = false;
      return false;
    }
  }
  
  // Disconnect from device
  Future<void> disconnect() async {
    try {
      await _connection?.close();
      _isConnected = false;
      print("Disconnected");
    } catch (e) {
      print("Error disconnecting: $e");
    }
  }
  
  // Send command to HC-06
  void sendCommand(String command) {
    if (_connection != null && _isConnected) {
      try {
        _connection!.output.add(Uint8List.fromList(utf8.encode(command)));
        _connection!.output.allSent;
        print("Sent: $command");
      } catch (e) {
        print("Error sending command: $e");
      }
    } else {
      print("Not connected. Cannot send command.");
    }
  }
  
  // Dispose resources
  void dispose() {
    _dataStreamController.close();
    disconnect();
  }
}
