import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:irigasi_cerdas_baru/firebase_options.dart';
import 'package:irigasi_cerdas_baru/pages/schedule.dart';
import 'package:irigasi_cerdas_baru/pages/connect_device_page.dart';
import 'package:irigasi_cerdas_baru/services/weather_service.dart';
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
      home: const DashboardPage(),
    );
  }
}

class _WateringAnimation extends StatefulWidget {
  const _WateringAnimation();

  @override
  State<_WateringAnimation> createState() => _WateringAnimationState();
}

class _WateringAnimationState extends State<_WateringAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 50,
      height: 50,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ikon Tanaman
          const Positioned(
            bottom: 5,
            child: Icon(Icons.local_florist, color: Colors.white, size: 28),
          ),
          // Animasi Tetesan Air
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Positioned(
                top: 0 + (_animation.value * 20),
                child: Opacity(
                  opacity: 1 - _animation.value,
                  child: const Icon(Icons.water_drop,
                      color: Colors.white, size: 16),
                ),
              );
            },
          ),
        ],
      ),
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

  Timer? _offlineTimer;
  DateTime _lastSeen = DateTime.now();

  StreamSubscription<DatabaseEvent>? _liveSub;
  StreamSubscription<DatabaseEvent>? _pumpSub;
  StreamSubscription<DatabaseEvent>? _modeSub;
  StreamSubscription<DatabaseEvent>? _systemSub;
  StreamSubscription<DatabaseEvent>? _offlineSub;
  StreamSubscription<DatabaseEvent>? _scheduleSub;
  StreamSubscription<DocumentSnapshot>? _weatherSub;

  String pumpStatus = "OFF";
  String soilStatus = "";
  int soilValue = 0;
  bool pumpValue = false;
  String mode = "Manual";

  // Variabel Jadwal
  String scheduleDate = "-";
  String scheduleTime = "-";
  int scheduleDuration = 0;

  String suhu = "-";
  String lokasi = "-";
  String systemStatus = "booting"; // "ready" = ESP sudah pairing
  bool espOffline = false;

  List<FlSpot> soilData = [];

  @override
  void initState() {
    super.initState();

    listenWeatherRealtime();
    loadFirebaseData();

    _startOfflineTimer();
  }

  void _startOfflineTimer() {
    _offlineTimer?.cancel();
    _offlineTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      final now = DateTime.now();
      // Ditambah jadi 45 detik agar lebih toleran terhadap lag internet
      bool isNowOffline = now.difference(_lastSeen).inSeconds > 45;

      if (isNowOffline != espOffline) {
        setState(() {
          espOffline = isNowOffline;
        });
      }
    });
  }

  @override
  void dispose() {
    _offlineTimer?.cancel();

    _liveSub?.cancel();
    _pumpSub?.cancel();
    _modeSub?.cancel();
    _systemSub?.cancel();
    _offlineSub?.cancel();
    _scheduleSub?.cancel();
    _weatherSub?.cancel();

    super.dispose();
  }

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

  void loadFirebaseData() {
    _liveSub?.cancel();
    _liveSub = dbRef.child('live').onValue.listen((event) {
      // SETIAP KALI DATA DITERIMA, UPDATE WAKTU TERAKHIR TERLIHAT
      _lastSeen = DateTime.now();
      
      if (!event.snapshot.exists) return;
      
      final data = Map<String, dynamic>.from(
        event.snapshot.value as Map,
      );

      bool isPumpOn = false;
      var ps = data['pump_state'];
      if (ps is bool) {
        isPumpOn = ps;
      } else if (ps is String) {
        isPumpOn = ps.toLowerCase() == 'true';
      } else if (ps is int) {
        isPumpOn = ps == 1;
      }

      if (!mounted) return;

      setState(() {
        soilStatus = data['status'].toString();
        soilValue = int.tryParse(data['value'].toString()) ?? 0;
        pumpStatus = isPumpOn ? "ON" : "OFF";

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
        // pumpStatus TIDAK diperbarui di sini agar tidak menimpa status asli dari ESP32
      });
    });

    _modeSub?.cancel();
    _modeSub = dbRef.child('control/mode').onValue.listen((event) {
      if (!event.snapshot.exists) return;

      if (!mounted) return;

      setState(() {
        mode = event.snapshot.value.toString();
      });
    });

    _scheduleSub?.cancel();
    _scheduleSub = dbRef.child('schedule/item').onValue.listen((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return;

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);

      if (!mounted) return;

      setState(() {
        scheduleDate = data['date']?.toString() ?? "-";
        scheduleTime = data['time']?.toString() ?? "-";
        scheduleDuration =
            int.tryParse(data['duration']?.toString() ?? "0") ?? 0;
      });
    });

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

    // Sub ke offline ditiadakan karena sudah dicover oleh _liveSub
    _offlineSub?.cancel();
  }

  String getNamaHari(String dateStr) {
    try {
      if (dateStr == "-") return "-";
      DateTime date = DateTime.parse(dateStr);
      List<String> hari = [
        "Senin",
        "Selasa",
        "Rabu",
        "Kamis",
        "Jumat",
        "Sabtu",
        "Minggu"
      ];
      return hari[date.weekday - 1];
    } catch (e) {
      return "-";
    }
  }

  Color getSoilColor() {
    if (soilStatus == "Kering") return Colors.red;
    if (soilStatus == "Lembap") return Colors.orange;
    if (soilStatus == "Basah") return Colors.green;
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
                  const Icon(Icons.bluetooth_searching,
                      size: 64, color: Colors.blue),
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
          : Column(
              children: [
                // BANNER OFFLINE (LOCKED AT TOP)
                if (espOffline)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    color: Colors.orange.shade700,
                    child: const Row(
                      children: [
                        Icon(Icons.wifi_off, color: Colors.white),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "ESP32 Offline — Sistem berjalan dalam Mode Otomatis",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Card(
                          elevation: 5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListTile(
                            leading: const Icon(Icons.bluetooth, color: Colors.blue),
                            title: const Text(
                              "Hubungkan Perangkat",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: const Text("Connect ESP32 secara manual"),
                            trailing: const Icon(Icons.arrow_forward_ios),
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
                        Card(
                          color: getSoilColor(),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListTile(
                            title: const Text(
                              "Kelembaban Tanah",
                              style: TextStyle(color: Colors.white),
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
                                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Status: $soilStatus",
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Card(
                          color: Colors.amber,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListTile(
                            title: const Text(
                              "Cuaca",
                              style: TextStyle(color: Colors.white),
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
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Card(
                          color: pumpStatus == "ON" ? Colors.blue : Colors.grey,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListTile(
                            leading: pumpStatus == "ON"
                                ? const _WateringAnimation()
                                : const Icon(Icons.power_off,
                                    color: Colors.white, size: 30),
                            title: Text(
                              pumpStatus == "ON" ? "Pompa Menyala" : "Pompa Off",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            subtitle: Text(
                              pumpStatus == "ON"
                                  ? "Sedang menyirami tanaman..."
                                  : "Pompa sedang tidak aktif",
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
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
                                          dotData: const FlDotData(show: true),
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
                                Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: espOffline
                                            ? null
                                            : () {
                                                dbRef.child('control/mode').set("Otomatis");
                                              },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          decoration: BoxDecoration(
                                            color: mode == "Otomatis"
                                                ? Colors.green
                                                : Colors.grey.shade300,
                                            borderRadius: BorderRadius.circular(12),
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
                                        onTap: espOffline
                                            ? null
                                            : () {
                                                dbRef.child('control/mode').set("Manual");
                                              },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          decoration: BoxDecoration(
                                            color: mode == "Manual"
                                                ? Colors.blue
                                                : Colors.grey.shade300,
                                            borderRadius: BorderRadius.circular(12),
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
                                        onTap: espOffline
                                            ? null
                                            : () {
                                                dbRef.child('control/mode').set("Jadwal");
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => const SchedulePage(),
                                                  ),
                                                );
                                              },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          decoration: BoxDecoration(
                                            color: mode == "Jadwal"
                                                ? Colors.orange
                                                : Colors.grey.shade300,
                                            borderRadius: BorderRadius.circular(12),
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
                                if (mode == "Manual") ...[
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: InkWell(
                                      onTap: espOffline
                                          ? null
                                          : () async {
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
                                          borderRadius: BorderRadius.circular(20),
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
                                              pumpValue ? "MATIKAN POMPA" : "NYALAKAN POMPA",
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
                                if (mode == "Jadwal") ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.orange),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Row(
                                          children: [
                                            Icon(Icons.event_note,
                                                color: Colors.orange, size: 20),
                                            SizedBox(width: 8),
                                            Text(
                                              "Detail Jadwal Aktif",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Divider(),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text("Hari / Tgl:"),
                                            Text(
                                              "${getNamaHari(scheduleDate)}, $scheduleDate",
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text("Waktu:"),
                                            Text(
                                              scheduleTime,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text("Durasi:"),
                                            Text(
                                              "$scheduleDuration Menit",
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Text(
                                  "Mode aktif: $mode",
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
