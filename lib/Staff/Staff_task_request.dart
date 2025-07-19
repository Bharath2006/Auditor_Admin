import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../models.dart';

class TaskRequestScreen extends StatefulWidget {
  const TaskRequestScreen({Key? key}) : super(key: key);

  @override
  _TaskRequestScreenState createState() => _TaskRequestScreenState();
}

class _TaskRequestScreenState extends State<TaskRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _clientNameController = TextEditingController();
  DateTime? _deadline;
  DateTime? _assignDate;
  bool _isLoading = false;

  final List<String> _entityOptions = ['Individual', 'Company', 'LLP'];
  final List<String> _workOptions = ['IT', 'ROC', 'Profit & Loss', 'GST'];

  String _selectedStatus = 'Pending';
  String? _selectedEntity;
  String? _selectedWork;

  Future<void> _submitTaskRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_deadline == null) {
      Fluttertoast.showToast(msg: 'Please select a deadline');
      return;
    }
    if (_assignDate == null) {
      Fluttertoast.showToast(msg: 'Please select an assign date');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final taskId = FirebaseFirestore.instance.collection('tasks').doc().id;

      final task = Task(
        id: taskId,
        clientName: _clientNameController.text,
        natureOfEntity: _selectedEntity!,
        natureOfWork: _selectedWork!,
        assignDate: _assignDate!,
        deadline: _deadline!,
        assignedStaffIds: [userId],
        status: _selectedStatus,
        receivedDate: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(taskId)
          .set(task.toMap());
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('task_history')
          .doc(taskId)
          .set(task.toMap());

      Fluttertoast.showToast(msg: '🎉 Task request submitted successfully');

      _clientNameController.clear();
      setState(() {
        _deadline = null;
        _assignDate = null;
        _selectedEntity = null;
        _selectedWork = null;
        _selectedStatus = 'Pending';
      });
    } catch (e) {
      Fluttertoast.showToast(msg: '❌ Error submitting task: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context, bool isAssignDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isAssignDate
          ? (_assignDate ?? DateTime.now())
          : (_deadline ?? DateTime.now().add(const Duration(days: 1))),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text('📝 Task Management'),
          centerTitle: true,
          elevation: 4,
          shadowColor: Colors.grey[400],
          bottom: const TabBar(
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            indicatorColor: Colors.deepPurple,
            indicatorWeight: 3,
            tabs: [
              Tab(text: '➕ New Request'),
              Tab(text: '📜 My History'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildResponsive(
                          _buildTextField(_clientNameController, 'Client Name'),
                          constraints,
                        ),
                        const SizedBox(height: 16),
                        _buildResponsive(
                          _buildDropdownField(
                            label: 'Nature of Entity',
                            value: _selectedEntity,
                            options: _entityOptions,
                            onChanged: (value) =>
                                setState(() => _selectedEntity = value),
                          ),
                          constraints,
                        ),
                        const SizedBox(height: 16),
                        _buildResponsive(
                          _buildDropdownField(
                            label: 'Nature of Work',
                            value: _selectedWork,
                            options: _workOptions,
                            onChanged: (value) =>
                                setState(() => _selectedWork = value),
                          ),
                          constraints,
                        ),
                        const SizedBox(height: 16),
                        // Enhanced Date Selection UI
                        _buildResponsive(
                          _buildDateSelectionCard(
                            context,
                            '📅 Assign Date',
                            _assignDate,
                            () => _selectDate(context, true),
                          ),
                          constraints,
                        ),
                        const SizedBox(height: 16),
                        _buildResponsive(
                          _buildDateSelectionCard(
                            context,
                            '⏰ Deadline',
                            _deadline,
                            () => _selectDate(context, false),
                          ),
                          constraints,
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: SizedBox(
                            width: constraints.maxWidth * 0.95,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _submitTaskRequest,
                              icon: const Icon(Icons.send),
                              label: _isLoading
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Submit Task Request',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 6,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            _buildTaskHistory(),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelectionCard(
    BuildContext context,
    String title,
    DateTime? date,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.calendar_today,
                    size: 20,
                    color: Colors.deepPurple[300],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_available,
                      color: Colors.deepPurple[400],
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      date != null
                          ? DateFormat('EEE, MMM d, y').format(date)
                          : 'Select a date',
                      style: TextStyle(
                        fontSize: 15,
                        color: date != null ? Colors.black : Colors.grey[600],
                        fontWeight: date != null
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              if (date != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Selected: ${DateFormat('MMMM d, y').format(date)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResponsive(Widget child, BoxConstraints constraints) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.95),
      child: child,
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (value) =>
          value == null || value.isEmpty ? 'Please enter $label' : null,
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.white,
      ),
      items: options
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: onChanged,
      validator: (value) =>
          value == null || value.isEmpty ? 'Please select $label' : null,
    );
  }

  Widget _buildTaskHistory() {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('task_history')
          .orderBy('assignDate', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No task history found.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final task = Task.fromMap(
              snapshot.data!.docs[index].data() as Map<String, dynamic>,
            );
            return LayoutBuilder(
              builder: (context, constraints) {
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * 0.98,
                  ),
                  child: _buildTaskCard(task),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTaskCard(Task task) {
    return Card(
      elevation: 6,
      shadowColor: Colors.grey[300],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.clientName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(
                  label: Text(task.status),
                  backgroundColor: _getStatusColor(task.status),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _taskDetailRow(Icons.business, 'Entity: ${task.natureOfEntity}'),
            _taskDetailRow(Icons.work_outline, 'Work: ${task.natureOfWork}'),
            _taskDetailRow(
              Icons.calendar_today,
              'Received: ${DateFormat('dd/MM/yyyy').format(task.receivedDate)}',
            ),
            _taskDetailRow(
              Icons.event_available,
              'Assigned: ${DateFormat('dd/MM/yyyy').format(task.assignDate)}',
            ),
            _taskDetailRow(
              Icons.event,
              'Deadline: ${DateFormat('dd/MM/yyyy').format(task.deadline)}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _taskDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Complete':
        return Colors.green[100]!;
      case 'In Progress':
        return Colors.blue[100]!;
      default:
        return Colors.orange[100]!;
    }
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    super.dispose();
  }
}
