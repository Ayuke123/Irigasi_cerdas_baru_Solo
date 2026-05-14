import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:irigasi_cerdas_baru/firebase_options.dart';
import 'package:irigasi_cerdas_baru/pages/schedule.dart';
import 'package:irigasi_cerdas_baru/pages/connect_device_page.dart';
import 'package:irigasi_cerdas_baru/services/weather_service.dart';
import 'package:irigasi_cerdas_baru/services/pump_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Irigasi Cerdas',
      home: DashboardPage(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final DatabaseReference dbRef = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
    "https://irigasi-cerdas-baru-default-rtdb.asia-southeast1.firebasedatabase.app",
  ).ref();

  PumpService? _pumpService;

  StreamSubscription<DatabaseEvent>? _liveSub;
  StreamSubscription<DatabaseEvent>? _pumpSub;
  StreamSubscription<DatabaseEvent>? _modeSub;
  StreamSubscription<DatabaseEvent>? _systemSub;
  StreamSubscription<DocumentSnapshot>? _weatherSub;

  String pumpStatus = "OFF";
  String soilStatus = "";
  int soilValue = 0;
  bool pumpValue = false;
  String mode = "Manual";

  String suhu = "-";
  String lokasi = "-";
  String systemStatus = "booting"; // "ready" = ESP sudah pairing

  List<FlSpot> soilData = [];

  @override
  void initState() {
    super.initState();

    listenWeatherRealtime();
    loadFirebaseData();

    _pumpService = PumpService(dbRef);
    _pumpService!.start();
  }

  @override
  void dispose() {
    _pumpService?.stop();

    _liveSub?.cancel();
    _pumpSub?.cancel();
    _modeSub?.cancel();
    _systemSub?.cancel();
    _weatherSub?.cancel();

    super.dispose();
  }

  // ==============================
  // WEATHER REALTIME
  // ==============================
  void listenWeatherRealtime() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    _weatherSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((doc) async {
      if (!doc.exists) return;

      String alamat = doc.data()?['alamat'] ?? "Makassar";

      try {
        final result = await WeatherService().getWeatherByAddress(alamat);

        if (!mounted) return;

        setState(() {
          suhu = "${result.current.temperature.toStringAsFixed(0)}°C";

          lokasi = result.current.cityName;
        });
      } catch (e) {
        debugPrint("Weather Error: $e");
      }
    });
  }

  // ==============================
  // LOAD FIREBASE
  // ==============================
  void loadFirebaseData() {
    // =========================
    // LIVE SENSOR
    // =========================
    _liveSub?.cancel();

    _liveSub = dbRef.child('live').onValue.listen((event) {
      if (!event.snapshot.exists) return;

      final data = Map<String, dynamic>.from(
        event.snapshot.value as Map,
      );

      if (!mounted) return;

      setState(() {
        soilStatus = data['status'].toString();

        soilValue = int.tryParse(data['value'].toString()) ?? 0;

        pumpStatus = data['pump_state'].toString();

        if (soilData.length > 10) {
          soilData.removeAt(0);
        }

        soilData.add(
          FlSpot(
            soilData.length.toDouble(),
            soilValue.toDouble(),
          ),
        );
      });
    });

    // =========================
    // PUMP CONTROL
    // =========================
    _pumpSub?.cancel();

    _pumpSub = dbRef.child('control/pump').onValue.listen((event) {
      if (!event.snapshot.exists) return;

      final value = event.snapshot.value;

      if (!mounted) return;

      setState(() {
        if (value is bool) {
          pumpValue = value;
        } else if (value is String) {
          pumpValue = value.toLowerCase() == 'true';
        } else if (value is int) {
          pumpValue = value == 1;
        } else {
          pumpValue = false;
        }

        pumpStatus = pumpValue ? "ON" : "OFF";
      });
    });

    // =========================
    // MODE CONTROL
    // =========================
    _modeSub?.cancel();

    _modeSub = dbRef.child('control/mode').onValue.listen((event) {
      if (!event.snapshot.exists) return;

      if (!mounted) return;

      setState(() {
        mode = event.snapshot.value.toString();
      });
    });

    // =========================
    // SYSTEM STATUS
    // =========================
    _systemSub?.cancel();

    _systemSub = dbRef.child('system/status').onValue.listen((event) {
      if (!mounted) return;

      setState(() {
        if (!event.snapshot.exists || event.snapshot.value == null) {
          systemStatus = "booting";
        } else {
          systemStatus = event.snapshot.value.toString();
        }
      });
    });
  }

  // ==============================
  // COLOR STATUS
  // ==============================
  Color getSoilColor() {
    if (soilStatus == "Kering") {
      return Colors.red;
    }

    if (soilStatus == "Lembap") {
      return Colors.orange;
    }

    if (soilStatus == "Basah") {
      return Colors.green;
    }

    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text(
          "Hallo!",
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: systemStatus != "ready"
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bluetooth_searching, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            const Text(
              "Menunggu Perangkat",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Hubungkan ESP32 terlebih dahulu",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ConnectDevicePage(),
                  ),
                );
              },
              icon: const Icon(Icons.bluetooth),
              label: const Text("Hubungkan Sekarang"),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // =========================
            // CONNECT DEVICE
            // =========================
            Card(
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.bluetooth,
                  color: Colors.blue,
                ),

                title: const Text(
                  "Hubungkan Perangkat",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                subtitle: const Text(
                  "Connect ESP32 secara manual",
                ),

                trailing: const Icon(
                  Icons.arrow_forward_ios,
                ),

                // =========================
                // FIX NAVIGATE
                // =========================
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ConnectDevicePage(),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 10),

            // =========================
            // KELEMBABAN
            // =========================
            Card(
              color: getSoilColor(),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                title: const Text(
                  "Kelembaban Tanah",
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      "$soilValue%",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: soilValue / 100,
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(10),
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation(
                        Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Status: $soilStatus",
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // =========================
            // WEATHER
            // =========================
            Card(
              color: Colors.amber,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                title: const Text(
                  "Cuaca",
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      suhu,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      lokasi,
                      style: const TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // =========================
            // STATUS POMPA
            // =========================
            Card(
              color: Colors.grey,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                title: const Text(
                  "Status Pompa",
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
                subtitle: Row(
                  children: [
                    Icon(
                      pumpStatus == "ON" ? Icons.water_drop : Icons.power_off,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      pumpStatus,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // =========================
            // GRAFIK
            // =========================
            Card(
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Grafik Kelembaban Tanah",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 200,
                      child: LineChart(
                        LineChartData(
                          borderData: FlBorderData(show: false),
                          gridData: FlGridData(show: true),
                          titlesData: FlTitlesData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: soilData,
                              isCurved: true,
                              barWidth: 3,
                              dotData: FlDotData(show: true),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // =========================
            // KONTROL POMPA
            // =========================
            Card(
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Kontrol Pompa",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // =========================
                    // MODE
                    // =========================
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              dbRef.child('control/mode').set("Otomatis");
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: mode == "Otomatis"
                                    ? Colors.green
                                    : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(
                                  12,
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  "Otomatis",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              dbRef.child('control/mode').set("Manual");
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: mode == "Manual"
                                    ? Colors.blue
                                    : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(
                                  12,
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  "Manual",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              dbRef.child('control/mode').set("Jadwal");

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SchedulePage(),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: mode == "Jadwal"
                                    ? Colors.orange
                                    : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(
                                  12,
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  "Jadwal",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // =========================
                    // MANUAL BUTTON
                    // =========================
                    if (mode == "Manual") ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: InkWell(
                          onTap: () async {
                            final newValue = !pumpValue;

                            await dbRef.child('control/pump').set(newValue);

                            if (!mounted) return;

                            setState(() {
                              pumpValue = newValue;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: pumpValue ? Colors.green : Colors.grey,
                              borderRadius: BorderRadius.circular(
                                20,
                              ),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.power_settings_new,
                                  size: 40,
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  pumpValue
                                      ? "MATIKAN POMPA"
                                      : "NYALAKAN POMPA",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    Text(
                      "Mode aktif: $mode",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}