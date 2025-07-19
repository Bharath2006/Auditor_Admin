import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../Firebasesetup.dart';
import '../models.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

class StaffTaskScreen extends StatefulWidget {
  const StaffTaskScreen({super.key});

  @override
  State<StaffTaskScreen> createState() => _StaffTaskScreenState();
}

class _StaffTaskScreenState extends State<StaffTaskScreen> {
  final String _currentUserId = FirebaseService.auth.currentUser!.uid;
  String _searchText = '';
  String _selectedStatus = 'All';
  String _selectedEntity = 'All';
  String _selectedNatureOfWork = 'All';
  late TextEditingController _searchController;
  bool _isExporting = false;
  bool _showFilters = false;
  List<Task> _allTasks = [];
  List<Task> _filteredTasks = [];

  final List<String> _statuses = [
    'All',
    'Pending',
    'In Progress',
    'Complete',
    'Request_Pending',
  ];

  List<String> _entities = ['All'];
  List<String> _natureOfWorks = ['All'];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _markTaskAsComplete(String taskId, String status) async {
    if (status == 'Request_Pending') return;
    try {
      final userTaskRef = FirebaseService.firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('assigned_tasks')
          .doc(taskId);
      final mainTaskRef = FirebaseService.firestore
          .collection('tasks')
          .doc(taskId);

      await userTaskRef.update({'status': 'Complete'});
      await mainTaskRef.update({'status': 'Complete'});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task marked as complete')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _exportToCSV() async {
    setState(() => _isExporting = true);
    try {
      String csv =
          'S.No,Client,Assigned Date,Deadline,Nature of Work,Entity,Status\n';

      for (int i = 0; i < _filteredTasks.length; i++) {
        final task = _filteredTasks[i];
        final isOverdue =
            task.deadline.isBefore(DateTime.now()) && task.status != 'Complete';
        csv +=
            '${i + 1},"${task.clientName}","'
            '${DateFormat('dd/MM/yyyy').format(task.assignDate)}","'
            '${DateFormat('dd/MM/yyyy').format(task.deadline)}${isOverdue ? ' (Overdue)' : ''}","'
            '${task.natureOfWork}","'
            '${task.natureOfEntity.trim().isEmpty ? 'No Entity' : task.natureOfEntity}","'
            '${task.status}"\n';
      }

      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/tasks_export_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File(path);

      await file.writeAsString(csv);

      await Share.shareXFiles(
        [XFile(path)],
        text: 'Tasks Export',
        subject: 'Exported Tasks',
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: ${e.toString()}')));
    } finally {
      setState(() => _isExporting = false);
    }
  }

  void _applyFilters() {
    final searchLower = _searchText.toLowerCase();
    _filteredTasks = _allTasks.where((task) {
      final matchesSearch =
          _searchText.isEmpty ||
          task.clientName.toLowerCase().contains(searchLower);
      final matchesStatus =
          _selectedStatus == 'All' || task.status == _selectedStatus;
      final matchesEntity =
          _selectedEntity == 'All' ||
          (_selectedEntity == 'No Entity' &&
              task.natureOfEntity.trim().isEmpty) ||
          task.natureOfEntity == _selectedEntity;
      final matchesWork =
          _selectedNatureOfWork == 'All' ||
          (_selectedNatureOfWork == 'No Work' &&
              task.natureOfWork.trim().isEmpty) ||
          task.natureOfWork == _selectedNatureOfWork;
      return matchesSearch && matchesStatus && matchesEntity && matchesWork;
    }).toList();

    // Sort by receivedDate in descending order (newest first)
    _filteredTasks.sort((a, b) => b.receivedDate.compareTo(a.receivedDate));
  }

  Widget _buildFilterDropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged, {
    bool isExpanded = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: isExpanded,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          items: items
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: (value) {
            onChanged(value);
            _applyFilters();
            setState(() {});
          },
        ),
      ],
    );
  }

  Widget _buildSearchHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by client name...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _searchText = '';
                        _applyFilters();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (val) {
              _searchText = val;
              _applyFilters();
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Tasks',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              IconButton(
                icon: Icon(
                  _showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
                  color: _showFilters ? Colors.blue : Colors.grey,
                ),
                onPressed: () => setState(() => _showFilters = !_showFilters),
                tooltip: 'Toggle filters',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildFilterDropdown(
                    'Work Type',
                    _selectedNatureOfWork,
                    _natureOfWorks,
                    (value) => _selectedNatureOfWork = value!,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildFilterDropdown(
                    'Entity',
                    _selectedEntity,
                    _entities,
                    (value) => _selectedEntity = value!,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildFilterDropdown(
              'Status',
              _selectedStatus,
              _statuses,
              (value) => _selectedStatus = value!,
              isExpanded: true,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  _selectedNatureOfWork = 'All';
                  _selectedEntity = 'All';
                  _selectedStatus = 'All';
                  _applyFilters();
                  setState(() {});
                },
                child: const Text('Reset Filters'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'complete':
        return Colors.green[100]!;
      case 'in progress':
        return Colors.blue[100]!;
      case 'request_pending':
        return Colors.grey[300]!;
      default:
        return Colors.orange[100]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tasks'),
        actions: [
          IconButton(
            icon: _isExporting
                ? const CircularProgressIndicator(color: Colors.white)
                : const Icon(Icons.download),
            onPressed: _isExporting ? null : _exportToCSV,
            tooltip: 'Export to CSV',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchHeader(),
          if (_showFilters) _buildFilterSection(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseService.firestore
                  .collection('users')
                  .doc(_currentUserId)
                  .collection('assigned_tasks')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No tasks assigned'));
                }
                _allTasks = snapshot.data!.docs.map((doc) {
                  final taskData = doc.data() as Map<String, dynamic>;
                  return Task.fromMap({...taskData, 'id': doc.id});
                }).toList();

                final entitySet = <String>{};
                final workSet = <String>{};
                for (var t in _allTasks) {
                  if (t.natureOfEntity.trim().isNotEmpty) {
                    entitySet.add(t.natureOfEntity.trim());
                  }
                  if (t.natureOfWork.trim().isNotEmpty) {
                    workSet.add(t.natureOfWork.trim());
                  }
                }
                _entities = ['All', ...entitySet];
                _natureOfWorks = ['All', ...workSet];

                _applyFilters();

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: DataTable(
                        headingRowHeight: 80,
                        dataRowHeight: 60,
                        headingRowColor: WidgetStateProperty.all(
                          Colors.grey[200],
                        ),
                        columns: const [
                          DataColumn(
                            label: Text(
                              'S.No',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Client',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Nature of Work',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Assigned Date',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'TAT Date',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Entity',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Status',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Action',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                        rows: _filteredTasks.asMap().entries.map((entry) {
                          final index = entry.key;
                          final task = entry.value;
                          final isOverdue =
                              task.deadline.isBefore(DateTime.now()) &&
                              task.status != 'Complete';
                          return DataRow(
                            color: WidgetStateProperty.resolveWith(
                              (states) => isOverdue ? Colors.red[50] : null,
                            ),
                            cells: [
                              DataCell(Text('${index + 1}')),
                              DataCell(
                                Text(
                                  task.clientName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DataCell(Text(task.natureOfWork)),
                              DataCell(
                                Text(
                                  DateFormat(
                                    'dd/MM/yyyy',
                                  ).format(task.assignDate),
                                ),
                              ),
                              DataCell(
                                Text(
                                  DateFormat(
                                    'dd/MM/yyyy',
                                  ).format(task.deadline),
                                  style: TextStyle(
                                    color: isOverdue
                                        ? Colors.red[700]
                                        : Colors.black,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  task.natureOfEntity.trim().isEmpty
                                      ? 'No Entity'
                                      : task.natureOfEntity,
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _statusColor(task.status),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    task.status,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                ElevatedButton(
                                  onPressed:
                                      (task.status == 'Complete' ||
                                          task.status == 'Request_Pending')
                                      ? null
                                      : () => _markTaskAsComplete(
                                          task.id,
                                          task.status,
                                        ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: task.status == 'Complete'
                                        ? Colors.grey
                                        : Colors.green,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text('Complete'),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
