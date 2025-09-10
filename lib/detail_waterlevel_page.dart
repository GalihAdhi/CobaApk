import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:toastification/toastification.dart';
import 'helper/mysql_services.dart';

class DetailWaterLevelPage extends StatefulWidget {
  final String kodeTandon;
  const DetailWaterLevelPage({super.key, required this.kodeTandon});

  @override
  State<DetailWaterLevelPage> createState() => _DetailWaterLevelPageState();
}

class _DetailWaterLevelPageState extends State<DetailWaterLevelPage> {
  late final MqttServerClient client;
  StreamSubscription? subscription;

  double waterPercent = 0.0;
  String lastUpdate = "-";

  int tinggiMaxCm = 0;
  int tinggiMinCm = 0;
  int tinggiTandoncm = 0;

  int tinggiMaxPercent = 0;
  int tinggiMinPercent = 0;

  String mode = "AUTO";
  bool pumpOn = false;

  late final String topicData;
  late final String topicMode;
  late final String topicOnOff;
  late final String topicParam;

  bool _pageActive = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null);
    _pageActive = true;

    client = MqttServerClient(
      'broker.hivemq.com',
      'flutter_client_${DateTime.now().millisecondsSinceEpoch}',
    );

    topicData = "iot/waterlevel/${widget.kodeTandon}";
    topicMode = "iot/waterlevel/tombol/mode/${widget.kodeTandon}";
    topicOnOff = "iot/waterlevel/tombol/${widget.kodeTandon}";
    topicParam = "iot/waterlevel/param/${widget.kodeTandon}";

    _fetchData();
    _connectMQTT();
  }

  Future<void> _fetchData() async {
    try {
      final param = await MySQLService.getParameterTandon(int.parse(widget.kodeTandon));
      if (param.isNotEmpty) {
        final data = param.first;

      final tinggiTandon = (data['tinggitandon'] as num?)?.toInt() ?? 0;
      final maxPercent  = (data['tinggimax'] as num?)?.toInt() ?? 0;
      final minPercent  = (data['tinggimin'] as num?)?.toInt() ?? 0;
        setState(() {
          tinggiMaxPercent = maxPercent;
          tinggiMinPercent = minPercent;
          tinggiTandoncm = tinggiTandon;
        });

        debugPrint("🎯 Parameter Tandon ${widget.kodeTandon}: "
            "Max=${tinggiMinCm.toStringAsFixed(2)}cm "
            "| Min=${tinggiMaxCm.toStringAsFixed(2)}cm"
            "| tinggiTandon = ${tinggiTandoncm.toStringAsFixed(2)}");

        _publishMessage("param", "tinggiTandon=$tinggiTandoncm");
      }
    } catch (e) {
      debugPrint("❌ Error fetching parameter: $e");
    }
  }

  void _showParameterWaterLevelSettings(BuildContext context, int kodeTandon, int tinggiMin, int tinggiMax) {
    final tinggiMinController = TextEditingController(text: tinggiMin.toString());
    final tinggiMaxController = TextEditingController(text: tinggiMax.toString());
    final tinggiTandonController = TextEditingController(text: tinggiTandoncm.toString());

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
                "Edit Parameter Tandon",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: tinggiMinController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Tinggi Minimum (%)"),
              ),
              TextField(
                controller: tinggiMaxController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Tinggi Maksimum (%)"),
              ),
              TextField(
                controller: tinggiTandonController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Tinggi Tandon (cm)"),
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
                  await MySQLService.updateParameterWaterLevel(
                    int.tryParse(tinggiMaxController.text) ?? tinggiMax,
                    int.tryParse(tinggiMinController.text) ?? tinggiMin,
                    int.tryParse(tinggiTandonController.text) ?? tinggiTandoncm.toInt(),
                    kodeTandon,
                  );

                  if (context.mounted) {
                    Navigator.pop(context); 
                    _fetchData();
                    toastification.show(
                      context: context,
                      type: ToastificationType.success,
                      style: ToastificationStyle.flatColored,
                      title: const Text("Berhasil"),
                      description: const Text("Parameter tandon berhasil diperbarui"),
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
  
  Future<void> _connectMQTT() async {
    client.logging(on: false);
    client.keepAlivePeriod = 30;

    client.onDisconnected = () {
      debugPrint("❌ Disconnected from MQTT");

      if (!_pageActive || !mounted) return;

      toastification.show(
        context: context,
        type: ToastificationType.warning,
        style: ToastificationStyle.flatColored,
        title: const Text("MQTT Disconnected"),
        description: const Text("Koneksi MQTT terputus, mencoba reconnect..."),
        autoCloseDuration: const Duration(seconds: 3),
      );

      Future.delayed(const Duration(seconds: 3), () {
        if (_pageActive && mounted) {
          debugPrint("🔄 Attempting to reconnect MQTT...");
          _connectMQTT();
        }
      });
    };

    client.onConnected = () {
      debugPrint("✅ Connected to MQTT");
      if (!mounted) return;
      toastification.show(
        context: context,
        type: ToastificationType.success,
        style: ToastificationStyle.flatColored,
        title: const Text("MQTT Connected"),
        autoCloseDuration: const Duration(seconds: 3),
      );
    };

    client.onSubscribed = (t) => debugPrint("📡 Subscribed to $t");

    try {
      await client.connect();
    } catch (e) {
      debugPrint("⚠️ MQTT connect error: $e");
      client.disconnect();
      return;
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      client.subscribe(topicData, MqttQos.atMostOnce);

      subscription = client.updates?.listen((List<MqttReceivedMessage<MqttMessage>>? c) {
        if (c == null || c.isEmpty) return;

        final recMess = c[0].payload;
        final topic = c[0].topic;

        if (recMess is MqttPublishMessage) {
          final message = MqttPublishPayload.bytesToStringAsString(recMess.payload.message).trim();
          debugPrint("📩 [MQTT] Topic: $topic | Message: $message");

          if (topic == topicData) {
            final parts = message.split(",");
            int? percent;

            for (var p in parts) {
              p = p.trim();
              if (p.startsWith("persen:")) {
                percent = int.tryParse(p.replaceFirst("persen:", "").trim());
                break;
              }
            }

            if (percent == null) {
              debugPrint("⚠️ Invalid payload: $message");
              return;
            }

            if (mounted) {
              setState(() {
                waterPercent = percent!.clamp(0, 100).toDouble();
                lastUpdate = DateFormat("dd MMMM yyyy HH:mm:ss", "id_ID").format(DateTime.now());
              });
            }
          }
        }
      });
    } else {
      debugPrint("❌ MQTT connection failed");
      if (!_pageActive || !mounted) return;
      toastification.show(
        context: context,
        type: ToastificationType.error,
        title: const Text("MQTT Failed"),
        description: const Text("Gagal koneksi ke broker"),
        autoCloseDuration: const Duration(seconds: 3),
      );
    }
  }

  void _publishMessage(String type, String payload) {
    if (client.connectionStatus?.state != MqttConnectionState.connected) {
      debugPrint("⚠️ Cannot publish, not connected");
      return;
    }

    String topic;
    if (type == "mode") {
      topic = topicMode;
    } else if (type == "param") {
      topic = topicParam;
    } else {
      topic = topicOnOff;
    }

    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);

    client.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
    debugPrint("➡️ Publish: $topic | $payload");
  }

  void _toggleMode() {
    setState(() {
      mode = (mode == "AUTO") ? "MANUAL" : "AUTO";
      if (mode == "AUTO") pumpOn = false;
    });
    _publishMessage("mode", mode);
  }

  void _togglePump() {
    setState(() {
      pumpOn = !pumpOn;
    });
    _publishMessage("onoff", pumpOn ? "ON" : "OFF");
  }

  @override
  void dispose() {
    _pageActive = false;
    subscription?.cancel();
    client.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          "Tandon ${widget.kodeTandon}",
          style: const TextStyle(
            fontSize: 23,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      "Water Level",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      lastUpdate,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 250,
                      child: SfRadialGauge(
                        enableLoadingAnimation: true,
                        animationDuration: 1200,
                        axes: <RadialAxis>[
                          RadialAxis(
                            showTicks: false,
                            showLabels: false,
                            startAngle: 180,
                            endAngle: 0,
                            minimum: 0,
                            maximum: 100,
                            axisLineStyle: const AxisLineStyle(
                              thickness: 25,
                              thicknessUnit: GaugeSizeUnit.logicalPixel,
                              color: Color(0xFFE0E0E0),
                              cornerStyle: CornerStyle.bothFlat,
                            ),
                            pointers: <GaugePointer>[
                              RangePointer(
                                value: waterPercent,
                                width: 25,
                                sizeUnit: GaugeSizeUnit.logicalPixel,
                                cornerStyle: CornerStyle.bothCurve,
                                enableAnimation: true,
                                gradient: const SweepGradient(
                                  colors: [Colors.red, Colors.orange, Colors.blue],
                                  stops: [0.0, 0.5, 1.0],
                                ),
                              ),
                            ],
                            annotations: <GaugeAnnotation>[
                              GaugeAnnotation(
                                widget: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "${waterPercent.toStringAsFixed(0)}%",
                                      style: TextStyle(
                                        fontSize: 40,
                                        fontWeight: FontWeight.bold,
                                        color: waterPercent < 30
                                            ? Colors.red
                                            : (waterPercent < 70
                                                ? Colors.orange
                                                : Colors.blue),
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
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _toggleMode,
                      icon: Icon(mode == "AUTO"
                          ? Icons.auto_mode
                          : Icons.settings_remote_outlined),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        backgroundColor:
                            (mode == "AUTO") ? Colors.blue : Colors.orange,
                      ),
                      label: Text(
                        "Mode: $mode",
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),

                    const SizedBox(height: 20),

                    if (mode == "MANUAL")
                      ElevatedButton.icon(
                        onPressed: _togglePump,
                        icon: Icon(pumpOn ? Icons.power_off : Icons.power),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 55),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          backgroundColor:
                              pumpOn ? Colors.red : Colors.green,
                        ),
                        label: Text(
                          pumpOn ? "Turn OFF Pump" : "Turn ON Pump",
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    
                    if (mode == "AUTO")
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
                                      Text("Pompa Hidup < $tinggiMinPercent%",
                                          style: const TextStyle(color: Colors.green)),
                                    ],
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("$tinggiMaxPercent % < Pompa Mati", style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("Tinggi Tandon: $tinggiTandoncm", style: TextStyle(color: Colors.grey)),
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
                                  _showParameterWaterLevelSettings(context, int.parse(widget.kodeTandon), tinggiMinPercent, tinggiMaxPercent);
                                },
                              ),
                            ),
                          ],
                        ),
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
