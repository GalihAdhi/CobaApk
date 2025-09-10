import 'package:flutter/material.dart';
import 'package:flutter_floating_bottom_bar/flutter_floating_bottom_bar.dart';
import 'dashboard_page.dart';
import 'waterlevel_page.dart';
import '../helper/mqtt_services.dart';
import '../helper/mysql_services.dart';
import 'package:toastification/toastification.dart';
import 'dart:ui';

class AppWrapper extends StatefulWidget {
  const AppWrapper({super.key});

  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> pinnedTandons = [];
  Map<String, String> sensorData = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
      _initData(firstTime: true).then((_) => _initMQTT());
  }

  Future<void> _initData({bool firstTime = false}) async {
    final data = await MySQLService.getKodeTandon();

    if (firstTime) {
      // Auto-pin hanya kalau pertama kali app dijalankan
      for (var t in data) {
        if (t['pinned'] != 1) {
          await MySQLService.updatePinTandon(t['kode_tandon'], 1);
          t['pinned'] = 1;
        }
      }
    }

    // Update state pinnedTandons sesuai DB
    setState(() {
      pinnedTandons = data.where((t) => t['pinned'] == 1).toList();
      isLoading = false;
    });

    _subscribePinnedTandons();
  }

  void _subscribePinnedTandons() {
    for (var t in pinnedTandons) {
      debugPrint("coba subscribe");
      final topic = "iot/waterlevel/${t['kode_tandon']}";
      MQTTServices.subscribe(topic);
    }
  }


  Future<void> _initMQTT() async {
    await MQTTServices.connect();
    MQTTServices.setOnConnected(() {
      if (!mounted) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        toastification.show(
          context: context,
          type: ToastificationType.success,
          style: ToastificationStyle.flatColored,
          title: const Text("MQTT Connected"),
          autoCloseDuration: const Duration(seconds: 2),
        );
      });
      _subscribePinnedTandons();
    });

    MQTTServices.setMessageHandler((topic, message) {
      final kodeTandon = topic.split('/').last;
      setState(() {
        sensorData[kodeTandon] = message;
      });
    });

    MQTTServices.setOnDisconnected(() {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.flatColored,
          title: const Text("MQTT Disconnected"),
          autoCloseDuration: const Duration(seconds: 2),
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5F7FA), Color(0xFFE4EBF5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: BottomBar(
          fit: StackFit.expand,
          borderRadius: BorderRadius.circular(24),
          duration: const Duration(milliseconds: 300),
          barColor: Colors.white.withValues(alpha: 0.6),
          body: (context, controller) {
            if (_selectedIndex == 0) {
              return isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : DashboardPage(
                      pinnedTandons: pinnedTandons,
                      sensorData: sensorData,
                    );
            } else {
              return WaterLevelPage(
                onPinChanged: () async {
                  await _initData();
                },
              );
            }
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _navItem(Icons.dashboard, "Dashboard", 0),
                    _navItem(Icons.water_drop, "Water Level", 1),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: isSelected
            ? BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 250),
              scale: isSelected ? 1.2 : 1.0,
              child: Icon(
                icon,
                color: isSelected ? Colors.blueAccent : Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.blueAccent : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
