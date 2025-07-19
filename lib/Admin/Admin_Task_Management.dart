import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Firebasesetup.dart';
import '../models.dart';
import 'Admin_Task_Assigned.dart';
import 'Task_Editing.dart';

class TaskListTab extends StatefulWidget {
  const TaskListTab({super.key});
  @override
  State<TaskListTab> createState() => _TaskListTabState();
}

class _TaskListTabState extends State<TaskListTab> {
  String _searchQuery = '';
  String _workFilter = 'All';
  String _entityFilter = 'All';
  String _statusFilter = 'All';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _showFilters = false;
  bool _isRefreshing = false;
  final _scrollController = ScrollController();

  final List<String> _statuses = [
    'All',
    'Pending',
    'In Progress',
    'Complete',
    'Request_Pending',
    'Approved',
  ];
  List<String> _entities = ['All'];
  List<String> _natureOfWorks = ['All'];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFilterPreferences();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFilterPreferences() async {
    if (!kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _workFilter = prefs.getString('workFilter') ?? 'All';
        _entityFilter = prefs.getString('entityFilter') ?? 'All';
        _statusFilter = prefs.getString('statusFilter') ?? 'All';
      });
    }
  }

  Future<void> _saveFilterPreferences() async {
    if (!kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('workFilter', _workFilter);
      await prefs.setString('entityFilter', _entityFilter);
      await prefs.setString('statusFilter', _statusFilter);
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);
    if (!kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      _loadFilterPreferences();
    }
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _isRefreshing = false);
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          // Fixed header with search and filters
          Material(
            elevation: 4,
            child: Column(
              children: [
                _buildSearchHeader(),
                if (_showFilters) _buildFilterSection(),
              ],
            ),
          ),

          // Scrollable table area
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshData,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseService.firestore
                    .collection('tasks')
                    .snapshots(),
                builder: (context, taskSnap) {
                  if (taskSnap.hasError) {
                    return const Center(child: Text('Error loading tasks'));
                  }
                  if (taskSnap.connectionState == ConnectionState.waiting &&
                      !_isRefreshing) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final rawTasks = taskSnap.data!.docs
                      .map((d) {
                        try {
                          return Task.fromMap(
                            d.data()! as Map<String, dynamic>,
                          );
                        } catch (_) {
                          return null;
                        }
                      })
                      .whereType<Task>()
                      .toList();

                  final entSet = <String>{};
                  final workSet = <String>{};
                  for (var t in rawTasks) {
                    if (t.natureOfEntity.trim().isNotEmpty) {
                      entSet.add(t.natureOfEntity.trim());
                    }
                    if (t.natureOfWork.trim().isNotEmpty) {
                      workSet.add(t.natureOfWork.trim());
                    }
                  }
                  _entities = ['All', ...entSet];
                  _natureOfWorks = ['All', ...workSet];

                  return FutureBuilder<List<Map<String, dynamic>>>(
                    future: _fetchTasksWithStaff(rawTasks),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting &&
                          !_isRefreshing) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final list = (snap.data ?? []).where((m) {
                        final t = m['task'] as Task;
                        final names = List<String>.from(m['staffNames'] ?? []);
                        final receivedOrAssignedDate = t.receivedDate;

                        if (_searchQuery.isNotEmpty) {
                          final clientMatch = t.clientName
                              .toLowerCase()
                              .contains(_searchQuery.toLowerCase());
                          final staffMatch = names.any(
                            (n) => n.toLowerCase().contains(
                              _searchQuery.toLowerCase(),
                            ),
                          );
                          if (!clientMatch && !staffMatch) return false;
                        }

                        if (_startDate != null &&
                            receivedOrAssignedDate.isBefore(_startDate!)) {
                          return false;
                        }
                        if (_endDate != null &&
                            receivedOrAssignedDate.isAfter(_endDate!)) {
                          return false;
                        }

                        if (_workFilter != 'All' &&
                            t.natureOfWork != _workFilter) {
                          return false;
                        }
                        if (_entityFilter != 'All' &&
                            t.natureOfEntity != _entityFilter) {
                          return false;
                        }
                        if (_statusFilter != 'All' &&
                            t.status != _statusFilter) {
                          return false;
                        }
                        return true;
                      }).toList();

                      if (list.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.search_off,
                                size: 48,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No tasks found',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              if (_searchQuery.isNotEmpty ||
                                  _workFilter != 'All' ||
                                  _entityFilter != 'All' ||
                                  _statusFilter != 'All' ||
                                  _startDate != null ||
                                  _endDate != null)
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _searchQuery = '';
                                      _workFilter = 'All';
                                      _entityFilter = 'All';
                                      _statusFilter = 'All';
                                      _startDate = null;
                                      _endDate = null;
                                      _searchController.clear();
                                      _saveFilterPreferences();
                                    });
                                  },
                                  child: const Text('Clear all filters'),
                                ),
                            ],
                          ),
                        );
                      }

                      return Scrollbar(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: DataTable(
                                  headingRowHeight: 80,
                                  dataRowHeight: 60,
                                  headingRowColor: WidgetStateProperty.all(
                                    Colors.grey[100],
                                  ),
                                  columns: _buildColumns(),
                                  rows: List.generate(list.length, (i) {
                                    final map = list[i];
                                    final t = map['task'] as Task;
                                    final names = List<String>.from(
                                      map['staffNames'] ?? [],
                                    );
                                    final overdue =
                                        t.deadline.isBefore(DateTime.now()) &&
                                        t.status.toLowerCase() != 'complete';
                                    final receivedOrAssignedDate =
                                        t.receivedDate;
                                    return DataRow(
                                      color: WidgetStateProperty.resolveWith((
                                        s,
                                      ) {
                                        if (overdue) return Colors.red[50];
                                        return (i % 2 == 1)
                                            ? Colors.grey[50]
                                            : Colors.white;
                                      }),
                                      cells: [
                                        DataCell(Text('${i + 1}')),
                                        DataCell(
                                          Text(
                                            DateFormat(
                                              'dd/MM/yyyy',
                                            ).format(receivedOrAssignedDate),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            t.clientName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        DataCell(Text(t.natureOfWork)),
                                        DataCell(Text(names.join(', '))),
                                        DataCell(
                                          Text(
                                            DateFormat(
                                              'dd/MM/yyyy',
                                            ).format(t.assignDate),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            DateFormat(
                                              'dd/MM/yyyy',
                                            ).format(t.deadline),
                                            style: TextStyle(
                                              color: overdue
                                                  ? Colors.red
                                                  : null,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            t.natureOfEntity.isEmpty
                                                ? 'No Entity'
                                                : t.natureOfEntity,
                                          ),
                                        ),
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _statusColor(t.status),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              t.status,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          IconButton(
                                            icon: const Icon(Icons.edit),
                                            onPressed: () => _editTask(t),
                                          ),
                                        ),
                                      ],
                                    );
                                  }),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueAccent,
        tooltip: 'Create New Task',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TaskAssignmentScreen()),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchTasksWithStaff(
    List<Task> tasks,
  ) async {
    final out = <Map<String, dynamic>>[];
    for (var t in tasks) {
      final names = <String>[];
      for (var id in t.assignedStaffIds) {
        try {
          final doc = await FirebaseService.firestore
              .collection('users')
              .doc(id)
              .get();
          if (doc.exists) names.add(doc.data()?['name'] ?? '—');
        } catch (_) {}
      }
      out.add({'task': t, 'staffNames': names});
    }

    // Sort by receivedDate in descending order (newest first)
    out.sort((a, b) {
      final taskA = a['task'] as Task;
      final taskB = b['task'] as Task;
      return taskB.receivedDate.compareTo(
        taskA.receivedDate,
      ); // Note: reversed order
    });

    return out;
  }

  Widget _buildSearchHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by client name or assigned staff...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Task List',
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final scale = (screenWidth / 400).clamp(0.8, 1.2);
        final paddingAll = 16.0 * scale;
        final dropdownSpacing = 16.0 * scale;
        final fontSizeLabel = 10.0 * scale;
        final iconSize = 15.0 * scale;
        final dateFieldVertical = 6.0 * scale;

        return SingleChildScrollView(
          child: Card(
            margin: EdgeInsets.symmetric(
              horizontal: 16.0 * scale,
              vertical: 8.0 * scale,
            ),
            child: Padding(
              padding: EdgeInsets.all(paddingAll),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildFilterDropdown(
                          'Work Type',
                          _workFilter,
                          _natureOfWorks,
                          (value) {
                            setState(() => _workFilter = value!);
                            _saveFilterPreferences();
                          },
                          fontSize: fontSizeLabel,
                          scale: scale,
                        ),
                      ),
                      SizedBox(width: dropdownSpacing),
                      Expanded(
                        child: _buildFilterDropdown(
                          'Entity',
                          _entityFilter,
                          _entities,
                          (value) {
                            setState(() => _entityFilter = value!);
                            _saveFilterPreferences();
                          },
                          fontSize: fontSizeLabel,
                          scale: scale,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: dropdownSpacing),
                  _buildFilterDropdown(
                    'Status',
                    _statusFilter,
                    _statuses,
                    (value) {
                      setState(() => _statusFilter = value!);
                      _saveFilterPreferences();
                    },
                    isExpanded: true,
                    fontSize: fontSizeLabel,
                    scale: scale,
                  ),
                  SizedBox(height: dropdownSpacing),
                  LayoutBuilder(
                    builder: (context, inner) {
                      final isWide = inner.maxWidth > 600;
                      if (isWide) {
                        return Row(
                          children: [
                            Expanded(
                              child: _buildDatePickerField(
                                context,
                                'From Date',
                                _startDate,
                                true,
                                fontSize: fontSizeLabel,
                                iconSize: iconSize,
                                verticalPadding: dateFieldVertical,
                                scale: scale,
                              ),
                            ),
                            SizedBox(width: dropdownSpacing),
                            Expanded(
                              child: _buildDatePickerField(
                                context,
                                'To Date',
                                _endDate,
                                false,
                                fontSize: fontSizeLabel,
                                iconSize: iconSize,
                                verticalPadding: dateFieldVertical,
                                scale: scale,
                              ),
                            ),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            _buildDatePickerField(
                              context,
                              'From Date',
                              _startDate,
                              true,
                              fontSize: fontSizeLabel,
                              iconSize: iconSize,
                              verticalPadding: dateFieldVertical,
                              scale: scale,
                            ),
                            SizedBox(height: dropdownSpacing),
                            _buildDatePickerField(
                              context,
                              'To Date',
                              _endDate,
                              false,
                              fontSize: fontSizeLabel,
                              iconSize: iconSize,
                              verticalPadding: dateFieldVertical,
                              scale: scale,
                            ),
                          ],
                        );
                      }
                    },
                  ),
                  SizedBox(height: 8.0 * scale),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _workFilter = 'All';
                          _entityFilter = 'All';
                          _statusFilter = 'All';
                          _startDate = null;
                          _endDate = null;
                          _saveFilterPreferences();
                        });
                      },
                      child: Text(
                        'Reset Filters',
                        style: TextStyle(fontSize: fontSizeLabel),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDatePickerField(
    BuildContext context,
    String label,
    DateTime? date,
    bool isStartDate, {
    required double fontSize,
    required double iconSize,
    required double verticalPadding,
    required double scale,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            color: Colors.grey[700],
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4.0 * scale),
        InkWell(
          onTap: () => _selectDate(context, isStartDate),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 12.0 * scale,
              vertical: verticalPadding,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8.0 * scale),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today, size: iconSize),
                SizedBox(width: 8.0 * scale),
                Expanded(
                  child: Text(
                    date != null
                        ? DateFormat('dd/MM/yyyy').format(date)
                        : 'Select ${label.toLowerCase()}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: fontSize),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged, {
    bool isExpanded = false,
    double fontSize = 14.0,
    double scale = 1.0,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            color: Colors.grey[700],
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4.0 * scale),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: isExpanded,
          decoration: InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 12.0 * scale),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0 * scale),
            ),
          ),
          items: items
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(item, style: TextStyle(fontSize: fontSize)),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  List<DataColumn> _buildColumns() => [
    const DataColumn(
      label: Text('S.No', style: TextStyle(fontWeight: FontWeight.bold)),
    ),
    const DataColumn(
      label: Text(
        'Received Date',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    ),
    const DataColumn(
      label: Text('Client Name', style: TextStyle(fontWeight: FontWeight.bold)),
    ),
    const DataColumn(
      label: Text(
        'Nature of Work',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    ),
    const DataColumn(
      label: Text('Assigned To', style: TextStyle(fontWeight: FontWeight.bold)),
    ),
    const DataColumn(
      label: Text(
        'Assigned Date',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    ),
    const DataColumn(
      label: Text('TAT Date', style: TextStyle(fontWeight: FontWeight.bold)),
    ),
    const DataColumn(
      label: Text('Entity', style: TextStyle(fontWeight: FontWeight.bold)),
    ),
    const DataColumn(
      label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
    ),
    const DataColumn(
      label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold)),
    ),
  ];

  Future<void> _editTask(Task t) async {
    final res = await showDialog(
      context: context,
      builder: (_) => TaskEditDialog(task: t),
    );
    if (res == true) setState(() {});
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'complete':
        return Colors.green[100]!;
      case 'in progress':
        return Colors.blue[100]!;
      case 'approved':
        return Colors.lightBlue[100]!;
      case 'request_pending':
        return Colors.grey[300]!;
      default:
        return Colors.orange[100]!;
    }
  }
}
