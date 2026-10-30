import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/mqtt_service.dart';
import '../services/schedule_service.dart';
import '../services/note_service.dart';
import '../services/firebase_service.dart';

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  final _db = FirebaseFirestore.instance;
  final _user = FirebaseAuth.instance.currentUser;
  
  List<Map<String, dynamic>> _devices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  void _loadDevices() {
    if (_user == null) return;
    _db.collection('users').doc(_user!.uid).collection('devices').snapshots().listen((snap) {
      if (mounted) {
        setState(() {
          _devices = snap.docs.map((doc) => {
             'id': doc.id,
             'name': (doc.data() as Map<String, dynamic>)['name'] ?? doc.id,
          }).toList();
          _isLoading = false;
        });
      }
    });
  }

  void _addDeviceDialog() {
    final _controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Thêm Thiết Bị Mới', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _controller,
          decoration: const InputDecoration(
            labelText: 'Mã Thiết Bị (Device ID)',
            hintText: 'Ví dụ: ESP32_240AC4XXXXXX',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_controller.text.isNotEmpty && _user != null) {
                await _db.collection('users').doc(_user!.uid).collection('devices').doc(_controller.text.trim()).set({
                  'addedAt': FieldValue.serverTimestamp(),
                  'name': 'Vườn ' + _controller.text.trim().substring(0, 5),
                });
                if (mounted) Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
            child: const Text('Thêm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _renameDeviceDialog(String devId, String currentName) {
    final _controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Đổi Tên Vườn', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _controller,
          decoration: const InputDecoration(labelText: 'Tên Vườn Mới'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              if (_controller.text.isNotEmpty && _user != null) {
                await _db.collection('users').doc(_user!.uid).collection('devices').doc(devId).set({
                  'name': _controller.text.trim(),
                }, SetOptions(merge: true));
                if (mounted) Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
            child: const Text('Lưu', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _deleteDeviceDialog(String devId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xóa Vườn', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: const Text('Bạn có chắc chắn muốn xóa vườn này khỏi danh sách quản lý?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              if (_user != null) {
                await _db.collection('users').doc(_user!.uid).collection('devices').doc(devId).delete();
                if (mounted) Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _selectDevice(String deviceId) {
    // Cập nhật Provider với deviceId mới
    final mqtt = Provider.of<MqttService>(context, listen: false);
    final schedule = Provider.of<ScheduleService>(context, listen: false);
    final note = Provider.of<NoteService>(context, listen: false);

    mqtt.setDeviceId(deviceId);
    schedule.setDeviceId(deviceId);
    note.setDeviceId(deviceId);
    FirebaseService.instance.setDeviceId(deviceId);

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MainShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[50],
      appBar: AppBar(
        title: const Text('Danh sách Vườn'),
        backgroundColor: const Color(0xFF16A34A),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _devices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.grass, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'Bạn chưa thêm vườn nào.',
                        style: GoogleFonts.inter(fontSize: 18, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _devices.length,
                  itemBuilder: (context, index) {
                    final dev = _devices[index];
                    final devId = dev['id'];
                    final devName = dev['name'];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFF16A34A),
                          child: Icon(Icons.eco, color: Colors.white),
                        ),
                        title: Text(devName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(devId, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (val) {
                            if (val == 'rename') _renameDeviceDialog(devId, devName);
                            if (val == 'delete') _deleteDeviceDialog(devId);
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'rename', child: Text('Đổi tên')),
                            const PopupMenuItem(value: 'delete', child: Text('Xóa', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                        onTap: () => _selectDevice(devId),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addDeviceDialog,
        backgroundColor: const Color(0xFF16A34A),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Thêm vườn', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
