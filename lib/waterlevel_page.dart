import 'package:flutter/material.dart';
import '../helper/mysql_services.dart';
import '../helper/mqtt_services.dart';
import 'package:toastification/toastification.dart';

class WaterLevelPage extends StatefulWidget {
  final VoidCallback? onPinChanged; 
  const WaterLevelPage({super.key, this.onPinChanged});

  @override
  State<WaterLevelPage> createState() => _WaterLevelPageState();
}

class _WaterLevelPageState extends State<WaterLevelPage> {
  List<Map<String, dynamic>> tandons = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTandons();
  }

  Future<void> _loadTandons() async {
    final data = await MySQLService.getKodeTandon();
    setState(() {
      tandons = data;
      isLoading = false;
    });
  }

  Future<void> _togglePin(String kodeTandon, int currentPin) async {
    final newPin = currentPin == 1 ? 0 : 1;
    await MySQLService.updatePinTandon(kodeTandon, newPin);
    _loadTandons();
    widget.onPinChanged?.call();
  }

  void _showAddTandonDialog() {
    final kodeController = TextEditingController();
    final namaController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Tambah Tandon"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: kodeController,
              decoration: const InputDecoration(labelText: "Kode Tandon"),
            ),
            TextField(
              controller: namaController,
              decoration: const InputDecoration(labelText: "Nama Tandon"),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text("Batal"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text("Simpan"),
            onPressed: () async {
              await MySQLService.addTandon(
                kodeController.text,
                namaController.text,
              );
              Navigator.pop(context);
              _loadTandons();
            },
          ),
        ],
      ),
    );
  }

  void _showEditTandonDialog(
      BuildContext context,
      int tandonID,
      int tinggiMin,
      int tinggiMax,
      int tinggiTandon,
      ) {
    final tinggiMinController =
        TextEditingController(text: tinggiMin.toString());
    final tinggiMaxController =
        TextEditingController(text: tinggiMax.toString());
    final tinggiTandonController =
        TextEditingController(text: tinggiTandon.toString());

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Tandon"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
              decoration:
                  const InputDecoration(labelText: "Tinggi Tandon (cm)"),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text("Batal"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text("Update"),
            onPressed: () async {
              final tinggiMin = int.parse(tinggiMinController.text);
              final tinggiMax = int.parse(tinggiMaxController.text);
              final tinggiTandonBaru =
                  int.parse(tinggiTandonController.text);
              await MySQLService.updateParameterWaterLevel(
                tinggiMax,
                tinggiMin,
                tinggiTandonBaru,
                tandonID,
              );
              if (context.mounted) {
                await MQTTServices.publishMessage(
                  "iot/waterlevel/param/${tandons.firstWhere((t) => t['id'] == tandonID)['kode_tandon']}",
                  tinggiTandonBaru.toString(),
                );
                Navigator.pop(context);
                toastification.show(
                  context: context,
                  type: ToastificationType.success,
                  style: ToastificationStyle.flatColored,
                  title: const Text("Berhasil"),
                  description: const Text("Parameter berhasil diperbarui"),
                  autoCloseDuration: const Duration(seconds: 3),
                );
              }
              _loadTandons();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Water Level Management"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.blueAccent),
            onPressed: _showAddTandonDialog,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: tandons.length,
              itemBuilder: (context, index) {
                final tandon = tandons[index];
                final pinned = int.tryParse(tandon['pinned']?.toString() ?? '0') ?? 0;

                return Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
                      child: const Icon(Icons.water_drop, color: Colors.blueAccent),
                    ),
                    title: Text(
                      tandon['nama_tandon'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text("Kode: ${tandon['kode_tandon']}"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            pinned == 1 ? Icons.push_pin : Icons.push_pin_outlined,
                            color: pinned == 1 ? Colors.green : Colors.grey,
                          ),
                          onPressed: () => _togglePin(tandon['kode_tandon'], pinned),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.orange),
                          onPressed: () {
                            _showEditTandonDialog(
                              context,
                              int.parse(tandon['id'].toString()),
                              int.parse(tandon['tinggi_min'].toString()),
                              int.parse(tandon['tinggi_max'].toString()),
                              int.parse(tandon['tinggi_tandon'].toString()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
