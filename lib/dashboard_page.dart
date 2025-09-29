import 'dart:async';
import 'package:flutter/material.dart';
import '../helper/mysql_services.dart';
import 'detail_waterlevel_page.dart';
import 'detail_tingkatkebisingan_page.dart';
import 'detail_suhu_page.dart';

class DashboardPage extends StatefulWidget {
  final List<Map<String, dynamic>> pinnedTandons;
  final Map<String, String> sensorData;

  const DashboardPage({
    super.key,
    required this.pinnedTandons,
    required this.sensorData,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<Map<String, dynamic>> _ruangKebisingan = [];
  List<Map<String, dynamic>> _ruangSuhu = [];
  List<Map<String, dynamic>> _waterLevelItems = [];
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _loadData();
    });
  }

  @override
  void didUpdateWidget(covariant DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sensorData != widget.sensorData) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    // --- Kebisingan ---
    final ruangKebisingan = await MySQLService.getKodeRuanganKebisingan();
    final List<Map<String, dynamic>> kebisinganWithValue = [];

    for (var ruang in ruangKebisingan) {
      final data = await MySQLService.getTingkatKebisingan(ruang['kode_ruang']);
      if (data.isNotEmpty) {
        kebisinganWithValue.add({
          'nama': ruang['nama_ruang'],
          'value': "${data.last['tingkat_kebisingan']} dB",
          'kode': ruang['kode_ruang'],
          'type': 'noise',
        });
      }
    }

    // --- Suhu ---
    final ruangSuhu = await MySQLService.getKodeRuanganSuhu();
    final List<Map<String, dynamic>> suhuWithValue = [];

    for (var ruang in ruangSuhu) {
      final data = await MySQLService.getSuhu(ruang['kode_ruang']);
      if (data.isNotEmpty) {
        suhuWithValue.add({
          'nama': ruang['nama_ruang'],
          'value': "${data.first['suhu']}°C",
          'kode': ruang['kode_ruang'],
          'type': 'temp',
        });
      }
    }

    // --- Water Level ---
    final List<Map<String, dynamic>> waterWithValue = [];
    for (var tandon in widget.pinnedTandons) {
      final kodeTandon = int.tryParse(tandon['kode_tandon'].toString());
      final namaTandon = tandon['nama_tandon']?.toString() ?? 'Unknown';

      if (kodeTandon == null) continue;

      final sensorRaw = widget.sensorData[tandon['kode_tandon']];
      if (sensorRaw != null) {
        final jarakMatch =
            RegExp(r'jarak\s*:\s*(\d+\.?\d*)').firstMatch(sensorRaw);
        final persenMatch =
            RegExp(r'persen\s*:\s*(\d+\.?\d*)').firstMatch(sensorRaw);

        double? jarak =
            jarakMatch != null ? double.tryParse(jarakMatch.group(1)!) : null;
        double? persen =
            persenMatch != null ? double.tryParse(persenMatch.group(1)!) : null;

        final params = await MySQLService.getParameterTandon(kodeTandon);
        if (params.isNotEmpty && jarak != null) {
          final tinggiTandon = params.first['tinggitandon'] as num;
          final tinggiAir = tinggiTandon - jarak;

          waterWithValue.add({
            'nama': namaTandon,
            'value': (persen != null)
                ? "${tinggiAir.toStringAsFixed(1)} cm | ${persen.toStringAsFixed(0)}%"
                : "${tinggiAir.toStringAsFixed(1)} cm | ?%",
            'kode': tandon['kode_tandon'],
            'type': 'water',
          });
        } else {
          waterWithValue.add({
            'nama': namaTandon,
            'value': "Menunggu data...",
            'kode': tandon['kode_tandon'],
            'type': 'water',
          });
        }
      } else {
        waterWithValue.add({
          'nama': namaTandon,
          'value': "Menunggu data...",
          'kode': tandon['kode_tandon'],
          'type': 'water',
        });
      }
    }

    // Update state
    if (mounted) {
      setState(() {
        _ruangKebisingan = kebisinganWithValue;
        _ruangSuhu = suhuWithValue;
        _waterLevelItems = waterWithValue;
      });
    }
  }

  Widget _buildSection(
    String title,
    IconData icon,
    Color color,
    List<Map<String, dynamic>> items,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
        ),
        ...items.map((item) => Card(
              elevation: 3,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                title: Text(item['nama']),
                trailing: Text(
                  item['value'],
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontSize: 16),
                ),
                onTap: () {
                  if (item['type'] == 'water') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            DetailWaterLevelPage(kodeTandon: item['kode']),
                      ),
                    );
                  } else if (item['type'] == 'noise') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetailTingkatKebisinganPage(
                            kodeRuangan: item['kode']),
                      ),
                    );
                  } else if (item['type'] == 'temp') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            DetailSuhuPage(kodeRuangan: item['kode']),
                      ),
                    );
                  }
                },
              ),
            )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Dashboard")),
      body: ListView(
        children: [
          _buildSection("Water Level", Icons.water_drop, Colors.blueAccent,
              _waterLevelItems),
          _buildSection("Tingkat Kebisingan", Icons.volume_up, Colors.orange,
              _ruangKebisingan),
          _buildSection(
              "Suhu", Icons.thermostat, Colors.redAccent, _ruangSuhu),
        ],
      ),
    );
  }
}
