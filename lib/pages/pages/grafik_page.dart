import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class GrafikPage extends StatefulWidget {
  const GrafikPage({super.key});

  @override
  State<GrafikPage> createState() => _GrafikPageState();
}

class _GrafikPageState extends State<GrafikPage> {
  List<FlSpot> spots = [];
  List<String> waktuLabel = [];
  bool loading = true;

  double minValue = 0;
  double maxValue = 0;
  double avgValue = 0;
  String statusTanah = "-";
  String lastUpdate = "-";
  String kondisiKritisText = "-";

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  void hitungKondisiKritis(List<double> values) {
    if (values.isEmpty) return;

    int durasiKering = 0;
    bool sedangKering = false;

    for (var v in values) {
      if (v < 30) {
        sedangKering = true;
        durasiKering++;
      }
    }

    if (sedangKering) {
      kondisiKritisText =
          "⚠ Tanah dalam kondisi kering selama ±$durasiKering data pengukuran";
    } else {
      kondisiKritisText = "✔ Tidak ada kondisi kritis (tanah stabil)";
    }
  }

  void fetchData() async {
    final db = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL:
          "https://irigasi-cerdas-baru-default-rtdb.asia-southeast1.firebasedatabase.app",
    );

    final snapshot = await db.ref('history').limitToLast(20).get();

    List<FlSpot> tempSpots = [];
    List<String> tempLabel = [];
    List<double> values = [];

    int index = 0;

    if (snapshot.exists) {
      for (var child in snapshot.children) {
        final data = child.value as Map<dynamic, dynamic>;

        double kelembaban = double.tryParse("${data['nilai_persen']}") ?? 0;
        values.add(kelembaban);

        String waktuRaw = data['waktu'] ?? '';

        String waktuFormatted;
        try {
          DateTime dt = DateTime.parse(waktuRaw);
          waktuFormatted = DateFormat('HH:mm').format(dt);
          lastUpdate = DateFormat('dd MMM HH:mm').format(dt);
        } catch (e) {
          waktuFormatted = waktuRaw.toString();
        }

        tempSpots.add(FlSpot(index.toDouble(), kelembaban));
        tempLabel.add(waktuFormatted);

        index++;
      }
    }

    if (values.isNotEmpty) {
      minValue = values.reduce((a, b) => a < b ? a : b);
      maxValue = values.reduce((a, b) => a > b ? a : b);
      avgValue = values.reduce((a, b) => a + b) / values.length;

      if (avgValue < 30) {
        statusTanah = "Kering";
      } else if (avgValue < 70) {
        statusTanah = "Normal";
      } else {
        statusTanah = "Basah";
      }

      hitungKondisiKritis(values);
    }

    setState(() {
      spots = tempSpots;
      waktuLabel = tempLabel;
      loading = false;
    });
  }

  Widget infoCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color),
        ),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 11)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Dashboard Kelembaban"),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // STATUS
                    Row(
                      children: [
                        Icon(
                          statusTanah == "Kering"
                              ? Icons.warning
                              : statusTanah == "Basah"
                                  ? Icons.water
                                  : Icons.eco,
                          color: statusTanah == "Kering"
                              ? Colors.red
                              : statusTanah == "Basah"
                                  ? Colors.blue
                                  : Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Status: $statusTanah",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    Text(
                      "Update terakhir: $lastUpdate",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // INFO CARD
                    Row(
                      children: [
                        infoCard("Min", "$minValue%", Colors.red),
                        infoCard("Max", "$maxValue%", Colors.green),
                        infoCard(
                          "Avg",
                          "${avgValue.toStringAsFixed(1)}%",
                          Colors.blue,
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // GRAFIK
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: SizedBox(
                          height: 250,
                          child: LineChart(
                            LineChartData(
                              minY: 0,
                              maxY: 100,
                              gridData: const FlGridData(show: true),
                              borderData: FlBorderData(
                                show: true,
                                border: Border.all(color: Colors.grey),
                              ),
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: 20,
                                    getTitlesWidget: (value, meta) {
                                      return Text("${value.toInt()}%");
                                    },
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: (waktuLabel.length / 5)
                                        .clamp(1, 10)
                                        .toDouble(),
                                    getTitlesWidget: (value, meta) {
                                      int i = value.toInt();
                                      if (i < 0 || i >= waktuLabel.length) {
                                        return const SizedBox.shrink();
                                      }

                                      return Transform.rotate(
                                        angle: -0.5,
                                        child: Text(
                                          waktuLabel[i],
                                          style: const TextStyle(fontSize: 9),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: spots,
                                  isCurved: true,
                                  barWidth: 3,
                                  color: Colors.blue,
                                  dotData: const FlDotData(show: true),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: Colors.blue.withOpacity(0.15),
                                  ),
                                ),
                              ],
                              extraLinesData: ExtraLinesData(
                                horizontalLines: [
                                  HorizontalLine(
                                    y: 30,
                                    color: Colors.red,
                                    dashArray: [5, 5],
                                    label: HorizontalLineLabel(
                                      show: true,
                                      labelResolver: (_) => "Kering",
                                    ),
                                  ),
                                  HorizontalLine(
                                    y: 70,
                                    color: Colors.green,
                                    dashArray: [5, 5],
                                    label: HorizontalLineLabel(
                                      show: true,
                                      labelResolver: (_) => "Aman",
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 🚨 KONDISI KRITIS (NEW INFO)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber, color: Colors.orange),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              kondisiKritisText,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
