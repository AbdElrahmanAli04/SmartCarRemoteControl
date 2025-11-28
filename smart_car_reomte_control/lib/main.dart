import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'bluetooth_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const SmartCarApp());
}

class SmartCarApp extends StatelessWidget {
  const SmartCarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Car Controller',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFED572C),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF111010),
        useMaterial3: true,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Color(0xFFFCF6F4)),
          bodyLarge: TextStyle(color: Color(0xFFFCF6F4)),
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Bluetooth service
  final BluetoothService _bluetoothService = BluetoothService();
  
  // Mock data for UI demonstration
  bool isConnected = false;
  bool isRecording = false;
  bool isAutonomous = false;
  bool isParking = false;
  bool isRepeating = false;
  int batteryLevel = 85;
  String currentMode = "Manual";
  double _speed = 50.0;
  String receivedData = "";

  final List<String> _modes = [
    "Manual",
    "Teach and Repeat"
  ];

  @override
  void initState() {
    super.initState();
    // Listen for incoming Bluetooth data
    _bluetoothService.dataStream.listen((data) {
      setState(() {
        receivedData = data;
        // Parse battery level if received (e.g., "BAT:85")
        if (data.startsWith("BAT:")) {
          batteryLevel = int.tryParse(data.substring(4)) ?? batteryLevel;
        }
      });
    });
  }

  @override
  void dispose() {
    _bluetoothService.dispose();
    super.dispose();
  }

  void _sendCommand(String command) {
    _bluetoothService.sendCommand(command);
    print("Sending command: $command");
  }

  // Show Bluetooth device selection dialog
  Future<void> _showBluetoothDialog() async {
    List<BluetoothDevice> devices = await _bluetoothService.getPairedDevices();
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Bluetooth Device'),
          content: SizedBox(
            width: double.maxFinite,
            child: devices.isEmpty
                ? const Text('No paired devices found.\nPlease pair your HC-06 in Bluetooth settings first.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(devices[index].name ?? 'Unknown'),
                        subtitle: Text(devices[index].address),
                        onTap: () async {
                          Navigator.pop(context);
                          _connectToDevice(devices[index]);
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  // Connect to selected device
  Future<void> _connectToDevice(BluetoothDevice device) async {
    // Show connecting dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Connecting...'),
            ],
          ),
        );
      },
    );

    bool connected = await _bluetoothService.connect(device);
    
    if (!mounted) return;
    Navigator.pop(context); // Close connecting dialog

    setState(() {
      isConnected = connected;
    });

    if (connected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connected to ${device.name}')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to connect')),
      );
    }
  }

  // Disconnect from device
  Future<void> _disconnect() async {
    await _bluetoothService.disconnect();
    setState(() {
      isConnected = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Disconnected')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111010),
      appBar: AppBar(
        title: const Text('Smart Car Remote Control'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Mode Display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Chip(
              avatar: const Icon(Icons.speed, size: 18),
              label: Text(currentMode),
            ),
          ),
          // Battery Display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                const Icon(Icons.battery_std),
                Text("$batteryLevel%", style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          // Bluetooth Connection
          IconButton(
            icon: Icon(
              isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
              color: isConnected ? Colors.green : Colors.red,
            ),
            onPressed: () {
              if (isConnected) {
                _disconnect();
              } else {
                _showBluetoothDialog();
              }
            },
          )
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Text(
                'Select Mode',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 24,
                ),
              ),
            ),
            ..._modes.map((mode) => ListTile(
              title: Text(mode),
              selected: currentMode == mode,
              onTap: () {
                setState(() {
                  currentMode = mode;
                });
                Navigator.pop(context); // Close the drawer
              },
            )),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.only(left: 20 , right: 50),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 1. Directional Controls (Expanded to fill most space)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildControlBtn(Icons.arrow_upward, "F"),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildControlBtn(Icons.arrow_back, "L"),
                      const SizedBox(width: 10),
                      const SizedBox(width: 78, height: 78),
                      const SizedBox(width: 10),
                      _buildControlBtn(Icons.arrow_forward, "R"),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildControlBtn(Icons.arrow_downward, "B"),
                ],
              ),
            ),


            if (currentMode == "Manual")
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAutonomous ? Colors.green : const Color(0xFFED572C),
                      foregroundColor: const Color(0xFFFCF6F4),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: () {
                      setState(() {
                        isAutonomous = !isAutonomous;
                        if (isAutonomous) isParking = false;
                      });
                      _sendCommand(isAutonomous ? "AUTO_ON" : "AUTO_OFF");
                    },
                    child: const Text("Autonomous"),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isParking ? Colors.green : const Color(0xFFED572C),
                      foregroundColor: const Color(0xFFFCF6F4),
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    ),
                    onPressed: () {
                      setState(() {
                        isParking = !isParking;
                        if (isParking) isAutonomous = false;
                      });
                      _sendCommand(isParking ? "PARK_ON" : "PARK_OFF");
                    },
                    child: const Text("Parking"),
                  ),
                ],
              ),

            if (currentMode == "Teach and Repeat")
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFED572C),
                      foregroundColor: const Color(0xFFFCF6F4),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: () {
                      setState(() {
                        isRecording = !isRecording;
                      });
                      _sendCommand(isRecording ? "REC_START" : "REC_STOP");
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(isRecording ? "Stop" : "Teach"),
                        const SizedBox(width: 10),
                        Icon(
                          isRecording ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          shadows: const [
                            Shadow(
                              blurRadius: 10.0,
                              color: Colors.black,
                              offset: Offset(2.0, 2.0),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isRepeating ? Colors.green : const Color(0xFFED572C),
                      foregroundColor: const Color(0xFFFCF6F4),
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    ),
                    onPressed: () {
                      setState(() {
                        isRepeating = !isRepeating;
                      });
                      _sendCommand(isRepeating ? "REPEAT" : "REPEAT_STOP");
                    },
                    child: const Text("Repeat"),
                  ),
                ],
              ),
        
            // 2. Speed Slider (Right)
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 10),
                const Text("Speed", style: TextStyle(fontWeight: FontWeight.bold , color: Color(0xffFcf6f4))),
                Expanded(
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        valueIndicatorColor: const Color(0xFFED572C),
                        valueIndicatorTextStyle: const TextStyle(color: Color(0xFFFCF6F4)),
                      ),
                      child: Slider(
                        value: _speed,
                        min: 0,
                        max: 100,
                        divisions: 10,
                        label: _speed.round().toString(),
                        onChanged: (isParking || isRepeating) ? null : (double value) {
                          setState(() {
                            _speed = value;
                          });
                        },
                      ),
                    ),
                  ),
                ),
                Text("${_speed.round()}%", style: const TextStyle(fontWeight: FontWeight.bold , color: Color(0xffFcf6f4))),
                const SizedBox(height: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlBtn(IconData icon, String command, {Color? color}) {
    final bool isDisabled = isParking || isAutonomous || isRepeating;
    return GestureDetector(
      onTapDown: isDisabled ? null : (_) => _sendCommand(command), // Send when pressed
      onTapUp: isDisabled ? null : (_) => _sendCommand("S"),       // Stop when released (optional safety)
      child: Container(
        width: 70,
        height: 70,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDisabled ? Colors.grey : (color ?? const Color(0xFFED572C)),
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(blurRadius: 5, color: Colors.black26)],
        ),
        child: Icon(icon, size: 32),
      ),
    );
  }
}
