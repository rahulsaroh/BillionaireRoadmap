import 'dart:math';
import 'package:flutter/material.dart';
import 'streak_validator.dart';

void main() {
  runApp(const StreakEngineApp());
}

class StreakEngineApp extends StatelessWidget {
  const StreakEngineApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Duolingo Streak Engine Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F0F12),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF5722),
          secondary: Color(0xFF4CAF50),
          surface: Color(0xFF1E1E24),
          background: Color(0xFF0F0F12),
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Current local state representing local database/cache
  late StreakState _streakState;
  
  // Simulation configurations
  Duration _simulatedTimezoneOffset = const Duration(hours: 5, minutes: 30); // Default IST
  String _timezoneLabel = "Asia/Kolkata (UTC+5:30)";
  bool _networkOutage = false;
  
  // Date offset to simulate user skipping days
  int _daysOffset = 0;

  // Mock console log list
  final List<String> _consoleLogs = [];

  @override
  void initState() {
    super.initState();
    _streakState = StreakState(
      currentStreak: 5,
      longestStreak: 12,
      activeFreezesCount: 2,
      lastCompletedDate: DateTime.now().subtract(const Duration(days: 1)),
    );
    _log("System", "Initial local cache loaded. Streak: 5, Freezes: 2");
  }

  void _log(String tag, String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    setState(() {
      _consoleLogs.insert(0, "[$timestamp] [$tag] $message");
    });
  }

  void _completeChallenge() {
    _log("Network", "Initiating check-in POST request...");
    
    if (_networkOutage) {
      _log("Network", "ERROR: Connection failed (Outage Mode Active). Saved to Offline SQLite Queue.");
      // Simulate local save
      final simulatedDate = DateTime.now().add(Duration(days: _daysOffset));
      final localDate = simulatedDate.add(_simulatedTimezoneOffset);
      _log("SQLite", "Transaction UUID queued locally: status=PENDING, date=${localDate.toIso8601String().substring(0, 10)}");
      return;
    }

    _log("Database", "Acquiring row-level write lock on 'streak_states'...");
    
    // Simulate transaction delay
    final now = DateTime.now().add(Duration(days: _daysOffset));
    
    final result = StreakValidator.validateStreak(
      completionTimeUtc: now,
      timezoneOffset: _simulatedTimezoneOffset,
      currentState: _streakState,
    );

    _log("UTC Engine", "Calculated DayDiff = ${now.add(_simulatedTimezoneOffset).difference(_streakState.lastCompletedDate ?? now).inDays} local days.");
    _log("Engine", "Action resolved: ${result.action}");
    _log("Database", "Updating transaction row. Idempotency verified.");

    setState(() {
      _streakState = result.newState;
    });

    _log("System", result.logMessage);
  }

  void _simulateMissedDay() {
    setState(() {
      _daysOffset += 1;
    });
    final simulatedTime = DateTime.now().add(Duration(days: _daysOffset));
    _log("Simulator", "Advanced local system clock by +1 Day. Simulated Time: ${simulatedTime.toIso8601String().substring(0, 10)}");
  }

  void _purchaseFreeze() {
    if (_streakState.activeFreezesCount >= 5) {
      _log("Purchase", "Error: Maximum streak freezes equipped (5/5).");
      return;
    }
    _log("Billing", "Processing payment of ₹99 via payment gateway API...");
    _log("Database", "Incrementing 'active_freezes_count' in PostgreSQL...");
    setState(() {
      _streakState = _streakState.copyWith(
        activeFreezesCount: _streakState.activeFreezesCount + 1,
      );
    });
    _log("System", "Streak freeze purchased successfully. Active Freezes: ${_streakState.activeFreezesCount}/5");
  }

  void _changeTimezone(String label, Duration offset) {
    setState(() {
      _timezoneLabel = label;
      _simulatedTimezoneOffset = offset;
    });
    _log("GPS", "Timezone updated to: $label");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "STREAK ENGINE",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                      color: Colors.white,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _networkOutage ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _networkOutage ? Colors.red : Colors.green,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _networkOutage ? Icons.cloud_off : Icons.cloud_queue,
                          size: 14,
                          color: _networkOutage ? Colors.red : Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _networkOutage ? "OUTAGE" : "ONLINE",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _networkOutage ? Colors.red : Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Main App Preview Card
              Expanded(
                flex: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF16161E),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF5722).withOpacity(0.08),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Glow Background for Fire Flame
                      Positioned(
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFFF5722).withOpacity(0.12),
                            blurRadius: 40,
                          ),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Interactive Flame Icon
                          const Icon(
                            Icons.local_fire_department,
                            size: 100,
                            color: Color(0xFFFF5722),
                          ),
                          const SizedBox(height: 10),
                          // Streak Count text
                          Text(
                            "${_streakState.currentStreak}",
                            style: const TextStyle(
                              fontSize: 72,
                              fontWeight: FontWeight.black,
                              height: 1.0,
                            ),
                          ),
                          const Text(
                            "DAY STREAK",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Freezes Status badges
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              final isActive = index < _streakState.activeFreezesCount;
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                child: Icon(
                                  Icons.ac_unit,
                                  size: 20,
                                  color: isActive ? const Color(0xFF00bcd4) : Colors.grey.withOpacity(0.3),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Active Freezes: ${_streakState.activeFreezesCount}/5",
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Interactive Controller Actions
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5722),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _completeChallenge,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text("COMPLETE TASK"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Simulation Panels
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _simulateMissedDay,
                      icon: const Icon(Icons.fast_forward),
                      label: const Text("+1 Day"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _purchaseFreeze,
                      icon: const Icon(Icons.payment),
                      label: const Text("Buy Freeze (₹99)"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Settings toggles & lists
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text("Outage Mode"),
                      selected: _networkOutage,
                      onSelected: (selected) {
                        setState(() {
                          _networkOutage = selected;
                        });
                        _log("Simulator", "Network Outage set to: $selected");
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text("Zone: $_timezoneLabel"),
                      selected: false,
                      onSelected: (_) {
                        // Toggle between London and India
                        if (_simulatedTimezoneOffset.inHours == 5) {
                          _changeTimezone("Europe/London (UTC+0:00)", Duration.zero);
                        } else {
                          _changeTimezone("Asia/Kolkata (UTC+5:30)", const Duration(hours: 5, minutes: 30));
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Realtime Console Logs (The core learning visually!)
              const Text(
                "CONSOLE UTILITY MONITOR",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF070709),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: ListView.builder(
                    itemCount: _consoleLogs.length,
                    itemBuilder: (context, index) {
                      final log = _consoleLogs[index];
                      // Style log based on category
                      Color logColor = Colors.grey;
                      if (log.contains("[Error]") || log.contains("[ERROR]")) {
                        logColor = Colors.redAccent;
                      } else if (log.contains("[Database]")) {
                        logColor = Colors.purpleAccent;
                      } else if (log.contains("[Network]")) {
                        logColor = Colors.blueAccent;
                      } else if (log.contains("[System]")) {
                        logColor = Colors.greenAccent;
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Text(
                          log,
                          style: TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 11,
                            color: logColor,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
