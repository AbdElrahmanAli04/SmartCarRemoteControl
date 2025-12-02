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
  double batteryLevel = 100;
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
    // Send initial Manual mode command and initial speed
    Future.delayed(const Duration(milliseconds: 500), () {
      _sendCommand("M");
      final int initialSpeedLevel = (_speed ~/ 10).clamp(0, 9);
      _sendCommand(initialSpeedLevel.toString());
    });
    // Listen for incoming Bluetooth data
    _bluetoothService.dataStream.listen((data) {
      setState(() {
        receivedData = data;
        // Parse battery level if received (e.g., "V085V" = 8.5V, "V105V" = 10.5V)
        if (data.startsWith("V") && data.endsWith("V") && data.length == 5) {
          final parsed = int.tryParse(data.substring(1, 4));
          if (parsed != null && parsed >= 0 && parsed <= 121) { // Max volt is 12.1V = 121
            // Convert to voltage: 085 -> 8.5V, 105 -> 10.5V
            final double voltage = parsed / 10.0;
            // Convert voltage to percentage (0-100%)
            // Assuming min voltage is ~7V (empty) and max is 12.1V (full)
            const double minVoltage = 7.0;
            const double maxVoltage = 12.1;
            batteryLevel = ((voltage - minVoltage) / (maxVoltage - minVoltage) * 100).clamp(0, 100);
          }
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
                Icon(
                  batteryLevel > 75 ? Icons.battery_full :
                  batteryLevel > 50 ? Icons.battery_5_bar :
                  batteryLevel > 25 ? Icons.battery_3_bar :
                  Icons.battery_1_bar,
                  color: batteryLevel > 75 ? Colors.green :  batteryLevel > 25 ? Colors.orange :  Colors.red,
                ),
                Text("${batteryLevel.toStringAsFixed(0)}%", 
                  style: const TextStyle(fontWeight: FontWeight.bold)),
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
                // Send mode command via Bluetooth
                if (mode == "Manual") {
                  _sendCommand("M");
                }
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
                  _buildControlBtn(Icons.arrow_upward, "f"),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildControlBtn(Icons.arrow_back, "l"),
                      const SizedBox(width: 10),
                      const SizedBox(width: 78, height: 78),
                      const SizedBox(width: 10),
                      _buildControlBtn(Icons.arrow_forward, "r"),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildControlBtn(Icons.arrow_downward, "b"),
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
                      final int speedLevel = (50 ~/ 10).clamp(0, 9); // Middle speed for Auto
                      print("Autonomous pressed - Current speed level: $speedLevel");
                      setState(() {
                        isAutonomous = !isAutonomous;
                        if (isAutonomous) isParking = false;
                      });
                      _sendCommand(isAutonomous ? "A" : "S"); //Sends A if Autonmous and M if non 
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
                      final int speedLevel = (30 ~/ 10).clamp(0, 9); // Fixed speed for parking 
                      print("Parking pressed - Current speed level: $speedLevel");
                      setState(() {
                        isParking = !isParking;
                        if (isParking) isAutonomous = false;
                      });
                      _sendCommand(isParking ? "P" : "S");
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
                      final int speedLevel = (_speed ~/ 10).clamp(0, 9);
                      print("Teach pressed - Current speed level: $speedLevel");
                      setState(() {
                        isRecording = !isRecording;
                      });
                      _sendCommand(isRecording ? "T" : "S");
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
                      final int speedLevel = (_speed ~/ 10).clamp(0, 9);
                      print("Repeat pressed - Current speed level: $speedLevel");
                      setState(() {
                        isRepeating = !isRepeating;
                      });
                      _sendCommand(isRepeating ? "R" : "S");
                    },
                    child: const Text("Repeat"),
                  ),
                ],
              ),
        
            // 2. Speed Mixer Control (Right)
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 10),
                const Text("Speed", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFCF6F4))),
                const SizedBox(height: 10),
                Expanded(
                  child: _buildSpeedMixer(),
                ),
                Text("Level ${(_speed ~/ 10).clamp(0, 9)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFCF6F4))),
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
    
    return StatefulBuilder(
      builder: (context, setLocalState) {
        bool isPressed = false;
        
        return GestureDetector(
          onTapDown: isDisabled ? null : (_) {
            setLocalState(() => isPressed = true);
            _sendCommand(command);
          },
          onTapUp: isDisabled ? null : (_) {
            setLocalState(() => isPressed = false);
            _sendCommand("S");
          },
          onTapCancel: isDisabled ? null : () {
            setLocalState(() => isPressed = false);
            _sendCommand("S");
          },
          child: AnimatedScale(
            scale: isPressed ? 0.92 : 1.0,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOutBack,
            child: Container(
              width: 70,
              height: 70,
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                gradient: isDisabled
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.grey.shade600, Colors.grey.shade700],
                      )
                    : isPressed
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFFF7043), Color(0xFFBF360C)],
                          )
                        : LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              color ?? const Color(0xFFED572C),
                              color?.withOpacity(0.7) ?? const Color(0xFFD84315),
                            ],
                          ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    blurRadius: isPressed ? 2 : 8,
                    color: Colors.black.withOpacity(0.4),
                    offset: Offset(0, isPressed ? 1 : 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(35),
                  splashColor: Colors.white.withOpacity(0.3),
                  highlightColor: Colors.white.withOpacity(0.1),
                  onTap: () {}, // Handled by GestureDetector
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      child: Icon(
                        icon,
                        size: 32,
                        color: isPressed ? Colors.white : const Color(0xFFFCF6F4),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Mixer-style speed control widget
  Widget _buildSpeedMixer() {
    final bool isDisabled = isParking || isRepeating || isAutonomous ;
    final int currentLevel = (_speed ~/ 10).clamp(0, 9);
    
    return Expanded(
      child: Container(
        width: 60,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF333333), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(10, (index) {
            final int level = 9 - index; // Reverse so 9 is at top, 0 at bottom
            final bool isActive = level <= currentLevel;
            final bool isCurrentLevel = level == currentLevel;
            
            // Color gradient from green (low) to yellow (mid) to red (high)
            Color getBarColor() {
              if (!isActive) return const Color(0xFF2A2A2A);
              if (isDisabled) return Colors.grey;
              if (level <= 3) return Colors.green;
              if (level <= 6) return Colors.orange;
              return Colors.red;
            }
            
            return GestureDetector(
              onTap: isDisabled ? null : () {
                setState(() {
                  _speed = level * 10.0;
                });
                // Send level 0-9 to Arduino
                _sendCommand(level.toString());
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: double.infinity,
                height: 14,
                margin: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  color: getBarColor(),
                  borderRadius: BorderRadius.circular(4),
                  border: isCurrentLevel
                      ? Border.all(color: const Color(0xFFFCF6F4), width: 2)
                      : null,
                  boxShadow: isActive && !isDisabled
                      ? [
                          BoxShadow(
                            color: getBarColor().withOpacity(0.6),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
