import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class ConnectDevicePage extends StatefulWidget {
  const ConnectDevicePage({super.key});

  @override
  State<ConnectDevicePage> createState() => _ConnectDevicePageState();
}

class _ConnectDevicePageState extends State<ConnectDevicePage> {
  List<ScanResult> scanResults = [];
  bool isScanning = false;

  StreamSubscription<List<ScanResult>>? scanSubscription;

  @override
  void initState() {
    super.initState();
    startScan();
  }

  @override
  void dispose() {
    scanSubscription?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  Future<void> startScan() async {
    await requestPermissions();

    if (!mounted) return;

    setState(() {
      isScanning = true;
      scanResults.clear();
    });

    scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return;
      setState(() {
        scanResults = results
            .where((r) => r.device.platformName.isNotEmpty)
            .toList()
          ..sort((a, b) => a.device.platformName
              .toLowerCase()
              .compareTo(b.device.platformName.toLowerCase()));
      });
    });

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 5),
    );

    await Future.delayed(const Duration(seconds: 5));

    if (!mounted) return;

    setState(() {
      isScanning = false;
    });
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();

      List<BluetoothService> services = await device.discoverServices();

      for (BluetoothService service in services) {
        for (BluetoothCharacteristic char in service.characteristics) {
          if (char.properties.notify) {
            await char.setNotifyValue(true);
            char.lastValueStream.listen((value) {
              String response = String.fromCharCodes(value);
              if (response == "PAIRED-OK") {
                if (!mounted) return;
                Navigator.pop(context);
              }
            });
          }
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Terhubung ke ${device.platformName}, menunggu konfirmasi...",
          ),
        ),
      );
    } catch (e) {
      debugPrint("ERROR CONNECT: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Gagal terhubung, coba lagi")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Hubungkan Perangkat"),
        backgroundColor: Colors.blue,
      ),
      body: isScanning
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : scanResults.isEmpty
              ? const Center(
                  child: Text(
                    "Tidak ada device ditemukan",
                  ),
                )
              : ListView.builder(
                  itemCount: scanResults.length,
                  itemBuilder: (context, index) {
                    final result = scanResults[index];
                    final device = result.device;

                    return Card(
                      margin: const EdgeInsets.all(10),
                      child: ListTile(
                        leading: const Icon(Icons.bluetooth),
                        title: Text(
                          device.platformName.isNotEmpty
                              ? device.platformName
                              : "Unknown Device",
                        ),
                        subtitle: Text(device.remoteId.toString()),
                        trailing: ElevatedButton(
                          onPressed: () {
                            connectToDevice(device);
                          },
                          child: const Text("Connect"),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: startScan,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
