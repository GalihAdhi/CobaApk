import 'dart:async';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:toastification/toastification.dart';
import 'helper/mysql_services.dart';

class DetailSuhuPage extends StatefulWidget {
  final String kodeRuangan;
  const DetailSuhuPage({super.key, required this.kodeRuangan});

  @override
  State<DetailSuhuPage> createState() => _DetailSuhuPageState();
}

class _DetailSuhuPageState extends State<DetailSuhuPage> {
  double suhu = 0.0;
  String namaRuangan = "";
  DateTime? date;
  int hot = 0;
  int cold = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null);
    _fetchData();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _fetchData());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final data = await MySQLService.getSuhu(widget.kodeRuangan);
      final param = await MySQLService.getParameter();
      if (data.isNotEmpty) {
        setState(() {
          suhu = data.first['suhu']?.toDouble() ?? 0.0;
          namaRuangan = data.first['nama_ruang'] ?? "";
          date = DateTime.tryParse(data.first['waktu']);
          if (param.isNotEmpty) {
              hot = param.first['hot'];
              cold = param.first['cold'];
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching suhu: $e");
    }
  }

  void _showParameterSettings(BuildContext context) {
    final hotController = TextEditingController(text: hot.toString());
    final coldController = TextEditingController(text: cold.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Edit Parameter",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: hotController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Hot (dB)"),
              ),
              TextField(
                controller: coldController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Cold (dB)"),
              ),
              const SizedBox(height: 20),

              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text("Simpan"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  await MySQLService.updateParameterSuhu(
                    int.tryParse(hotController.text) ?? cold,
                    int.tryParse(coldController.text) ?? hot,
                  );

                  if (context.mounted) {
                    Navigator.pop(context);
                    _fetchData();
                    toastification.show(
                      context: context,
                      type: ToastificationType.success,
                      style: ToastificationStyle.flatColored,
                      title: const Text("Berhasil"),
                      description: const Text("Parameter berhasil diperbarui"),
                      autoCloseDuration: const Duration(seconds: 3),
                    );
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = date != null
        ? DateFormat("dd MMMM yyyy HH:mm:ss", "id_ID").format(date!)
        : "-";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Monitoring Suhu"),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              namaRuangan,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              formattedDate,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),

            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 6,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 320,
                  child: SfRadialGauge(
                    enableLoadingAnimation: true,
                    animationDuration: 1200,
                    axes: [
                      RadialAxis(
                        showTicks: false,
                        showLabels: false,
                        startAngle: 180,
                        endAngle: 0,
                        minimum: 0,
                        maximum: 50,
                        axisLineStyle: const AxisLineStyle(
                          thickness: 28,
                          thicknessUnit: GaugeSizeUnit.logicalPixel,
                          color: Color(0xFFE0E0E0),
                          cornerStyle: CornerStyle.bothFlat,
                        ),
                        pointers: [
                          RangePointer(
                            value: suhu,
                            width: 28,
                            sizeUnit: GaugeSizeUnit.logicalPixel,
                            cornerStyle: CornerStyle.bothCurve,
                            enableAnimation: true,
                            gradient: const SweepGradient(
                              colors: [Colors.blue, Colors.green, Colors.red],
                              stops: [0.0, 0.5, 1.0],
                            ),
                          ),
                        ],
                        annotations: [
                          GaugeAnnotation(
                            widget: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "${suhu.toStringAsFixed(1)} °C",
                                  style: TextStyle(
                                    fontSize: 42,
                                    fontWeight: FontWeight.bold,
                                    color: suhu < cold
                                        ? Colors.blue
                                        : (suhu > hot
                                            ? Colors.red
                                            : Colors.green),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  suhu < 20
                                      ? "Dingin"
                                      : (suhu < 35 ? "Normal" : "Panas"),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            positionFactor: 0.1,
                            angle: 90,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Batas Parameter",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Terlalu Dingin < $cold",
                                style: const TextStyle(color: Colors.blue)),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("$hot > Terlalu Panas", style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      icon: const Icon(Icons.settings, color: Colors.blue),
                      onPressed: () {
                        _showParameterSettings(context);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
