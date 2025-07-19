import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../Firebasesetup.dart';
import '../models.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

class StaffWaitScreen extends StatefulWidget {
  const StaffWaitScreen({super.key});
  @override
  State<StaffWaitScreen> createState() => _StaffWaitScreenState();
}

class _StaffWaitScreenState extends State<StaffWaitScreen> {
  final String _uid = FirebaseService.auth.currentUser!.uid;
  String _userName = '';
  final _outFileCtrl = TextEditingController();
  final _clientCtrl = TextEditingController();
  final _fileCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  DateTime? _selectedDate;
  bool _isLoading = false;
  bool _isExporting = false;

  String _statusFilter = 'All';
  final List<String> _statusOptions = ['All', 'Inward', 'Outward'];

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  @override
  void dispose() {
    _outFileCtrl.dispose();
    _clientCtrl.dispose();
    _fileCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserName() async {
    final doc = await FirebaseService.firestore
        .collection('users')
        .doc(_uid)
        .get();
    if (doc.exists) {
      setState(() => _userName = doc['name'] ?? '');
    }
  }

  Future<void> _addInward() async {
    if (_clientCtrl.text.isEmpty || _fileCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Client & File required'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    final docRef = FirebaseService.firestore.collection('wait_records').doc();
    final rec = WaitRecord(
      id: docRef.id,
      staffId: _uid,
      staffName: _userName,
      clientName: _clientCtrl.text.trim(),
      fileName: _fileCtrl.text.trim(),
      inWaitTime: DateTime.now(),
      outWaitTime: null,
      isCompleted: false,
      outFileName: null,
    );
    await docRef.set(rec.toMap());
    _clientCtrl.clear();
    _fileCtrl.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Inward recorded'),
        backgroundColor: Colors.green,
      ),
    );
    setState(() => _isLoading = false);
  }

