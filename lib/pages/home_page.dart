import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:irigasi_cerdas_baru/firebase_options.dart';
import 'package:irigasi_cerdas_baru/services/weather_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

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

  Widget _buildManualButton({
    required String title,
    required IconData icon,
    required Color color,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? color : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? color : Colors.grey.shade400,
            width: 2,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : Colors.grey.shade600,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey.shade600,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
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

  // 🔥 DATA SENSOR
  String pumpStatus = "OFF";
  String soilStatus = ""; // Kosongkan agar tidak memicu notif saat awal buka
  int soilValue = 0;
  String mode = "Manual";

  // 🔥 DATA CUACA
  String suhu = "-";
  String lokasi = "-";

  @override
  void initState() {
    super.initState();
    _initNotifications();
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
        final newSoilStatus = data['status']?.toString() ?? "Tidak diketahui";

        // Cek jika status tanah berubah untuk kirim notifikasi
        if (newSoilStatus != soilStatus && soilStatus != "Kering" && soilStatus != "Basah" && soilStatus != "Lembap") {
           // Ini untuk inisialisasi awal agar tidak langsung notif saat aplikasi dibuka
        } else if (newSoilStatus != soilStatus) {
           _sendNotification(newSoilStatus);
           _saveNotificationToDatabase(newSoilStatus);
        }

        soilStatus = newSoilStatus;
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

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _sendNotification(String status) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'soil_status_channel',
      'Status Tanah',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      0,
      'Peringatan Status Tanah',
      'Status tanah saat ini: $status',
      platformChannelSpecifics,
    );
  }

  void _saveNotificationToDatabase(String status) {
    final notifRef = dbRef.child('notifications/items').push();
    notifRef.set({
      'title': 'Perubahan Status Tanah',
      'body': 'Tanah sekarang dalam kondisi $status.',
      'time': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      'isRead': false,
      'type': 'status_change',
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
                    if (mode == "Manual") ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Kontrol Manual Pompa',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: SizedBox(
                          width: double.infinity,
                          child: _buildManualButton(
                            title: pumpStatus == "ON" ? "MATIKAN POMPA" : "NYALAKAN POMPA",
                            icon: Icons.power_settings_new,

                            // warna aktif = hijau, tapi hanya dipakai saat ON
                            color: Colors.green,

                            // status ON / OFF
                            isActive: pumpStatus == "ON",

                            onTap: () {
                              dbRef.child('control/pump').set(pumpStatus == "OFF");
                            },
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      mode == "Otomatis"
                          ? 'Mode otomatis aktif. Pompa akan menyala otomatis ketika kelembaban tanah dibawah 40%.'
                          : 'Mode manual aktif. Gunakan tombol di atas untuk menyalakan atau mematikan pompa.',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
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
        duration: const Duration(milliseconds: 500), // Durasi animasi 0.5 detik
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isActive ? color : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? color.withOpacity(0.7) : Colors.grey.shade400,
            width: 3,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.5),
                    blurRadius: 15,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedRotation(
              duration: const Duration(milliseconds: 500),
              turns: isActive ? 1 : 0, // Ikon sedikit berputar saat aktif
              child: Icon(
                icon,
                color: isActive ? Colors.white : Colors.grey.shade600,
                size: 40,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isActive ? "STATUS: AKTIF" : "STATUS: MATI",
              style: TextStyle(
                color: isActive ? Colors.white70 : Colors.grey.shade500,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
