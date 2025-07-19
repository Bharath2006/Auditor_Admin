import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminAttendanceApprovalScreen extends StatefulWidget {
  const AdminAttendanceApprovalScreen({super.key});

  @override
  State<AdminAttendanceApprovalScreen> createState() =>
      _AdminAttendanceApprovalScreenState();
}

class _AdminAttendanceApprovalScreenState
    extends State<AdminAttendanceApprovalScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Approvals'),
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('admin_attendance_approval')
                .where('status', isEqualTo: 'pending')
                .orderBy('timestamp', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading approvals.\nEnsure Firestore index exists.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade700),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No pending approvals 🎉'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final userId = data['userId'] ?? 'N/A';

              return FutureBuilder<DocumentSnapshot>(
                future:
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .get(),
                builder: (context, userSnapshot) {
                  final userData =
                      userSnapshot.data?.data() as Map<String, dynamic>?;

                  final userName =
                      userData?['name'] ?? data['name'] ?? 'Unknown';
                  final date = DateFormat(
                    'yyyy-MM-dd',
                  ).format(DateTime.fromMillisecondsSinceEpoch(data['date']));
                  final clockIn =
                      data['clockIn'] != null
                          ? DateFormat('hh:mm a').format(
                            DateTime.fromMillisecondsSinceEpoch(
                              data['clockIn'],
                            ),
                          )
                          : 'N/A';
                  final clockOut =
                      data['clockOut'] != null
                          ? DateFormat('hh:mm a').format(
                            DateTime.fromMillisecondsSinceEpoch(
                              data['clockOut'],
                            ),
                          )
                          : 'N/A';

                  return Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const CircleAvatar(
                                backgroundColor: Colors.deepPurple,
                                child: Icon(Icons.person, color: Colors.white),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    Text(
                                      'ID: $userId',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Chip(
                                backgroundColor: Colors.orange[100],
                                label: Text(
                                  "Pending",
                                  style: TextStyle(color: Colors.orange[800]),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Text("Date: $date"),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.login,
                                size: 16,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 6),
                              Text("Clock In: $clockIn"),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.logout,
                                size: 16,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 6),
                              Text("Clock Out: $clockOut"),
                            ],
                          ),
                          const Divider(height: 25),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton.icon(
                                icon: const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                ),
                                label: const Text(
                                  "Approve",
                                  style: TextStyle(color: Colors.green),
                                ),
                                onPressed:
                                    () => _approveAttendance(
                                      doc.id,
                                      userId,
                                      true,
                                    ),
                              ),
                              TextButton.icon(
                                icon: const Icon(
                                  Icons.cancel,
                                  color: Colors.red,
                                ),
                                label: const Text(
                                  "Reject",
                                  style: TextStyle(color: Colors.red),
                                ),
                                onPressed:
                                    () => _approveAttendance(
                                      doc.id,
                                      userId,
                                      false,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _approveAttendance(
    String docId,
    String userId,
    bool approved,
  ) async {
    final batch = FirebaseFirestore.instance.batch();

    final doc =
        await FirebaseFirestore.instance
            .collection('admin_attendance_approval')
            .doc(docId)
            .get();

    if (!doc.exists) return;

    final _ = doc.data()!;
    final userAttendanceRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('attendance')
        .doc(docId);

    batch.update(doc.reference, {
      'status': approved ? 'approved' : 'rejected',
      'processedAt': FieldValue.serverTimestamp(),
    });

    batch.update(userAttendanceRef, {
      'status': approved ? 'approved' : 'rejected',
      'type': approved ? 'Present' : 'Absent',
    });

    await batch.commit();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approved ? 'Attendance Approved ✅' : 'Attendance Rejected ❌',
          ),
          backgroundColor: approved ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
