import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../Admin/admin_dashboard.dart';
import '../Firebasesetup.dart';
import 'Staff_Attendence.dart';
import 'Staff_Inwait_Outwait.dart';
import 'Staff_Leave_Request.dart';
import 'Staff_Task_View.dart';
import '../auth.dart';
import 'Staff_task_request.dart';

class StaffDashboard extends StatefulWidget {
  const StaffDashboard({super.key});

  @override
  _StaffDashboardState createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isActiveAdmin = false;
  late AnimationController _animationController;

  final List<Widget> _children = [
    const StaffTaskScreen(),
    const AttendanceScreen(),
    const LeaveRequestPage(),
    const TaskRequestScreen(),
    const StaffWaitScreen(),
  ];

  final List<IconData> icons = [
    Icons.task_alt_outlined,
    Icons.calendar_today_outlined,
    Icons.beach_access_outlined,
    Icons.task_outlined,
    Icons.open_in_new_sharp,
  ];

  final List<String> labels = [
    'Tasks',
    'Work Reports',
    'Leave',
    'Requests',
    'Inward/Outward',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final uid = FirebaseService.auth.currentUser?.uid;
    if (uid == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('activeadmin')
        .doc(uid)
        .get();

    if (mounted) {
      setState(() {
        _isActiveAdmin = snapshot.exists;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Widget _buildGradientAppBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blueAccent.shade700, Colors.blueAccent.shade200],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'User Dashboard',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 28, color: Colors.white),
            onPressed: () async {
              try {
                await FirebaseService.auth.signOut();
                if (context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const AuthScreen()),
                  );
                }
              } catch (e) {
                debugPrint('Error signing out: $e');
              }
            },
            tooltip: 'Log Out',
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.1),
            blurRadius: 18,
            spreadRadius: 5,
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Wrap(
          alignment: WrapAlignment.spaceEvenly,
          spacing: 8,
          runSpacing: 8,
          children: List.generate(icons.length, (index) {
            final isSelected = _currentIndex == index;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _currentIndex = index;
                  _animationController.forward(from: 0);
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.deepPurpleAccent.shade100.withOpacity(0.3)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedScale(
                      scale: isSelected ? 1.3 : 1.0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: Icon(
                        icons[index],
                        size: isSelected ? 28 : 24,
                        color: isSelected
                            ? Colors.deepPurpleAccent.shade700
                            : Colors.grey.shade600,
                      ),
                    ),
                    if (isSelected)
                      Padding(
                        padding: const EdgeInsets.only(left: 6.0),
                        child: Text(
                          labels[index],
                          style: TextStyle(
                            color: Colors.deepPurpleAccent.shade700,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  void _onAdminFabTap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminDashboard()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(90),
        child: _buildGradientAppBar(),
      ),
      body: Stack(
        children: [
          Positioned(
            top: 20,
            right: -100,
            child: Container(
              height: 200,
              width: 200,
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            left: -80,
            child: Container(
              height: 180,
              width: 180,
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
            ),
          ),
          _children[_currentIndex],
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(),
      floatingActionButton: _isActiveAdmin
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.admin_panel_settings),
              label: const Text("Admin Panel"),
              backgroundColor: Colors.blueAccent.shade700,
              onPressed: _onAdminFabTap,
            )
          : null,
    );
  }
}
