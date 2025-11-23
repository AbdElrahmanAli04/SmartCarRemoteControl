import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
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
  // Mock data for UI demonstration
  bool isConnected = false;
  int batteryLevel = 85;
  String currentMode = "Manual";
  double _speed = 50.0;

  final List<String> _modes = [
    "Manual",
    "Autonomous",
    "Auto Parking",
    "Teach and Repeat"
  ];

  void _sendCommand(String command) {
    // TODO: Implement Bluetooth send logic here
    print("Sending command: $command");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              // TODO: Navigate to connection screen or toggle connection
              setState(() {
                isConnected = !isConnected;
              });
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
                      _buildControlBtn(Icons.stop_circle, "S", color: Colors.red),
                      const SizedBox(width: 10),
                      _buildControlBtn(Icons.arrow_forward, "R"),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildControlBtn(Icons.arrow_downward, "B"),
                ],
              ),
            ),
        
            // 2. Speed Slider (Right)
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 10),
                const Text("Speed", style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Slider(
                      value: _speed,
                      min: 0,
                      max: 100,
                      divisions: 10,
                      label: _speed.round().toString(),
                      onChanged: (double value) {
                        setState(() {
                          _speed = value;
                        });
                      },
                    ),
                  ),
                ),
                Text("${_speed.round()}%", style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlBtn(IconData icon, String command, {Color? color}) {
    return GestureDetector(
      onTapDown: (_) => _sendCommand(command), // Send when pressed
      onTapUp: (_) => _sendCommand("S"),       // Stop when released (optional safety)
      child: Container(
        width: 70,
        height: 70,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color ?? Theme.of(context).colorScheme.primaryContainer,
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(blurRadius: 5, color: Colors.black26)],
        ),
        child: Icon(icon, size: 32),
      ),
    );
  }
}