  Future<void> _addOutwardDirect() async {
    if (_clientCtrl.text.isEmpty ||
        _fileCtrl.text.isEmpty ||
        _outFileCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Client, File & Output File required'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    final now = DateTime.now();
    final docRef = FirebaseService.firestore.collection('wait_records').doc();
    final rec = WaitRecord(
      id: docRef.id,
      staffId: _uid,
      staffName: _userName,
      clientName: _clientCtrl.text.trim(),
      fileName: _fileCtrl.text.trim(),
      inWaitTime: now,
      outWaitTime: now,
      isCompleted: true,
      outFileName: _outFileCtrl.text.trim(),
    );
    await docRef.set(rec.toMap());
    _clientCtrl.clear();
    _fileCtrl.clear();
    _outFileCtrl.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Outward recorded directly'),
        backgroundColor: Colors.blue,
      ),
    );
    setState(() => _isLoading = false);
  }

  Future<void> _promptOutward(WaitRecord rec) async {
    final outCtrl = TextEditingController(text: rec.outFileName ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Record Outward'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: outCtrl,
                decoration: const InputDecoration(
                  labelText: 'Output File Name',
                  hintText: 'Type file name',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      await FirebaseService.firestore
          .collection('wait_records')
          .doc(rec.id)
          .update({
            'outWaitTime': DateTime.now(),
            'isCompleted': true,
            'outFileName': outCtrl.text.trim(),
          });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Outward recorded'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _clearDateFilter() {
    setState(() => _selectedDate = null);
  }

  String _fmt(DateTime dt) => DateFormat('dd/MM/yyyy HH:mm').format(dt);

  String _duration(DateTime inT, DateTime? outT) {
    if (outT == null) return '—';
    final d = outT.difference(inT);
    return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
  }

  bool _passesStatus(WaitRecord r) {
    if (_statusFilter == 'All') return true;
    return _statusFilter == 'Inward' ? !r.isCompleted : r.isCompleted;
  }

  bool _passesDateFilter(WaitRecord r) {
    if (_selectedDate == null) return true;
    final dt = r.inWaitTime;
    return dt.year == _selectedDate!.year &&
        dt.month == _selectedDate!.month &&
        dt.day == _selectedDate!.day;
  }

  Future<void> _exportToCSV(List<WaitRecord> records) async {
    setState(() => _isExporting = true);
    try {
      String csv =
          'S.No,Client,Inward,Inward Time,Outward,Outward Time,Duration,Status\n'; // Updated headers

      for (var i = 0; i < records.length; i++) {
        final r = records[i];
        final status = r.isCompleted ? 'Outward' : 'Inward';
        csv +=
            '${i + 1},'
            '"${r.clientName}","${r.fileName}",'
            '"${_fmt(r.inWaitTime)}",'
            '"${r.outFileName ?? '—'}",' // Outward (previously Out File)
            '"${r.outWaitTime != null ? _fmt(r.outWaitTime!) : '—'}",' // Outward Time
            '"${_duration(r.inWaitTime, r.outWaitTime)}",'
            '"$status"\n';
      }

      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/word_records_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File(path);

      await file.writeAsString(csv);
      await Share.shareXFiles(
        [XFile(path)],
        text: 'Inward/Outward Records Export',
        subject: 'Exported Inward/Outward Records',
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: ${e.toString()}')));
    } finally {
      setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Inward & Outward Register', style: GoogleFonts.openSans()),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _pickDate,
            tooltip: 'Filter by date',
          ),
          if (_selectedDate != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearDateFilter,
              tooltip: 'Clear date filter',
            ),
          IconButton(
            icon: _isExporting
                ? const CircularProgressIndicator(color: Colors.white)
                : const Icon(Icons.download),
            onPressed: _isExporting
                ? null
                : () async {
                    // Get current filtered data
                    final snap = await FirebaseService.firestore
                        .collection('wait_records')
                        .where('staffId', isEqualTo: _uid)
                        .orderBy('inWaitTime', descending: true)
                        .get();

                    final all = snap.docs
                        .map((d) {
                          final m = d.data();
                          m['id'] = d.id;
                          return WaitRecord.fromMap(m);
                        })
                        .where((r) {
                          final txt = _searchCtrl.text.toLowerCase();
                          final matchesText =
                              txt.isEmpty ||
                              r.clientName.toLowerCase().contains(txt) ||
                              r.fileName.toLowerCase().contains(txt);
                          return _passesDateFilter(r) &&
                              matchesText &&
                              _passesStatus(r);
                        })
                        .toList();

                    await _exportToCSV(all);
                  },
            tooltip: 'Export to CSV',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              SizedBox(
                                width: MediaQuery.of(context).size.width * 0.8,
                                child: TextField(
                                  controller: _clientCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'Client',
                                    prefixIcon: const Icon(Icons.person),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: MediaQuery.of(context).size.width * 0.8,
                                child: TextField(
                                  controller: _fileCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'File',
                                    prefixIcon: const Icon(
                                      Icons.insert_drive_file,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: MediaQuery.of(context).size.width * 0.8,
                                child: TextField(
                                  controller: _outFileCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'Output File',
                                    prefixIcon: const Icon(Icons.upload_file),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  shape: const StadiumBorder(),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 16,
                                  ),
                                ),
                                onPressed: _addInward,
                                child: const Text('Inward'),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  shape: const StadiumBorder(),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 16,
                                  ),
                                  backgroundColor: Colors.blueAccent,
                                ),
                                onPressed: _addOutwardDirect,
                                child: const Text('Outward Direct'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchCtrl,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  labelText: 'Search client or file',
                                  prefixIcon: const Icon(Icons.search),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            DropdownButton<String>(
                              value: _statusFilter,
                              items: _statusOptions
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(s),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _statusFilter = v);
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // === Data Table ===
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseService.firestore
                          .collection('wait_records')
                          .where('staffId', isEqualTo: _uid)
                          .orderBy('inWaitTime', descending: true)
                          .snapshots(),
                      builder: (ctx, snap) {
                        if (snap.hasError) {
                          return const Center(
                            child: Text('Error loading records'),
                          );
                        }
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final all = snap.data!.docs
                            .map((d) {
                              final m = d.data()! as Map<String, dynamic>;
                              m['id'] = d.id;
                              return WaitRecord.fromMap(m);
                            })
                            .where((r) {
                              final txt = _searchCtrl.text.toLowerCase();
                              final matchesText =
                                  txt.isEmpty ||
                                  r.clientName.toLowerCase().contains(txt) ||
                                  r.fileName.toLowerCase().contains(txt);
                              return _passesDateFilter(r) &&
                                  matchesText &&
                                  _passesStatus(r);
                            })
                            .toList();

                        if (all.isEmpty) {
                          return const Center(child: Text('No records found.'));
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(
                                    Colors.grey.shade200,
                                  ),
                                  dataRowHeight: 56,
                                  headingRowHeight: 56,
                                  columns: const [
                                    DataColumn(
                                      label: Text(
                                        'S.No',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Client',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Inward',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Inward Time',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Outward',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Outward Time',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Duration',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Status',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Action',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                  rows: List.generate(all.length, (i) {
                                    final r = all[i];
                                    final isOut = r.isCompleted;
                                    return DataRow(
                                      color: WidgetStateProperty.resolveWith(
                                        (states) => i.isOdd
                                            ? Colors.grey.shade50
                                            : null,
                                      ),
                                      cells: [
                                        DataCell(Text('${i + 1}')), // S.No
                                        DataCell(Text(r.clientName)),
                                        DataCell(
                                          Text(r.fileName),
                                        ), // Inward (previously File)
                                        DataCell(
                                          Text(_fmt(r.inWaitTime)),
                                        ), // Inward Time (previously In Time)
                                        DataCell(
                                          Text(r.outFileName ?? '—'),
                                        ), // Outward (previously Out File)
                                        DataCell(
                                          Text(
                                            r.outWaitTime != null
                                                ? _fmt(r.outWaitTime!)
                                                : '—',
                                          ),
                                        ), // Outward Time (previously Out Time)
                                        DataCell(
                                          Text(
                                            _duration(
                                              r.inWaitTime,
                                              r.outWaitTime,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isOut
                                                  ? Colors.green.shade100
                                                  : Colors.red.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              isOut ? 'Outward' : 'Inward',
                                              style: TextStyle(
                                                color: isOut
                                                    ? Colors.green.shade900
                                                    : Colors.red.shade900,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          isOut
                                              ? const SizedBox.shrink()
                                              : ElevatedButton(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            Colors.red.shade400,
                                                      ),
                                                  onPressed: () =>
                                                      _promptOutward(r),
                                                  child: const Text('Outward'),
                                                ),
                                        ),
                                      ],
                                    );
                                  }),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
