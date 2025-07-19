import 'package:flutter/material.dart';

import '../Firebasesetup.dart';

class WorkDetail {
  final String id;
  final String userId;
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String description;

  WorkDetail({
    required this.id,
    required this.userId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.description,
  });

  factory WorkDetail.fromMap(Map<String, dynamic> data) {
    return WorkDetail(
      id: data['id'] ?? '',
      userId: data['userId'] ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(data['date']),
      startTime: TimeOfDay(
        hour: data['startHour'] ?? 0,
        minute: data['startMinute'] ?? 0,
      ),
      endTime: TimeOfDay(
        hour: data['endHour'] ?? 0,
        minute: data['endMinute'] ?? 0,
      ),
      description: data['description'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'date': date.millisecondsSinceEpoch,
      'startHour': startTime.hour,
      'startMinute': startTime.minute,
      'endHour': endTime.hour,
      'endMinute': endTime.minute,
      'description': description,
    };
  }
}

class WorkDetailsScreen extends StatefulWidget {
  final String userId;
  final DateTime date;
  final WorkDetail? existingDetail;

  const WorkDetailsScreen({
    super.key,
    required this.userId,
    required this.date,
    this.existingDetail,
  });

  @override
  _WorkDetailsScreenState createState() => _WorkDetailsScreenState();
}

class _WorkDetailsScreenState extends State<WorkDetailsScreen> {
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late TextEditingController _descriptionController;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.existingDetail != null) {
      _startTime = widget.existingDetail!.startTime;
      _endTime = widget.existingDetail!.endTime;
      _descriptionController = TextEditingController(
        text: widget.existingDetail!.description,
      );
    } else {
      final now = TimeOfDay.now();
      _startTime = now;
      _endTime = now.replacing(hour: now.hour + 1);
      _descriptionController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveWorkDetails() async {
    if (_descriptionController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter a description');
      return;
    }

    if (_endTime.hour < _startTime.hour ||
        (_endTime.hour == _startTime.hour &&
            _endTime.minute <= _startTime.minute)) {
      setState(() => _errorMessage = 'End time must be after start time');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final workDetail = WorkDetail(
        id:
            widget.existingDetail?.id ??
            '${widget.userId}_${DateTime.now().millisecondsSinceEpoch}',
        userId: widget.userId,
        date: widget.date,
        startTime: _startTime,
        endTime: _endTime,
        description: _descriptionController.text,
      );

      await FirebaseService.firestore
          .collection('users')
          .doc(widget.userId)
          .collection('workDetails')
          .doc(workDetail.id)
          .set(workDetail.toMap());

      Navigator.pop(context, workDetail);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to save: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingDetail != null
              ? 'Edit Work Detail'
              : 'Add Work Detail',
        ),
        actions: [
          if (widget.existingDetail != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                try {
                  await FirebaseService.firestore
                      .collection('users')
                      .doc(widget.userId)
                      .collection('workDetails')
                      .doc(widget.existingDetail!.id)
                      .delete();
                  Navigator.pop(context, null);
                } catch (e) {
                  setState(
                    () => _errorMessage = 'Failed to delete: ${e.toString()}',
                  );
                }
              },
            ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildTimeField('Start Time', _startTime, true),
                    _buildTimeField('End Time', _endTime, false),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saveWorkDetails,
                      child: const Text('SAVE'),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildTimeField(String label, TimeOfDay time, bool isStartTime) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _selectTime(context, isStartTime),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(time.format(context)),
                const Icon(Icons.access_time),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStartTime ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }
}
