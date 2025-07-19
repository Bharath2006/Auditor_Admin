import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LeaveApprovalPage extends StatefulWidget {
  const LeaveApprovalPage({super.key});

  @override
  State<LeaveApprovalPage> createState() => _LeaveApprovalPageState();
}

class _LeaveApprovalPageState extends State<LeaveApprovalPage> {
  Future<void> _approveLeave(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final userId = data['userId'];
    final name = data['name'];
    final reason = data['reason'];
    final fromDate = data['fromDate'];
    final toDate = data['toDate'];

    final attendanceData = {
      'name': name,
      'reason': reason,
      'fromDate': fromDate,
      'toDate': toDate,
      'status': 'approved',
      'type': 'Leave',
      'timestamp': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('attendance')
        .add(attendanceData);

    await doc.reference.update({'status': 'approved'});
  }

  Future<void> _rejectLeave(DocumentSnapshot doc) async {
    await doc.reference.update({'status': 'rejected'});
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.15),
        border: Border.all(color: _getStatusColor(status)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: _getStatusColor(status),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  void _showConfirmationDialog({
    required String title,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        actions: [
          TextButton(child: Text("Cancel"), onPressed: () => Navigator.pop(context)),
          ElevatedButton(
            child: Text("Yes"),
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Leave Approval"),
        elevation: 4,
        backgroundColor: Colors.deepPurpleAccent,
      ),
      backgroundColor: Colors.grey[100],
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('leave_requests')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Text(
                "No leave requests.",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index];
              final fromDate = (data['fromDate'] as Timestamp).toDate();
              final toDate = (data['toDate'] as Timestamp).toDate();

              return Card(
                margin: EdgeInsets.only(bottom: 14),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 16, horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            data['name'],
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          _buildStatusBadge(data['status']),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        "From: ${DateFormat.yMMMd().format(fromDate)}",
                        style: TextStyle(fontSize: 14),
                      ),
                      Text(
                        "To: ${DateFormat.yMMMd().format(toDate)}",
                        style: TextStyle(fontSize: 14),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "Reason: ${data['reason']}",
                        style: TextStyle(fontSize: 14),
                      ),
                      if (data['status'] == 'pending') ...[
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  _showConfirmationDialog(
                                    title: "Approve this leave?",
                                    onConfirm: () => _approveLeave(data),
                                  );
                                },
                                icon: Icon(Icons.check_circle_outline),
                                label: Text("Approve"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  _showConfirmationDialog(
                                    title: "Reject this leave?",
                                    onConfirm: () => _rejectLeave(data),
                                  );
                                },
                                icon: Icon(Icons.cancel_outlined),
                                label: Text("Reject"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        )
                      ]
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
