import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../Firebasesetup.dart';
import '../models.dart';
import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class AdminWaitRecordsScreen extends StatefulWidget {
  const AdminWaitRecordsScreen({super.key});

  @override
  State<AdminWaitRecordsScreen> createState() => _AdminWaitRecordsScreenState();
}

class _AdminWaitRecordsScreenState extends State<AdminWaitRecordsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = 'All';
  final List<String> _statuses = ['All', 'Inward', 'Outward'];
  List<WaitRecord> _cachedRecords = [];
  bool _isLoading = false;
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  final GlobalKey _refreshIndicatorKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (_cachedRecords.isEmpty) {
      await _refreshData();
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseService.firestore
          .collection('wait_records')
          .orderBy('inWaitTime', descending: true)
          .get();

      _cachedRecords = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return WaitRecord.fromMap(data);
      }).toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDate(DateTime dt) => DateFormat('dd/MM/yyyy HH:mm').format(dt);

  String _calcDuration(DateTime inTime, DateTime? outTime) {
    if (outTime == null) return '—';
    final dur = outTime.difference(inTime);
    return '${dur.inHours}h ${dur.inMinutes.remainder(60)}m';
  }

  Future<void> _exportAndShareData(List<WaitRecord> records) async {
    try {
      List<List<dynamic>> csvData = [
        [
          'S.No',
          'Dealing Person',
          'Client',
          'Inward',
          'Inward Time',
          'Outward', // New column
          'Outward Time',
          'Duration',
          'Status',
        ],
        ...records.asMap().entries.map((entry) {
          final r = entry.value;
          return [
            entry.key + 1,
            r.staffName,
            r.clientName,
            r.fileName,
            _formatDate(r.inWaitTime),
            r.outFileName ?? '—', // New column data
            r.outWaitTime != null ? _formatDate(r.outWaitTime!) : '—',
            _calcDuration(r.inWaitTime, r.outWaitTime),
            r.isCompleted ? 'Outward' : 'Inward',
          ];
        }),
      ];

      String csv = const ListToCsvConverter().convert(csvData);

      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/wait_records_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File(path);
      await file.writeAsString(csv);
      await Share.shareXFiles([XFile(path)], text: 'Inward/Outward Records');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error exporting: $e')));
      }
    }
  }

  List<WaitRecord> _getFilteredRecords() {
    final query = _searchController.text.toLowerCase();
    return _cachedRecords.where((r) {
      final matchesSearch =
          query.isEmpty ||
          r.staffName.toLowerCase().contains(query) ||
          r.clientName.toLowerCase().contains(query) ||
          r.fileName.toLowerCase().contains(query);
      final matchesStatus =
          _selectedStatus == 'All' ||
          (_selectedStatus == 'Outward' && r.isCompleted) ||
          (_selectedStatus == 'Inward' && !r.isCompleted);
      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    final filteredRecords = _getFilteredRecords();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inward & Outward Register'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _exportAndShareData(filteredRecords),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refreshData(),
          ),
        ],
      ),
      body: RefreshIndicator(
        key: _refreshIndicatorKey,
        onRefresh: _refreshData,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: isSmallScreen
                  ? Column(
                      children: [
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                            hintText: 'Search...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: DropdownButtonFormField<String>(
                            value: _selectedStatus,
                            items: _statuses
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _selectedStatus = v);
                              }
                            },
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {});
                                      },
                                    )
                                  : null,
                              hintText: 'Search...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 150,
                          child: DropdownButtonFormField<String>(
                            value: _selectedStatus,
                            items: _statuses
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _selectedStatus = v);
                              }
                            },
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredRecords.isEmpty
                  ? const Center(child: Text('No records found'))
                  : ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context).copyWith(
                        dragDevices: {
                          PointerDeviceKind.touch,
                          PointerDeviceKind.mouse,
                        },
                      ),
                      child: Scrollbar(
                        controller: _verticalScrollController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _verticalScrollController,
                          child: Scrollbar(
                            controller: _horizontalScrollController,
                            thumbVisibility: true,
                            notificationPredicate: (notification) =>
                                notification.depth == 1,
                            child: SingleChildScrollView(
                              controller: _horizontalScrollController,
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columnSpacing: 20,
                                horizontalMargin: 20,
                                headingRowHeight: 56,
                                dataRowHeight: 60,
                                headingRowColor: WidgetStateProperty.all(
                                  Colors.grey.shade200,
                                ),
                                columns: const [
                                  DataColumn(
                                    label: Text('S.No'),
                                    numeric: true,
                                  ),
                                  DataColumn(label: Text('Dealing Person')),
                                  DataColumn(label: Text('Client')),
                                  DataColumn(label: Text('Inward')),
                                  DataColumn(label: Text('Inward Time')),
                                  DataColumn(label: Text('Outward')),
                                  DataColumn(label: Text('Outward Time')),
                                  DataColumn(label: Text('Duration')),
                                  DataColumn(label: Text('Status')),
                                ],
                                rows: List.generate(
                                  filteredRecords.length,
                                  (i) => DataRow(
                                    color: WidgetStateProperty.all<Color?>(
                                      i.isOdd ? Colors.grey.shade50 : null,
                                    ),
                                    cells: [
                                      DataCell(Text('${i + 1}')),
                                      DataCell(
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 150,
                                          ),
                                          child: Text(
                                            filteredRecords[i].staffName,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 150,
                                          ),
                                          child: Text(
                                            filteredRecords[i].clientName,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 150,
                                          ),
                                          child: Text(
                                            filteredRecords[i].fileName,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          _formatDate(
                                            filteredRecords[i].inWaitTime,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          filteredRecords[i].outFileName ??
                                              '—', // New Outward column data
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          filteredRecords[i].outWaitTime != null
                                              ? _formatDate(
                                                  filteredRecords[i]
                                                      .outWaitTime!,
                                                )
                                              : '—',
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          _calcDuration(
                                            filteredRecords[i].inWaitTime,
                                            filteredRecords[i].outWaitTime,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Chip(
                                          label: Text(
                                            filteredRecords[i].isCompleted
                                                ? 'Outward'
                                                : 'Inward',
                                            style: TextStyle(
                                              color:
                                                  filteredRecords[i].isCompleted
                                                  ? Colors.green
                                                  : Colors.orange,
                                            ),
                                          ),
                                          backgroundColor:
                                              filteredRecords[i].isCompleted
                                              ? Colors.green.shade100
                                              : Colors.orange.shade100,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
