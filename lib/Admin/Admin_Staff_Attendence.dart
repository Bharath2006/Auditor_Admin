import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../Firebasesetup.dart';
import '../models.dart';
import 'Admin_Attendence_Approval.dart';
import 'Admin_Attendence_Details.dart';

class StaffAttendanceScreen extends StatefulWidget {
  const StaffAttendanceScreen({super.key});

  @override
  State<StaffAttendanceScreen> createState() => _StaffAttendanceScreenState();
}

class _StaffAttendanceScreenState extends State<StaffAttendanceScreen> {
  bool _isExporting = false;

  Future<void> _exportAttendanceData() async {
    setState(() => _isExporting = true);
    try {
      final staffSnapshot = await FirebaseService.firestore
          .collection('users')
          .where('role', isEqualTo: 'staff')
          .get();

      String csv =
          'Staff Name,Email,Total Attendance Days,Last Attendance Date,Status\n';

      for (var staffDoc in staffSnapshot.docs) {
        final staff = UserModel.fromMap(staffDoc.data());

        final attendanceSnapshot = await FirebaseService.firestore
            .collection('users')
            .doc(staff.uid)
            .collection('attendance')
            .orderBy('date', descending: true)
            .get();

        final totalDays = attendanceSnapshot.docs.length;
        final lastAttendance = attendanceSnapshot.docs.isNotEmpty
            ? DateFormat('dd/MM/yyyy').format(
                DateTime.fromMillisecondsSinceEpoch(
                  attendanceSnapshot.docs.first['date'],
                ),
              )
            : 'No records';

        String status = 'No records';
        if (attendanceSnapshot.docs.isNotEmpty) {
          final lastRecord = attendanceSnapshot.docs.first.data();
          status = lastRecord['type'] == 'Leave'
              ? 'On Leave'
              : (lastRecord['clockIn'] != null ? 'Present' : 'Absent');
        }

        csv +=
            '"${staff.name}","'
            '${staff.email}","'
            '$totalDays","'
            '$lastAttendance","'
            '$status"\n';
      }

      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/staff_attendance_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File(path);

      await file.writeAsString(csv);

      await Share.shareXFiles(
        [XFile(path)],
        text: 'Staff Attendance Export',
        subject: 'Exported Staff Attendance Data',
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
        title: const Text('Work Reports'),
        backgroundColor: Colors.deepPurpleAccent,
        elevation: 0,
        actions: [
          IconButton(
            icon: _isExporting
                ? const CircularProgressIndicator(color: Colors.white)
                : const Icon(Icons.download),
            onPressed: _isExporting ? null : _exportAttendanceData,
            tooltip: 'Export Attendance Data',
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF3F4F6),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseService.firestore
            .collection('users')
            .where('role', isEqualTo: 'staff')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading staff: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data?.docs.isEmpty == true) {
            return const Center(child: Text('No staff members found'));
          }

          List<UserModel> staffList = [];

          try {
            staffList = snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>?;

              if (data == null) {
                throw Exception('Staff data is null');
              }

              return UserModel.fromMap(data);
            }).toList();
          } catch (e) {
            return Center(
              child: Text(
                'Error parsing staff data: $e',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: staffList.length,
            itemBuilder: (context, index) {
              final staff = staffList[index];

              if (staff.name.isEmpty || staff.email.isEmpty) {
                return const SizedBox.shrink();
              }

              final colorVariants = [
                Colors.purple,
                Colors.teal,
                Colors.orange,
                Colors.blue,
              ];
              final patternColor = colorVariants[index % colorVariants.length];

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      patternColor.withOpacity(0.9),
                      patternColor.withOpacity(0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: patternColor.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 20,
                  ),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white,
                    child: Text(
                      staff.name.isNotEmpty ? staff.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 20,
                        color: patternColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    staff.name,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    staff.email,
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                  ),
                  onTap: () {
                    try {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              StaffAttendanceDetailScreen(staff: staff),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Navigation failed: $e')),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AdminAttendanceApprovalScreen(),
            ),
          );
        },
        backgroundColor: Colors.deepPurpleAccent,
        tooltip: 'Add Attendance',
        child: const Icon(Icons.add),
      ),
    );
  }
}
