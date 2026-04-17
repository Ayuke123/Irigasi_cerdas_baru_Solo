import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:irigasi_cerdas_baru/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform.copyWith(
      databaseURL:
          "https://irigasi-cerdas-baru-default-rtdb.asia-southeast1.firebasedatabase.app",
    ),
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Irigasi Cerdas',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: DashboardPage(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final DatabaseReference dbRef = FirebaseDatabase.instance.ref();

  String pumpStatus = "OFF";
  String soilStatus = "Kering";
  int soilValue = 0;
  String mode = "Manual";

  @override
  void initState() {
    super.initState();
    // Listen ke Firebase Realtime
    dbRef.child('live').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      setState(() {
        pumpStatus = data['pump_state'] ?? "OFF";
        soilStatus = data['status'] ?? "Kering";
        soilValue = data['value'] ?? 0;
      });
    });

    dbRef.child('control/mode').onValue.listen((event) {
      final data = event.snapshot.value;
      setState(() {
        mode = data?.toString() ?? "Manual";
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Hallo! Ayu'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Kelembaban Tanah
            Card(
              color: Colors.blue,
              child: ListTile(
                title: Text(
                  'Kelembaban Tanah',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  '$soilValue%',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            SizedBox(height: 8),
            // Cuaca
            Card(
              color: Colors.amber,
              child: ListTile(
                title: Text(
                  'Cuaca',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  'Normal',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            SizedBox(height: 8),
            // Status Pompa
            Card(
              color: Colors.grey,
              child: ListTile(
                title: Text(
                  'Status Pompa',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  pumpStatus,
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            SizedBox(height: 16),
            // Kontrol Pompa
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kontrol Pompa',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        ChoiceChip(
                          label: Text('Otomatis'),
                          selected: mode == "Otomatis",
                          onSelected: (val) {
                            dbRef
                                .child('control/mode')
                                .set(val ? "Otomatis" : "Manual");
                          },
                        ),
                        SizedBox(width: 8),
                        ChoiceChip(
                          label: Text('Manual'),
                          selected: mode == "Manual",
                          onSelected: (val) {
                            dbRef
                                .child('control/mode')
                                .set(val ? "Manual" : "Otomatis");
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Mode otomatis aktif. Pompa akan menyala otomatis ketika kelembaban tanah dibawah 40%.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
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
