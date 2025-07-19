import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../Firebasesetup.dart';
import '../models.dart';


class TaskEditDialog extends StatefulWidget {
  final Task task;

  const TaskEditDialog({super.key, required this.task});

  @override
  _TaskEditDialogState createState() => _TaskEditDialogState();
}

class _TaskEditDialogState extends State<TaskEditDialog> {
  final _formKey = GlobalKey<FormState>();

  late String _clientName;
  late String _natureOfWork;
  late String _natureOfEntity;
  late DateTime _deadline;
  late String _status;
  late List<String> _assignedStaffIds;

  final List<String> _entityOptions = ['Individual', 'Company', 'LLP'];
  final List<String> _workOptions = ['IT', 'ROC', 'Profit & Loss', 'GST'];
  final List<String> _statusOptions = [
    'Pending',
    'Complete',
    'Request_Pending',
    'Approved',
  ];

  List<UserModel> _allStaff = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _clientName = widget.task.clientName;
    _natureOfWork = widget.task.natureOfWork;
    _natureOfEntity = widget.task.natureOfEntity;
    _deadline = widget.task.deadline;
    _status = widget.task.status;
    _assignedStaffIds = List.from(widget.task.assignedStaffIds);
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    try {
      final snapshot =
          await FirebaseService.firestore
              .collection('users')
              .where('role', isEqualTo: 'staff')
              .get();

      setState(() {
        _allStaff =
            snapshot.docs.map((doc) => UserModel.fromMap(doc.data())).toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load staff: $e')));
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    if (_assignedStaffIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please assign at least one staff.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final taskData = {
        'clientName': _clientName,
        'natureOfWork': _natureOfWork,
        'natureOfEntity': _natureOfEntity,
        'deadline': _deadline.millisecondsSinceEpoch,
        'status': _status,
        'assignedStaffIds': _assignedStaffIds,
      };

      final taskRef = FirebaseService.firestore
          .collection('tasks')
          .doc(widget.task.id);

      await taskRef.update(taskData);

      for (final staffId in _assignedStaffIds) {
        await FirebaseService.firestore
            .collection('users')
            .doc(staffId)
            .collection('assigned_tasks')
            .doc(widget.task.id)
            .set(taskData);
      }

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving changes: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      helpText: 'Select Deadline',
    );

    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child:
            _isLoading
                ? const SizedBox(
                  height: 300,
                  child: Center(child: CircularProgressIndicator()),
                )
                : SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Edit Task',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),

                        _buildTextField(
                          label: 'Client Name',
                          icon: Icons.person,
                          initialValue: _clientName,
                          onChanged: (val) => _clientName = val,
                        ),

                        const SizedBox(height: 16),
                        _buildDropdown(
                          label: 'Nature of Work',
                          icon: Icons.work,
                          value: _natureOfWork,
                          items: _workOptions,
                          onChanged: (val) => _natureOfWork = val!,
                        ),

                        const SizedBox(height: 16),
                        _buildDropdown(
                          label: 'Nature of Entity',
                          icon: Icons.apartment,
                          value: _natureOfEntity,
                          items: _entityOptions,
                          onChanged: (val) => _natureOfEntity = val!,
                        ),

                        const SizedBox(height: 16),
                        _buildDateField(context),

                        const SizedBox(height: 16),
                        _buildDropdown(
                          label: 'Status',
                          icon: Icons.flag_outlined,
                          value: _status,
                          items: _statusOptions,
                          onChanged: (val) => _status = val!,
                        ),

                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Assign Staff',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._allStaff.map((staff) {
                          return CheckboxListTile(
                            value: _assignedStaffIds.contains(staff.uid),
                            title: Text(staff.name),
                            onChanged: (bool? checked) {
                              setState(() {
                                if (checked == true) {
                                  _assignedStaffIds.add(staff.uid);
                                } else {
                                  _assignedStaffIds.remove(staff.uid);
                                }
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          );
                        }),

                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.cancel_outlined),
                              onPressed: () => Navigator.pop(context),
                              label: const Text('Cancel'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _isLoading ? null : _saveChanges,
                              icon: const Icon(Icons.save),
                              label: const Text('Save'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                backgroundColor:
                                    Theme.of(context).colorScheme.primary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    required String initialValue,
    required Function(String) onChanged,
  }) {
    return TextFormField(
      initialValue: initialValue,
      onChanged: onChanged,
      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : null,
      onChanged: onChanged,
      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items:
          items
              .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
              .toList(),
    );
  }

  Widget _buildDateField(BuildContext context) {
    return InkWell(
      onTap: _pickDeadline,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Deadline',
          prefixIcon: const Icon(Icons.calendar_today),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(DateFormat('dd MMM yyyy').format(_deadline)),
            const Icon(Icons.edit_calendar, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
