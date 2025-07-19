import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'Firebasesetup.dart';
import 'Admin/admin_dashboard.dart';
import 'auth.dart';
import 'models.dart';
import 'Staff/staffdashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auditor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseService.auth.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasData && snapshot.data != null) {
            return FutureBuilder<DocumentSnapshot>(
              future:
                  FirebaseService.firestore
                      .collection('users')
                      .doc(snapshot.data!.uid)
                      .get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                if (userSnapshot.hasError) {
                  return const Scaffold(
                    body: Center(child: Text("Error loading user data")),
                  );
                }

                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  try {
                    final data =
                        userSnapshot.data!.data() as Map<String, dynamic>;

                    if (!data.containsKey('role')) {
                      return const Scaffold(
                        body: Center(child: Text("No role found for user")),
                      );
                    }

                    final user = UserModel.fromMap(data);

                    return user.role == 'admin'
                        ? const AdminDashboard()
                        : const StaffDashboard();
                  } catch (e, stack) {
                    debugPrint("Error parsing user data: $e\n$stack");
                    return const Scaffold(
                      body: Center(child: Text("Invalid user data")),
                    );
                  }
                }

                return const AuthScreen();
              },
            );
          }

          return const AuthScreen();
        },
      ),
    );
  }
}
