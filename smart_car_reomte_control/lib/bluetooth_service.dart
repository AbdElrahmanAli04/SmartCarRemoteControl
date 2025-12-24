import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothService {
  BluetoothConnection? _connection;
  bool _isConnected = false;
  String _buffer = ''; // Buffer to accumulate incoming data

  final StreamController<String> _dataStreamController =
      StreamController<String>.broadcast();
  Stream<String> get dataStream => _dataStreamController.stream;

  // Connection state stream to notify UI when connection is lost
  final StreamController<bool> _connectionStateController =
      StreamController<bool>.broadcast();
  Stream<bool> get connectionStateStream => _connectionStateController.stream;

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
      _buffer = ''; // Clear buffer on new connection

      // Listen for incoming data
      _connection!.input!
          .listen((Uint8List data) {
            // Log raw bytes for debugging
            print("Raw bytes received: $data");

            // Append received data to buffer
            _buffer += ascii.decode(data);
            print("Current buffer: $_buffer");

            // Check if buffer contains complete message(s) ending with newline
            while (_buffer.contains('\n')) {
              int newlineIndex = _buffer.indexOf('\n');
              String completeMessage = _buffer.substring(0, newlineIndex);
              _buffer = _buffer.substring(newlineIndex + 1);

              // Send complete message to stream
              _dataStreamController.add(completeMessage);
              print("Received complete message: $completeMessage");
            }
          })
          .onDone(() {
            _isConnected = false;
            _buffer = '';
            _connectionStateController.add(false); // Notify UI of disconnection
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
    if ( _isConnected ) {
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
    _connectionStateController.close();
    disconnect();
  }
}
