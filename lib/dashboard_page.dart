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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final ruangKebisingan = await MySQLService.getKodeRuanganKebisingan();
    final List<Map<String, dynamic>> kebisinganWithValue = [];

    for (var ruang in ruangKebisingan) {
      final data = await MySQLService.getTingkatKebisingan(ruang['kode_ruang']);
      if (data.isNotEmpty) {
        kebisinganWithValue.add({
          'nama': ruang['nama_ruang'],
          'value': "${data.last['tingkat_kebisingan']} dB",
          'kode_ruang': ruang['kode_ruang'],
        });
      }
    }

    final ruangSuhu = await MySQLService.getKodeRuanganSuhu();
    final List<Map<String, dynamic>> suhuWithValue = [];

    for (var ruang in ruangSuhu) {
      final data = await MySQLService.getSuhu(ruang['kode_ruang']);
      if (data.isNotEmpty) {
        suhuWithValue.add({
          'nama': ruang['nama_ruang'],
          'value': "${data.first['suhu']}°C",
           'kode_ruang': ruang['kode_ruang'],
        });
      }
    }

    setState(() {
      _ruangKebisingan = kebisinganWithValue;
      _ruangSuhu = suhuWithValue;
    });
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
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
        ),
        ...items.map((item) => Card(
              elevation: 3,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                title: Text(item['nama']),
                trailing: Text(
                  item['value'],
                  style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16),
                ),
                onTap: () {
                  if (item['type'] == 'water') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetailWaterLevelPage(kodeTandon: item['kode']),
                      ),
                    );
                  } else if (item['type'] == 'noise') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetailTingkatKebisinganPage(kodeRuangan: item['kode']),
                      ),
                    );
                  } else if (item['type'] == 'temp') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetailSuhuPage(kodeRuangan: item['kode']),
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
    final waterLevelItems = widget.pinnedTandons.map((tandon) => {
      'nama': tandon['nama_tandon']?.toString() ?? 'Unknown',
      'value': widget.sensorData[tandon['kode_tandon']]?.toString() ?? "Menunggu data...",
      'kode': tandon['kode_tandon']?.toString() ?? '',
      'type': 'water',
    }).toList();
    final kebisinganItems = _ruangKebisingan.map((ruang) => {
      'nama': ruang['nama']?.toString() ?? '',
      'value': ruang['value']?.toString() ?? '',
      'kode': ruang['kode_ruang']?.toString() ?? '',
      'type': 'noise',
    }).toList();
    final suhuItems = _ruangSuhu.map((ruang) => {
      'nama': ruang['nama']?.toString() ?? '',
      'value': ruang['value']?.toString() ?? '',
      'kode': ruang['kode_ruang']?.toString() ?? '',
      'type': 'temp',
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Dashboard")),
      body: ListView(
        children: [
          _buildSection("Water Level", Icons.water_drop, Colors.blueAccent, waterLevelItems),
          _buildSection("Tingkat Kebisingan", Icons.volume_up, Colors.orange, kebisinganItems),
          _buildSection("Suhu Ruangan", Icons.thermostat, Colors.redAccent, suhuItems),
        ],
      ),
    );
  }
}
