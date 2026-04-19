import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:irigasi_cerdas_baru/firebase_options.dart';
import 'package:irigasi_cerdas_baru/services/weather_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dbRef = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        "https://irigasi-cerdas-baru-default-rtdb.asia-southeast1.firebasedatabase.app",
  ).ref();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Irigasi Cerdas',
      debugShowCheckedModeBanner: false,
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

  // 🔥 DATA SENSOR
  String pumpStatus = "OFF";
  String soilStatus = "Kering";
  int soilValue = 0;
  String mode = "Manual";

  // 🔥 DATA CUACA
  String suhu = "-";
  String lokasi = "-";

  @override
  void initState() {
    super.initState();

    loadWeather();

    dbRef.child('live').onValue.listen((event) {
      print("🔥 MASUK LISTENER");
      print("SNAPSHOT: ${event.snapshot.value}");

      if (!event.snapshot.exists || event.snapshot.value == null) {
        print("DATA KOSONG");
        return;
      }

      final rawData = event.snapshot.value as Map<dynamic, dynamic>;

      final data = rawData.map(
        (key, value) => MapEntry(key.toString(), value),
      );

      setState(() {
        pumpStatus = data['pump_state']?.toString() ?? "OFF";
        soilStatus = data['status']?.toString() ?? "Tidak diketahui";

        soilValue = int.tryParse("${data['value']}") ?? 0;
      });

      print("DATA SETELAH PARSE: $data");
    });

    /// 🔥 MODE
    dbRef.child('control/mode').onValue.listen((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        setState(() {
          mode = event.snapshot.value.toString();
        });
      }
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
          final data = doc.data();
          alamat = data?['alamat'] ?? "Makassar";
        }
      }

      final result = await WeatherService().getWeatherByAddress(alamat);

      setState(() {
        suhu = "${result.current.temperature.toStringAsFixed(0)}°C";
        lokasi = result.current.cityName;
      });

      debugPrint("LOKASI USER: $alamat");
    } catch (e) {
      debugPrint("ERROR CUACA: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Hallo! Ayu',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false, // biar ke kiri
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            /// 🔥 KELEMBABAN TANAH (REALTIME FIX)
            Card(
              color: Colors.blue,
              child: ListTile(
                title: const Text(
                  'Kelembaban Tanah',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$soilValue%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      'Status: $soilStatus',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            /// 🔥 CUACA
            Card(
              color: Colors.amber,
              child: ListTile(
                title: const Text(
                  'Cuaca',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suhu,
                      style: const TextStyle(
                        color: Colors.white,
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

            const SizedBox(height: 8),

            /// 🔥 STATUS POMPA
            Card(
              color: Colors.grey,
              child: ListTile(
                title: const Text(
                  'Status Pompa',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  pumpStatus,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            /// 🔥 KONTROL
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kontrol Pompa',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Otomatis'),
                          selected: mode == "Otomatis",
                          onSelected: (val) {
                            dbRef
                                .child('control/mode')
                                .set(val ? "Otomatis" : "Manual");
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Manual'),
                          selected: mode == "Manual",
                          onSelected: (val) {
                            dbRef
                                .child('control/mode')
                                .set(val ? "Manual" : "Otomatis");
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Mode otomatis aktif. Pompa akan menyala otomatis ketika kelembaban tanah dibawah 40%.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
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
