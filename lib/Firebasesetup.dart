// ignore_for_file: file_names

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';

class FirebaseService {
  static late FirebaseAuth auth;
  static late FirebaseFirestore firestore;

  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    auth = FirebaseAuth.instance;
    firestore = FirebaseFirestore.instance;
  }
}
