import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:irigasi_cerdas_baru/firebase_options.dart';
import 'package:irigasi_cerdas_baru/services/weather_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
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
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final DatabaseReference dbRef = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        "https://irigasi-cerdas-baru-default-rtdb.asia-southeast1.firebasedatabase.app",
  ).ref();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  String pumpStatus = "OFF";
  String soilStatus = "";
  int soilValue = 0;
  bool pumpValue = false;
  String mode = "Manual";

  String suhu = "-";
  String lokasi = "-";

  List<FlSpot> soilData = [];

  @override
  void initState() {
    super.initState();
    _initNotifications();
    loadWeather();
    loadFirebaseData();
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings android =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings =
        InitializationSettings(android: android);

    await flutterLocalNotificationsPlugin.initialize(settings);
  }

  Future<void> _sendNotification(String status) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'soil_status_channel',
      'Status Tanah',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails details =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      0,
      'Peringatan Status Tanah',
      'Status tanah saat ini: $status',
      details,
    );
  }

  void _saveNotificationToDatabase(String status) {
    dbRef.child('notifications/items').push().set({
      'title': 'Perubahan Status Tanah',
      'body': 'Tanah sekarang dalam kondisi $status',
      'time': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      'isRead': false,
    });
  }

  void loadFirebaseData() {
    dbRef.child('live').onValue.listen((event) {
      if (!event.snapshot.exists) return;

      final data = Map<String, dynamic>.from(
        event.snapshot.value as Map,
      );

      final newStatus = data['status'].toString();

      if (soilStatus.isNotEmpty && newStatus != soilStatus) {
        _sendNotification(newStatus);
        _saveNotificationToDatabase(newStatus);
      }

      setState(() {
        soilStatus = newStatus;
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

    dbRef.child('control/pump').onValue.listen((event) {
      if (!event.snapshot.exists) return;

      setState(() {
        pumpValue = event.snapshot.value as bool;
      });
    });

    dbRef.child('control/mode').onValue.listen((event) {
      if (!event.snapshot.exists) return;

      setState(() {
        mode = event.snapshot.value.toString();
      });
    });
  }

  Future<void> loadWeather() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      String alamat = "Makassar";

      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          alamat = doc.data()?['alamat'] ?? "Makassar";
        }
      }

      final result = await WeatherService().getWeatherByAddress(alamat);

      setState(() {
        suhu = "${result.current.temperature.toStringAsFixed(0)}°C";
        lokasi = result.current.cityName;
      });
    } catch (e) {
      debugPrint(e.toString());
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// KELEMBABAN
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

            /// CUACA
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

            /// STATUS POMPA
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
                    )
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            /// GRAFIK
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 5,
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

            /// KONTROL POMPA
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 5,
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
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text("Otomatis"),
                          selected: mode == "Otomatis",
                          onSelected: (val) {
                            dbRef.child('control/mode').set(
                                  val ? "Otomatis" : "Manual",
                                );
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text("Manual"),
                          selected: mode == "Manual",
                          onSelected: (val) {
                            dbRef.child('control/mode').set(
                                  val ? "Manual" : "Otomatis",
                                );
                          },
                        ),
                      ],
                    ),
                    if (mode == "Manual") ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: _buildManualButton(
                          title: pumpValue ? "MATIKAN POMPA" : "NYALAKAN POMPA",
                          icon: Icons.power_settings_new,
                          color: Colors.green,
                          isActive: pumpValue,
                          onTap: () {
                            dbRef.child('control/pump').set(!pumpValue);
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      mode == "Otomatis"
                          ? "Mode otomatis aktif."
                          : "Mode manual aktif.",
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualButton({
    required String title,
    required IconData icon,
    required Color color,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isActive ? color : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 40,
              color: isActive ? Colors.white : Colors.black54,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
