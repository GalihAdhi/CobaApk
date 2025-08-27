import 'dart:async';
import 'package:flutter/material.dart';

import 'helper/mysql_services.dart';
import 'waterlevel_page.dart';
import 'tingkatkebisingan_page.dart';
import 'suhu_page.dart';
import 'login_page.dart';

class DashboardPage extends StatefulWidget {
  final String username;

  const DashboardPage({super.key, required this.username});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<Map<String, dynamic>> tandonList = [];
  List<Map<String, dynamic>> ruangKebisinganList = [];
  List<Map<String, dynamic>> ruangSuhuList = [];

  String? selectedTandonCode;
  String? selectedRuangKebisingan;
  String? selectedRuangSuhu;

  int? expandedIndex;


  @override
  void initState() {
    super.initState();
    _fetchTandon();
    _fetchRuanganKebisingan();
    _fetchRuanganSuhu();
  }

  Future<void> _fetchTandon() async {
    try {
      final data = await MySQLService.getKodeTandon();
      setState(() {
        tandonList = data;
      });
    } catch (e) {
      debugPrint("Error fetching tandon: $e");
    }
  }

  Future<void> _fetchRuanganKebisingan() async {
    try {
      final data = await MySQLService.getKodeRuanganKebisingan();
      setState(() {
        ruangKebisinganList = data;
      });
    } catch (e) {
      debugPrint("Error fetching ruangan: $e");
    }
  }

  Future<void> _fetchRuanganSuhu() async {
    try {
      final data = await MySQLService.getKodeRuanganSuhu();
      setState(() {
        ruangSuhuList = data;
      });
    } catch (e) {
      debugPrint("Error fetching ruangan: $e");
    }
  }

  void _goToWaterLevelPage() {
    if (selectedTandonCode != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WaterLevelPage(kodeTandon: selectedTandonCode!),
        ),
      );
    }
  }

  void _goToKebisinganPage() {
    if (selectedRuangKebisingan != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              TingkatKebisinganPage(kodeRuangan: selectedRuangKebisingan!),
        ),
      );
    }
  }

  void _goToSuhuPage() {
    if (selectedRuangSuhu != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SuhuPage(kodeRuangan: selectedRuangSuhu!),
        ),
      );
    }
  }

  void _logout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = [
      {
        "title": "Water Level",
        "icon": Icons.water_drop_rounded,
        "color": Colors.blueAccent,
        "dropdownValue": selectedTandonCode,
        "dropdownHint": "Pilih Tandon",
        "items": tandonList.map((t) {
          return DropdownMenuItem<String>(
            value: t['kode_tandon'],
            child: Text(t['nama_tandon']),
          );
        }).toList(),
        "onChanged": (String? value) {
          setState(() {
            selectedTandonCode = value;
          });
        },
        "buttonText": "Lihat Water Level",
        "onPressed": _goToWaterLevelPage,
      },
      {
        "title": "Tingkat Kebisingan",
        "icon": Icons.volume_up_rounded,
        "color": Colors.deepOrangeAccent,
        "dropdownValue": selectedRuangKebisingan,
        "dropdownHint": "Pilih Ruangan",
        "items": ruangKebisinganList.map((r) {
          return DropdownMenuItem<String>(
            value: r['kode_ruang'],
            child: Text(r['nama_ruang']),
          );
        }).toList(),
        "onChanged": (String? value) {
          setState(() {
            selectedRuangKebisingan = value;
          });
        },
        "buttonText": "Lihat Tingkat Kebisingan",
        "onPressed": _goToKebisinganPage,
      },
      {
        "title": "Suhu",
        "icon": Icons.thermostat_rounded,
        "color": Colors.red,
        "dropdownValue": selectedRuangSuhu,
        "dropdownHint": "Pilih Ruangan",
        "items": ruangSuhuList.map((r) {
          return DropdownMenuItem<String>(
            value: r['kode_ruang'],
            child: Text(r['nama_ruang']),
          );
        }).toList(),
        "onChanged": (String? value) {
          setState(() {
            selectedRuangSuhu = value;
          });
        },
        "buttonText": "Lihat Suhu",
        "onPressed": _goToSuhuPage,
      },
    ];

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Image(
                            image: AssetImage('assets/hospital.png'),
                            width: 38,
                            height: 38),
                        const SizedBox(width: 10),
                        Text(
                          "IoT Dashboard",
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium!
                              .copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      onPressed: _logout,
                      tooltip: "Logout",
                    ),
                  ],
                ),
              ),

              Text(
                "Selamat datang, ${widget.username}",
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: cards.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildCard(cards[index], index),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> c, int index) {
    final isExpanded = expandedIndex == index;

    return Card(
      elevation: 6,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            expandedIndex = isExpanded ? null : index;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: (c["color"] as Color).withValues(alpha: 0.10),
                    child: Icon(c["icon"] as IconData,
                        color: c["color"] as Color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      c["title"] as String,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey[600],
                  ),
                ],
              ),

              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: isExpanded
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          children: [
                            DropdownButton<String>(
                              value: c["dropdownValue"] as String?,
                              hint: Text(c["dropdownHint"] as String),
                              isExpanded: true,
                              items: c["items"] as List<DropdownMenuItem<String>>,
                              onChanged: c["onChanged"] as ValueChanged<String?>,
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: c["onPressed"] as VoidCallback,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: c["color"] as Color,
                                  foregroundColor: Colors.white,
                                  minimumSize:
                                      const Size(double.infinity, 48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                ),
                                child: Text(
                                  c["buttonText"] as String,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
