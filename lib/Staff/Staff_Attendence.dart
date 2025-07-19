import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:table_calendar/table_calendar.dart';
import '../Firebasesetup.dart';
import 'Staff_Work_Details.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final String _currentUserId = FirebaseService.auth.currentUser!.uid;
  bool _isClockedIn = false;
  bool _isLoading = false;
  DateTime? _lastClockInTime;
  String? _errorMessage;
  AttendanceRecord? _todayRecord;
  Duration? _currentDuration;
  Timer? _timer;
  WorkDetail? _todayWorkDetail;
  bool _isLoadingWorkDetails = false;
  List<WorkDetail> _todayWorkDetails = [];
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<AttendanceRecord>> _attendanceEvents = {};
  List<AttendanceRecord> _allRecords = [];
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _checkCurrentStatus();
    _loadAttendanceHistory();
    _loadTodayWorkDetails();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _exportAttendanceData() async {
    setState(() => _isExporting = true);
    try {
      // Create CSV header
      String csv =
          'Date,Day,Clock In,Clock Out,Duration,Status,Type,Work Details\n';

      // Sort records by date (newest first)
      _allRecords.sort((a, b) => b.date.compareTo(a.date));

      // Add each record as a row
      for (var record in _allRecords) {
        // Get work details for this day
        final workDetails = await _getWorkDetailsForDay(record.date);
        final workDetailsText = workDetails
            .map(
              (detail) =>
                  '${detail.startTime.format(context)}-${detail.endTime.format(context)}: ${detail.description}',
            )
            .join('; ');

        final dayName = DateFormat('EEEE').format(record.date);
        final clockInTime =
            record.clockIn != null
                ? DateFormat('h:mm a').format(record.clockIn!)
                : 'N/A';
        final clockOutTime =
            record.clockOut != null
                ? DateFormat('h:mm a').format(record.clockOut!)
                : 'N/A';
        final duration =
            (record.clockIn != null && record.clockOut != null)
                ? _formatDuration(record.clockOut!.difference(record.clockIn!))
                : 'N/A';

        csv +=
            '"${DateFormat('yyyy-MM-dd').format(record.date)}",'
            '"$dayName",'
            '"$clockInTime",'
            '"$clockOutTime",'
            '"$duration",'
            '"${record.status}",'
            '"${record.type}",'
            '"$workDetailsText"\n';
      }

      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/attendance_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File(path);

      // Write the file
      await file.writeAsString(csv);

      // Share the file
      await Share.shareXFiles(
        [XFile(path)],
        text: 'Attendance Records Export',
        subject: 'Exported Attendance Data',
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: ${e.toString()}')));
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _loadAttendanceHistory() async {
    setState(() => _isLoading = true);
    try {
      final snapshot =
          await FirebaseService.firestore
              .collection('users')
              .doc(_currentUserId)
              .collection('attendance')
              .orderBy('date', descending: true)
              .get();

      final Map<DateTime, List<AttendanceRecord>> tempEvents = {};
      final List<AttendanceRecord> tempRecords = [];

      for (var doc in snapshot.docs) {
        final record = AttendanceRecord.fromMap(doc.data());
        final date = DateTime(
          record.date.year,
          record.date.month,
          record.date.day,
        );

        tempRecords.add(record);

        if (tempEvents[date] == null) {
          tempEvents[date] = [];
        }
        tempEvents[date]!.add(record);
      }

      setState(() {
        _attendanceEvents = tempEvents;
        _allRecords = tempRecords;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load attendance history';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTodayWorkDetails() async {
    setState(() => _isLoadingWorkDetails = true);
    try {
      final today = DateTime.now();
      final snapshot =
          await FirebaseService.firestore
              .collection('users')
              .doc(_currentUserId)
              .collection('workDetails')
              .where(
                'date',
                isGreaterThanOrEqualTo:
                    DateTime(
                      today.year,
                      today.month,
                      today.day,
                    ).millisecondsSinceEpoch,
              )
              .where(
                'date',
                isLessThan:
                    DateTime(
                      today.year,
                      today.month,
                      today.day + 1,
                    ).millisecondsSinceEpoch,
              )
              .orderBy('date')
              .get();

      setState(() {
        _todayWorkDetails =
            snapshot.docs.map((doc) => WorkDetail.fromMap(doc.data())).toList();
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load work details';
      });
    } finally {
      setState(() => _isLoadingWorkDetails = false);
    }
  }

  Future<void> _navigateToWorkDetailsScreen() async {
    final result = await Navigator.push<WorkDetail?>(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
                WorkDetailsScreen(userId: _currentUserId, date: DateTime.now()),
      ),
    );
    if (result != null) {
      await _loadTodayWorkDetails();
    }
  }

  List<AttendanceRecord> _getEventsForDay(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    return _attendanceEvents[date] ?? [];
  }

  AttendanceStatus _getStatusForDay(DateTime day) {
    final events = _getEventsForDay(day);
    if (events.isEmpty) {
      return day.isAfter(DateTime.now())
          ? AttendanceStatus.future
          : AttendanceStatus.absent;
    }

    final hasLeave = events.any((record) => record.type == 'Leave');
    if (hasLeave) return AttendanceStatus.leave;

    // Check for pending records first
    final hasPending = events.any((record) => record.status == 'pending');
    if (hasPending) return AttendanceStatus.pending;

    final hasCompleteRecord = events.any(
      (record) => record.clockIn != null && record.clockOut != null,
    );
    final hasPartialRecord = events.any(
      (record) => record.clockIn != null && record.clockOut == null,
    );

    if (hasCompleteRecord) return AttendanceStatus.present;
    if (hasPartialRecord) return AttendanceStatus.partial;
    return AttendanceStatus.absent;
  }

  Future<void> _checkCurrentStatus() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final snapshot =
          await FirebaseService.firestore
              .collection('users')
              .doc(_currentUserId)
              .collection('attendance')
              .where('date', isEqualTo: today.millisecondsSinceEpoch)
              .limit(1)
              .get();

      if (snapshot.docs.isNotEmpty) {
        _todayRecord = AttendanceRecord.fromMap(snapshot.docs.first.data());

        if (_todayRecord!.type == 'Leave') {
          setState(() {
            _isClockedIn = false;
            _lastClockInTime = null;
            _timer?.cancel();
            _currentDuration = null;
          });
          return;
        }

        if (_todayRecord!.clockIn != null && _todayRecord!.clockOut != null) {
          setState(() {
            _isClockedIn = false;
            _lastClockInTime = _todayRecord!.clockIn;
            _timer?.cancel();
            _currentDuration = _todayRecord!.clockOut!.difference(
              _todayRecord!.clockIn!,
            );
          });
          return;
        }

        if (_todayRecord!.clockIn != null) {
          setState(() {
            _isClockedIn = true;
            _lastClockInTime = _todayRecord!.clockIn;
            _startTimer();
          });
          return;
        }
      } else {
        setState(() {
          _isClockedIn = false;
          _lastClockInTime = null;
          _todayRecord = null;
          _timer?.cancel();
          _currentDuration = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error checking attendance status';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (_todayRecord?.clockIn != null) {
      final now = DateTime.now();
      final initialDuration = now.difference(_todayRecord!.clockIn!);
      _currentDuration = initialDuration;

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!_isClockedIn) {
          timer.cancel();
          return;
        }
        setState(() {
          _currentDuration = Duration(seconds: _currentDuration!.inSeconds + 1);
        });
      });
    }
  }

  Future<void> _clockIn() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final todayEvents = _getEventsForDay(today);
    if (todayEvents.any((record) => record.type == 'Leave')) {
      setState(() {
        _errorMessage = 'Today is a leave day - cannot clock in';
      });
      return;
    }

    if (todayEvents.any(
      (record) => record.clockIn != null && record.clockOut != null,
    )) {
      setState(() {
        _errorMessage = 'Attendance already completed for today';
      });
      return;
    }

    if (todayEvents.any(
      (record) => record.clockIn != null && record.clockOut == null,
    )) {
      setState(() {
        _errorMessage = 'You are already clocked in for today';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final recordId = '${_currentUserId}_${now.millisecondsSinceEpoch}';

      // Save to user's attendance collection as pending
      await FirebaseService.firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('attendance')
          .doc(recordId)
          .set({
            'id': recordId,
            'userId': _currentUserId,
            'date': today.millisecondsSinceEpoch,
            'clockIn': now.millisecondsSinceEpoch,
            'clockOut': null,
            'type': 'Pending',
            'status': 'pending',
            'timestamp': FieldValue.serverTimestamp(),
          });

      await FirebaseService.firestore
          .collection('admin_attendance_approval')
          .doc(recordId)
          .set({
            'id': recordId,
            'userId': _currentUserId,
            'userName':
                FirebaseService.auth.currentUser!.displayName ?? 'Unknown',
            'date': today.millisecondsSinceEpoch,
            'clockIn': now.millisecondsSinceEpoch,
            'clockOut': null,
            'type': 'Pending',
            'status': 'pending',
            'timestamp': FieldValue.serverTimestamp(),
          });

      final newRecord = AttendanceRecord(
        id: recordId,
        userId: _currentUserId,
        date: today,
        clockIn: now,
        clockOut: null,
        type: 'Pending', // Changed from 'Present' to 'Pending'
      );

      setState(() {
        _isClockedIn = true;
        _lastClockInTime = now;
        _todayRecord = newRecord;
        _attendanceEvents[today] = [newRecord];
        _allRecords.insert(0, newRecord);
        _startTimer();
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to clock in: ${e.toString()}';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clockOut() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final todayEvents = _getEventsForDay(today);
    if (todayEvents.any((record) => record.type == 'Leave')) {
      setState(() {
        _errorMessage = 'Today is a leave day - cannot clock out';
      });
      return;
    }

    if (todayEvents.any(
      (record) => record.clockIn != null && record.clockOut != null,
    )) {
      setState(() {
        _errorMessage = 'Attendance already completed for today';
      });
      return;
    }

    final incompleteRecord = todayEvents.firstWhere(
      (record) => record.clockIn != null && record.clockOut == null,
      orElse:
          () => AttendanceRecord(
            id: '',
            userId: '',
            date: today,
            type: 'Pending',
          ),
    );

    if (incompleteRecord.id.isEmpty) {
      setState(() {
        _errorMessage = 'No active clock-in found for today';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Update user's attendance record
      await FirebaseService.firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('attendance')
          .doc(incompleteRecord.id)
          .update({
            'clockOut': now.millisecondsSinceEpoch,
            'status': 'pending', // Ensure status remains pending
          });

      // Update admin approval record
      await FirebaseService.firestore
          .collection('admin_attendance_approval')
          .doc(incompleteRecord.id)
          .update({
            'clockOut': now.millisecondsSinceEpoch,
            'status': 'pending',
          });

      final updatedRecord = AttendanceRecord(
        id: incompleteRecord.id,
        userId: incompleteRecord.userId,
        date: incompleteRecord.date,
        clockIn: incompleteRecord.clockIn,
        clockOut: now,
        type: 'Pending', // Changed from 'Present' to 'Pending'
      );

      setState(() {
        _isClockedIn = false;
        _todayRecord = updatedRecord;
        _currentDuration = now.difference(incompleteRecord.clockIn!);

        final index = _allRecords.indexWhere(
          (r) => r.id == incompleteRecord.id,
        );
        if (index != -1) {
          _allRecords[index] = updatedRecord;
        }

        if (_attendanceEvents[today] != null) {
          final dayIndex = _attendanceEvents[today]!.indexWhere(
            (r) => r.id == incompleteRecord.id,
          );
          if (dayIndex != -1) {
            _attendanceEvents[today]![dayIndex] = updatedRecord;
          }
        }

        _timer?.cancel();
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to clock out: ${e.toString()}';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildDurationCounter() {
    if (_currentDuration == null || !_isClockedIn) return const SizedBox();

    final hours = _currentDuration!.inHours;
    final minutes = _currentDuration!.inMinutes.remainder(60);
    final seconds = _currentDuration!.inSeconds.remainder(60);

    return Column(
      children: [
        const SizedBox(height: 16),
        Text(
          'Time Elapsed:',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
        Text(
          '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildWorkDetailsSummary() {
    if (_todayWorkDetails.isEmpty) return const SizedBox();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Today\'s Work Details:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ..._todayWorkDetails
                .map(
                  (detail) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              '${detail.startTime.format(context)} - ${detail.endTime.format(context)}',
                            ),
                          ],
                        ),
                        if (detail.description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 24.0, top: 4),
                            child: Text(detail.description),
                          ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: TableCalendar<AttendanceStatus>(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          onFormatChanged: (format) {
            setState(() {
              _calendarFormat = format;
            });
          },
          onPageChanged: (focusedDay) {
            setState(() {
              _focusedDay = focusedDay;
            });
          },
          eventLoader: (day) {
            final status = _getStatusForDay(day);
            return [status];
          },
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            selectedDecoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            markerSize: 0,
          ),
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (context, day, focusedDay) {
              final status = _getStatusForDay(day);
              Color dayColor;
              Color textColor = Colors.black;
              String? statusText;

              switch (status) {
                case AttendanceStatus.present:
                  dayColor = Colors.green[100]!;
                  break;
                case AttendanceStatus.partial:
                  dayColor = Colors.orange[100]!;
                  statusText = 'Partial';
                  break;
                case AttendanceStatus.absent:
                  dayColor =
                      day.isBefore(DateTime.now())
                          ? Colors.red[100]!
                          : Colors.grey[200]!;
                  statusText = day.isBefore(DateTime.now()) ? 'Absent' : null;
                  break;
                case AttendanceStatus.leave:
                  dayColor = Colors.purple[100]!;
                  statusText = 'Leave';
                  break;
                case AttendanceStatus.pending:
                  dayColor = Colors.yellow[100]!;
                  statusText = 'Pending';
                  break;
                case AttendanceStatus.future:
                  dayColor = Colors.grey[200]!;
                  break;
              }

              if (isSameDay(day, DateTime.now())) {
                textColor = Colors.white;
              }

              return Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: dayColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        day.day.toString(),
                        style: TextStyle(color: textColor),
                      ),
                      if (statusText != null)
                        Text(
                          statusText,
                          style: TextStyle(color: textColor, fontSize: 8),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceHistory() {
    if (_allRecords.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'No attendance records found',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _allRecords.length,
      itemBuilder: (context, index) {
        final record = _allRecords[index];
        final isToday = isSameDay(record.date, DateTime.now());

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: isToday ? Colors.blue[50] : null,
          child: ListTile(
            onTap: () => _showDayDetails(record.date),
            title: Text(DateFormat('EEEE, MMMM d, y').format(record.date)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (record.type == 'Leave') ...[
                  const Text(
                    'Leave (Approved)',
                    style: TextStyle(color: Colors.purple),
                  ),
                ] else ...[
                  if (record.clockIn != null)
                    Text(
                      'Clock In: ${DateFormat('h:mm a').format(record.clockIn!)}',
                    ),
                  if (record.clockOut != null)
                    Text(
                      'Clock Out: ${DateFormat('h:mm a').format(record.clockOut!)}',
                    ),
                  if (record.clockIn != null && record.clockOut != null)
                    Text(
                      'Duration: ${_formatDuration(record.clockOut!.difference(record.clockIn!))}',
                    ),
                  if (record.clockIn != null && record.clockOut == null)
                    const Text(
                      'Status: Clocked in but not out',
                      style: TextStyle(color: Colors.orange),
                    ),
                ],
              ],
            ),
            trailing:
                record.clockOut == null
                    ? const Icon(Icons.warning, color: Colors.orange)
                    : null,
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }

  Future<void> _showDayDetails(DateTime date) async {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(DateFormat('EEEE, MMMM d, y').format(date)),
            content: FutureBuilder<List<WorkDetail>>(
              future: _getWorkDetailsForDay(date),
              builder: (context, snapshot) {
                final workDetails = snapshot.data ?? [];
                final totalDuration = _calculateTotalWorkDuration(workDetails);

                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ... existing attendance records display ...
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Work Details:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (totalDuration.inMinutes > 0)
                            Text(
                              'Total: ${totalDuration.inHours}h ${totalDuration.inMinutes.remainder(60)}m',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const Center(child: CircularProgressIndicator())
                      else if (workDetails.isEmpty)
                        const Text('No work details for this day')
                      else
                        ...workDetails
                            .map(
                              (detail) => Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(
                                    '${detail.startTime.format(context)} - ${detail.endTime.format(context)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle:
                                      detail.description.isNotEmpty
                                          ? Text(detail.description)
                                          : null,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 20),
                                        onPressed: () async {
                                          Navigator.pop(context);
                                          final result =
                                              await Navigator.push<WorkDetail?>(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (
                                                        context,
                                                      ) => WorkDetailsScreen(
                                                        userId: _currentUserId,
                                                        date: date,
                                                        existingDetail: detail,
                                                      ),
                                                ),
                                              );
                                          if (result != null) {
                                            await _loadTodayWorkDetails();
                                          }
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          size: 20,
                                          color: Colors.red,
                                        ),
                                        onPressed: () async {
                                          final confirm = await showDialog<
                                            bool
                                          >(
                                            context: context,
                                            builder:
                                                (context) => AlertDialog(
                                                  title: const Text(
                                                    'Delete Work Detail',
                                                  ),
                                                  content: const Text(
                                                    'Are you sure you want to delete this work detail?',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed:
                                                          () => Navigator.pop(
                                                            context,
                                                            false,
                                                          ),
                                                      child: const Text(
                                                        'CANCEL',
                                                      ),
                                                    ),
                                                    TextButton(
                                                      onPressed:
                                                          () => Navigator.pop(
                                                            context,
                                                            true,
                                                          ),
                                                      child: const Text(
                                                        'DELETE',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                          );
                                          if (confirm == true) {
                                            await FirebaseService.firestore
                                                .collection('users')
                                                .doc(_currentUserId)
                                                .collection('workDetails')
                                                .doc(detail.id)
                                                .delete();
                                            await _loadTodayWorkDetails();
                                            if (mounted) Navigator.pop(context);
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                    ],
                  ),
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CLOSE'),
              ),
              if (_isClockedIn && isSameDay(date, DateTime.now()))
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    final result = await Navigator.push<WorkDetail?>(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => WorkDetailsScreen(
                              userId: _currentUserId,
                              date: date,
                            ),
                      ),
                    );
                    if (result != null) {
                      await _loadTodayWorkDetails();
                    }
                  },
                  child: const Text('ADD NEW'),
                ),
            ],
          ),
    );
  }

  Duration _calculateTotalWorkDuration(List<WorkDetail> workDetails) {
    Duration total = Duration.zero;
    for (final detail in workDetails) {
      final start = DateTime(
        2023,
        1,
        1,
        detail.startTime.hour,
        detail.startTime.minute,
      );
      final end = DateTime(
        2023,
        1,
        1,
        detail.endTime.hour,
        detail.endTime.minute,
      );
      total += end.difference(start);
    }
    return total;
  }

  Future<List<WorkDetail>> _getWorkDetailsForDay(DateTime date) async {
    try {
      final dateKey = DateTime(date.year, date.month, date.day);
      final snapshot =
          await FirebaseService.firestore
              .collection('users')
              .doc(_currentUserId)
              .collection('workDetails')
              .where(
                'date',
                isGreaterThanOrEqualTo: dateKey.millisecondsSinceEpoch,
              )
              .where(
                'date',
                isLessThan:
                    dateKey.add(const Duration(days: 1)).millisecondsSinceEpoch,
              )
              .orderBy('date')
              .get();

      return snapshot.docs
          .map((doc) => WorkDetail.fromMap(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching work details: $e');
      return [];
    }
  }

  Widget _buildStatusCard() {
    final today = DateTime.now();
    final todayEvents = _getEventsForDay(today);
    final isLeaveDay = todayEvents.any((record) => record.type == 'Leave');
    final isCompleted = todayEvents.any(
      (record) => record.clockIn != null && record.clockOut != null,
    );
    final isPartial = todayEvents.any(
      (record) => record.clockIn != null && record.clockOut == null,
    );

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          children: [
            if (isLeaveDay) ...[
              const Icon(Icons.beach_access, color: Colors.purple, size: 40),
              const SizedBox(height: 10),
              const Text(
                "ON LEAVE TODAY",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
            ] else if (isCompleted) ...[
              const Icon(Icons.check_circle, color: Colors.green, size: 40),
              const SizedBox(height: 10),
              const Text(
                "ATTENDANCE COMPLETED",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 10),
              if (_todayRecord != null)
                Column(
                  children: [
                    Text(
                      "Clock In: ${DateFormat('h:mm a').format(_todayRecord!.clockIn!)}",
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    Text(
                      "Clock Out: ${DateFormat('h:mm a').format(_todayRecord!.clockOut!)}",
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    Text(
                      "Duration: ${_formatDuration(_todayRecord!.clockOut!.difference(_todayRecord!.clockIn!))}",
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
            ] else if (isPartial) ...[
              const Icon(Icons.access_time, color: Colors.orange, size: 40),
              const SizedBox(height: 10),
              const Text(
                "CLOCKED IN - PENDING CLOCK OUT",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 10),
              if (_lastClockInTime != null)
                Text(
                  "Since: ${DateFormat('h:mm a').format(_lastClockInTime!)}",
                  style: TextStyle(color: Colors.grey[700]),
                ),
              _buildDurationCounter(),
            ] else ...[
              const Icon(Icons.lock_clock, color: Colors.grey, size: 40),
              const SizedBox(height: 10),
              const Text(
                "NOT CLOCKED IN TODAY",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Add work details button when clocked in
            if (_isClockedIn && !isLeaveDay)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: ElevatedButton.icon(
                  onPressed: _navigateToWorkDetailsScreen,
                  icon: const Icon(Icons.work),
                  label: const Text('ADD WORK DETAILS'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),

            if (_todayWorkDetail != null) _buildWorkDetailsSummary(),

            if (!isLeaveDay && !isCompleted)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (!isPartial)
                    ElevatedButton.icon(
                      onPressed: _clockIn,
                      icon: const Icon(Icons.login),
                      label: const Text('CLOCK IN'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  if (isPartial)
                    ElevatedButton.icon(
                      onPressed: _clockOut,
                      icon: const Icon(Icons.logout),
                      label: const Text('CLOCK OUT'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ElevatedButton.icon(
                    onPressed: () {
                      _checkCurrentStatus();
                      _loadAttendanceHistory();
                      _loadTodayWorkDetails();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('REFRESH'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),

            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Colors.deepPurple;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Staffs Work Reports"),
        backgroundColor: themeColor,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        actions: [
          IconButton(
            icon:
                _isExporting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Icon(Icons.download),
            onPressed: _isExporting ? null : _exportAttendanceData,
            tooltip: 'Export Attendance Data',
          ),
        ],
      ),
      body:
          _isLoading || _isLoadingWorkDetails
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: () async {
                  await _checkCurrentStatus();
                  await _loadAttendanceHistory();
                  await _loadTodayWorkDetails();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildStatusCard(),
                      const SizedBox(height: 16),
                      _buildCalendar(),
                      const SizedBox(height: 16),
                      const Text(
                        'Attendance History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildAttendanceHistory(),
                      const SizedBox(height: 20),
                      const Divider(thickness: 1.5),
                      const SizedBox(height: 10),
                      const Text(
                        'Legend',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          _buildLegendItem(Colors.green[100]!, 'Present'),
                          _buildLegendItem(Colors.purple[100]!, 'Leave'),
                          _buildLegendItem(Colors.red[100]!, 'Absent'),
                          _buildLegendItem(
                            Colors.yellow[100]!,
                            'Pending',
                          ), // Added pending
                          _buildLegendItem(Colors.grey[200]!, 'Future'),
                        ],
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.black12),
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}

enum AttendanceStatus { present, partial, absent, leave, future, pending }

class AttendanceRecord {
  final String id;
  final String userId;
  final DateTime date;
  final DateTime? clockIn;
  final DateTime? clockOut;
  final String type;
  final String status;

  AttendanceRecord({
    required this.id,
    required this.userId,
    required this.date,
    this.clockIn,
    this.clockOut,
    this.type = 'Pending',
    this.status = 'pending',
  });

  factory AttendanceRecord.fromMap(Map<String, dynamic> data) {
    return AttendanceRecord(
      id: data['id'] ?? '',
      userId: data['userId'] ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(data['date']),
      clockIn:
          data['clockIn'] != null
              ? DateTime.fromMillisecondsSinceEpoch(data['clockIn'])
              : null,
      clockOut:
          data['clockOut'] != null
              ? DateTime.fromMillisecondsSinceEpoch(data['clockOut'])
              : null,
      type: data['type'] ?? 'Pending',
      status: data['status'] ?? 'pending', // Added status
    );
  }
}
