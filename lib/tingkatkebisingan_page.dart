import 'dart:async';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:toastification/toastification.dart';
import 'helper/mysql_services.dart';

class TingkatKebisinganPage extends StatefulWidget {
  final String kodeRuangan;
  const TingkatKebisinganPage({super.key, required this.kodeRuangan});

  @override
  State<TingkatKebisinganPage> createState() => _TingkatKebisinganPageState();
}

class _TingkatKebisinganPageState extends State<TingkatKebisinganPage> {
  double dbSound = 0.0;
  String namaRuangan = "";
  int tenang = 0;
  int hening = 0;
  int bising = 0;
  DateTime? date;
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
      final data =
          await MySQLService.getTingkatKebisingan(widget.kodeRuangan);
      final param = await MySQLService.getParameter();
      if (data.isNotEmpty) {
        setState(() {
          dbSound = data.first['tingkat_kebisingan'] ?? 0.0;
          namaRuangan = data.first['nama_ruang'] ?? "";
          date = DateTime.parse(data.first['waktu']);
          if (param.isNotEmpty) {
            tenang = param.first['tenang'];
            hening = param.first['hening'];
            bising = param.first['bising'];
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching kebisingan: $e");
    }
  }

  void _showParameterSettings(BuildContext context) {
    final tenangController = TextEditingController(text: tenang.toString());
    final bisingController = TextEditingController(text: bising.toString());

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
                controller: tenangController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Tenang (dB)"),
              ),
              TextField(
                controller: bisingController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Bising (dB)"),
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
                  await MySQLService.updateParameterTingkatKebisingan(
                    int.tryParse(tenangController.text) ?? tenang,
                    int.tryParse(bisingController.text) ?? bising,
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

    String statusKebisingan;
    if (dbSound < tenang) {
      statusKebisingan = "Hening";
    } else if (dbSound >= tenang && dbSound < bising) {
      statusKebisingan = "Tenang";
    } else {
      statusKebisingan = "Bising";
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Tingkat Kebisingan"),
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
                        minimum: 30,
                        maximum: 130,
                        axisLineStyle: const AxisLineStyle(
                          thickness: 28,
                          thicknessUnit: GaugeSizeUnit.logicalPixel,
                          color: Color(0xFFE0E0E0),
                          cornerStyle: CornerStyle.bothFlat,
                        ),
                        pointers: [
                          RangePointer(
                            value: dbSound,
                            width: 28,
                            sizeUnit: GaugeSizeUnit.logicalPixel,
                            cornerStyle: CornerStyle.bothCurve,
                            enableAnimation: true,
                            gradient: const SweepGradient(
                              colors: [Colors.green, Colors.orange, Colors.red],
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
                                  "${dbSound.toStringAsFixed(1)} dB",
                                  style: TextStyle(
                                    fontSize: 42,
                                    fontWeight: FontWeight.bold,
                                    color: dbSound < hening
                                        ? Colors.green
                                        : (dbSound < bising
                                            ? Colors.orange
                                            : Colors.red),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  statusKebisingan,
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
                            Text("Hening < $tenang dB",
                                style: const TextStyle(color: Colors.green)),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("$tenang dB < Tenang < $bising dB",
                                style: const TextStyle(color: Colors.orange)),
                          ],
                        ),
                         Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("$bising dB < Bising", style: TextStyle(color: Colors.red)),
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
