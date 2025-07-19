import 'package:flutter/material.dart';
import 'Admin_Active.dart';
import 'Admin_Inwait_Outwait.dart';
import 'Admin_Request_Approval.dart';
import 'Admin_Staff_Attendence.dart';
import 'Admin_Task_Management.dart';
import '../Firebasesetup.dart';
import '../auth.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  final List<Widget> _children = [
    TaskListTab(),
    StaffAttendanceScreen(),
    LeaveApprovalPage(),
    AdminWaitRecordsScreen(),
    Active_Admin_Selection(),
  ];

  final List<IconData> icons = [
    Icons.assignment_outlined,
    Icons.people_outline,
    Icons.beach_access_outlined,
    Icons.open_in_new_sharp,
    Icons.airplanemode_active,
  ];

  final List<String> labels = [
    'Task Management',
    'Work Reports',
    'Leave Approval',
    'Inward Outward',
    'Active Admin Selection',
  ];

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
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
          colors: [
            Colors.deepPurpleAccent.shade700,
            Colors.deepPurpleAccent.shade400,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurpleAccent.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      padding: const EdgeInsets.only(top: 40, left: 20, right: 16, bottom: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Admin Dashboard',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1.3,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 28, color: Colors.white),
            onPressed: () async {
              await FirebaseService.auth.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => AuthScreen()),
              );
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
            right: -90,
            child: Container(
              height: 180,
              width: 180,
              decoration: BoxDecoration(
                color: Colors.deepPurpleAccent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            left: -80,
            child: Container(
              height: 160,
              width: 160,
              decoration: BoxDecoration(
                color: Colors.deepPurpleAccent.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Material(
                elevation: 8,
                color: Colors.white,
                child: _children[_currentIndex],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }
}
