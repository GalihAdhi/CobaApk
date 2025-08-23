import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:toastification/toastification.dart';
import 'helper/mysql_services.dart';

class WaterLevelPage extends StatefulWidget {
  final String kodeTandon;
  const WaterLevelPage({super.key, required this.kodeTandon});

  @override
  State<WaterLevelPage> createState() => _WaterLevelPageState();
}

class _WaterLevelPageState extends State<WaterLevelPage> {
  late final MqttServerClient client;
  StreamSubscription? subscription;

  double waterPercent = 0.0;
  String lastUpdate = "-";

  int tinggimax = 0;
  int tinggimin = 0;

  String mode = "AUTO";
  bool pumpOn = false;

  late final String topicData;
  late final String topicMode;
  late final String topicOnOff;
  late final String topicAuto;

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
    topicAuto = "iot/waterlevel/tombol/mode/auto/${widget.kodeTandon}";

    _fetchData();
    _connectMQTT();
  }

  Future<void> _fetchData() async {
    try {
      final param = await MySQLService.getParameter();
      if (param.isNotEmpty) {
        tinggimax = param.first['tinggi_max'];
        tinggimin = param.first['tinggi_min'];
      }
    } catch (e) {
      debugPrint("Error fetching water_level: $e");
    }
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
            final distance = double.tryParse(message);
            if (distance == null) {
              debugPrint("⚠️ Invalid number: $message");
              return;
            }

            final percent = _convertToPercent(distance);

            if (mounted) {
              setState(() {
                waterPercent = percent.isNaN || percent.isInfinite ? 0.0 : percent;
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
    } else if (type == "auto") {
      topic = topicAuto;
    } else {
      topic = topicOnOff;
    }

    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);

    client.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
    debugPrint("➡️ Publish: $topic | $payload");
  }

  double _convertToPercent(double distance) {
    const double minDist = 20.0;
    const double maxDist = 250.0;
    if (distance <= minDist) return 100;
    if (distance >= maxDist) return 0;
    double percent = ((maxDist - distance) / (maxDist - minDist)) * 100;
    return percent.clamp(0, 100);
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