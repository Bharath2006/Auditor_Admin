import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../Firebasesetup.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

import '../models.dart';

class TaskAssignmentScreen extends StatefulWidget {
  const TaskAssignmentScreen({super.key});

  @override
  _TaskAssignmentScreenState createState() => _TaskAssignmentScreenState();
}

class _TaskAssignmentScreenState extends State<TaskAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clientNameController = TextEditingController();
  String _natureOfEntity = 'Individual';
  String _natureOfWork = 'IT';
  DateTime _assignDate = DateTime.now();
  DateTime _deadline = DateTime.now().add(const Duration(days: 7));
  List<String> _selectedStaffIds = [];
  List<UserModel> _allStaff = [];
  bool _isLoading = false;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _exportTasksToCSV() async {
    setState(() => _isExporting = true);
    try {
      final snapshot = await FirebaseService.firestore
          .collection('tasks')
          .orderBy('assignDate', descending: true)
          .get();

      String csv =
          'Client Name,Nature of Entity,Nature of Work,Received Date,Assign Date,Deadline,Assigned Staff,Status\n';

      for (var doc in snapshot.docs) {
        final task = Task.fromMap(doc.data());
        final staffNames = await _getStaffNames(task.assignedStaffIds);

        csv +=
            '"${task.clientName}",'
            '"${task.natureOfEntity}",'
            '"${task.natureOfWork}",'
            '"${DateFormat('dd/MM/yyyy').format(task.receivedDate)}",'
            '"${DateFormat('dd/MM/yyyy').format(task.assignDate)}",'
            '"${DateFormat('dd/MM/yyyy').format(task.deadline)}",'
            '"${staffNames.join(', ')}",'
            '"${task.status}"\n';
      }

      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/tasks_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
      final file = File(path);

      await file.writeAsString(csv);

      await Share.shareXFiles(
        [XFile(path)],
        text:
            'Tasks Export - ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
        subject: 'Tasks Export',
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: ${e.toString()}')));
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<List<String>> _getStaffNames(List<String> staffIds) async {
    final names = <String>[];
    for (final id in staffIds) {
      try {
        final doc = await FirebaseService.firestore
            .collection('users')
            .doc(id)
            .get();
        if (doc.exists) {
          names.add(doc['name'] ?? 'Unknown');
        }
      } catch (e) {
        debugPrint('Error fetching staff name: $e');
      }
    }
    return names;
  }

  Future<void> _loadStaff() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseService.firestore
          .collection('users')
          .where('role', isEqualTo: 'staff')
          .get();

      setState(() {
        _allStaff = snapshot.docs
            .map((doc) => UserModel.fromMap(doc.data()))
            .toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading staff: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context, bool isAssignDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isAssignDate ? _assignDate : _deadline,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isAssignDate) {
          _assignDate = picked;
        } else {
          _deadline = picked;
        }
      });
    }
  }

  Future<void> _createTask() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    if (_selectedStaffIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one staff member'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final taskId = FirebaseService.firestore.collection('tasks').doc().id;
      final task = Task(
        id: taskId,
        clientName: _clientNameController.text.trim(),
        natureOfEntity: _natureOfEntity,
        natureOfWork: _natureOfWork,
        receivedDate: DateTime.now(),
        assignDate: _assignDate,
        deadline: _deadline,
        assignedStaffIds: _selectedStaffIds,
        status: 'Pending',
      );

      // Save to main tasks collection
      await FirebaseService.firestore
          .collection('tasks')
          .doc(taskId)
          .set(task.toMap());

      // Save to each staff member's assigned tasks
      final batch = FirebaseService.firestore.batch();
      for (final staffId in _selectedStaffIds) {
        final staffTaskRef = FirebaseService.firestore
            .collection('users')
            .doc(staffId)
            .collection('assigned_tasks')
            .doc(taskId);
        batch.set(staffTaskRef, task.toMap());
      }
      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task created successfully!')),
      );

      // Reset form
      _formKey.currentState?.reset();
      _clientNameController.clear();
      setState(() {
        _selectedStaffIds = [];
        _natureOfEntity = 'Individual';
        _natureOfWork = 'IT';
        _assignDate = DateTime.now();
        _deadline = DateTime.now().add(const Duration(days: 7));
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating task: ${e.toString()}')),
      );
      debugPrint('Error creating task: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign New Task'),
        actions: [
          IconButton(
            icon: _isExporting
                ? const CircularProgressIndicator(color: Colors.white)
                : const Icon(Icons.download),
            onPressed: _isExporting ? null : _exportTasksToCSV,
            tooltip: 'Export Tasks',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Client Name
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: TextFormField(
                          controller: _clientNameController,
                          decoration: const InputDecoration(
                            labelText: 'Client Name *',
                            border: InputBorder.none,
                          ),
                          validator: (value) => value?.isEmpty ?? true
                              ? 'Client name is required'
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Nature of Entity
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: DropdownButtonFormField<String>(
                          value: _natureOfEntity,
                          decoration: const InputDecoration(
                            labelText: 'Nature of Entity',
                            border: InputBorder.none,
                          ),
                          items: ['Individual', 'Company', 'LLP', 'Trust']
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                          onChanged: (value) => setState(() {
                            if (value != null) _natureOfEntity = value;
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Nature of Work
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: DropdownButtonFormField<String>(
                          value: _natureOfWork,
                          decoration: const InputDecoration(
                            labelText: 'Nature of Work',
                            border: InputBorder.none,
                          ),
                          items:
                              ['IT', 'ROC', 'GST', 'TDS', 'Audit', 'Accounting']
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) => setState(() {
                            if (value != null) _natureOfWork = value;
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Date Selection
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            elevation: 2,
                            child: ListTile(
                              title: const Text('Assign Date'),
                              subtitle: Text(
                                DateFormat('dd MMM yyyy').format(_assignDate),
                              ),
                              trailing: const Icon(Icons.calendar_today),
                              onTap: () => _selectDate(context, true),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Card(
                            elevation: 2,
                            child: ListTile(
                              title: const Text('Deadline'),
                              subtitle: Text(
                                DateFormat('dd MMM yyyy').format(_deadline),
                              ),
                              trailing: const Icon(Icons.calendar_today),
                              onTap: () => _selectDate(context, false),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Staff Selection
                    const Text(
                      'Assign To Staff *',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._allStaff.map(
                      (staff) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 2,
                        child: CheckboxListTile(
                          title: Text(staff.name),
                          subtitle: Text(staff.email),
                          value: _selectedStaffIds.contains(staff.uid),
                          onChanged: (selected) {
                            setState(() {
                              if (selected == true) {
                                _selectedStaffIds.add(staff.uid);
                              } else {
                                _selectedStaffIds.remove(staff.uid);
                              }
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    ElevatedButton(
                      onPressed: _createTask,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Create Task',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
