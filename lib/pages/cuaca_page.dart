import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/weather_service.dart';

class CuacaPage extends StatefulWidget {
  const CuacaPage({super.key});

  @override
  State<CuacaPage> createState() => _CuacaPageState();
}

class _CuacaPageState extends State<CuacaPage> {
  late Future<WeatherResult> weatherFuture;

  @override
  void initState() {
    super.initState();
    weatherFuture = _loadWeatherFromUserAddress();
  }

  Future<WeatherResult> _loadWeatherFromUserAddress() async {
    final user = FirebaseAuth.instance.currentUser;
    String alamat = 'Makassar';

    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        alamat = data?['alamat'] ?? 'Makassar';
      }
    }

    return WeatherService().getWeatherByAddress(alamat);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Cuaca'),
        backgroundColor: const Color.fromARGB(255, 250, 250, 251),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<WeatherResult>(
          future: weatherFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final data = snapshot.data!;
            final current = data.current;
            final forecast = data.next3Days;

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // =========================
                  // CARD CUACA UTAMA
                  // =========================
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.blue[300],
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            const Icon(Icons.cloud, color: Colors.white),
                            const SizedBox(width: 8),
                            const Text(
                              'Cuaca Saat Ini',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // LOKASI
                        Text(
                          current.cityName,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // SUHU
                        Center(
                          child: Text(
                            '${current.temperature.toStringAsFixed(0)}°C',
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),

                        const SizedBox(height: 6),

                        // DESKRIPSI
                        Center(
                          child: Text(
                            current.description,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // =========================
                  // PERKIRAAN 3 HARI
                  // =========================
                  const Text(
                    'Perkiraan Cuaca',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    height: 150,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: forecast.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final item = forecast[index];

                        return Container(
                          width: 110,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _dayLabel(item.dateTime),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Icon(
                                _weatherIcon(item.mainWeather),
                                size: 32,
                                color: Colors.orange,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${item.temperature.toStringAsFixed(0)}°C',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  IconData _weatherIcon(String mainWeather) {
    switch (mainWeather.toLowerCase()) {
      case 'clouds':
        return Icons.cloud_outlined;
      case 'rain':
      case 'drizzle':
        return Icons.grain;
      case 'thunderstorm':
        return Icons.thunderstorm;
      case 'clear':
        return Icons.wb_sunny_outlined;
      default:
        return Icons.cloud_outlined;
    }
  }

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year);
    final tomorrow = today.add(const Duration(days: 1));
    final dayAfterTomorrow = today.add(const Duration(days: 2));
    final threeDaysLater = today.add(const Duration(days: 3));

    final target = DateTime(date.year, date.month, date.day);

    // Menampilkan "Besok", "Lusa", "3 Hari" sesuai hari yang benar
    if (target == tomorrow) return 'Besok';
    if (target == dayAfterTomorrow) return 'Lusa';
    if (target == threeDaysLater) return '3 Hari';

    // Menampilkan nama hari secara lengkap setelah hari besok dan lusa
    final dayNames = [
      'Minggu',
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu'
    ];
    return dayNames[target.weekday %
        7]; // Menggunakan weekday untuk mengambil nama hari yang benar
  }
}
