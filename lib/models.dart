import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String role;
  final DateTime createdAt;
  final String? profileImageUrl;
  final String? phoneNumber;
  final String? department;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.createdAt,
    this.profileImageUrl,
    this.phoneNumber,
    this.department,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'role': role,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'profileImageUrl': profileImageUrl,
      'phoneNumber': phoneNumber,
      'department': department,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] as String? ?? '',
      email: map['email'] as String? ?? '',
      name: map['name'] as String? ?? '',
      role: map['role'] as String? ?? 'staff',
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
      profileImageUrl: map['profileImageUrl'] as String?,
      phoneNumber: map['phoneNumber'] as String?,
      department: map['department'] as String?,
    );
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    String? role,
    DateTime? createdAt,
    String? profileImageUrl,
    String? phoneNumber,
    String? department,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      department: department ?? this.department,
    );
  }
}

class Task {
  final String id;
  final String clientName;
  final String natureOfEntity;
  final String natureOfWork;
  final DateTime assignDate;
  final DateTime deadline;
  final List<String> assignedStaffIds;
  final String status;
  final String? reassignmentRequest;
  final String? reassignmentReason;
  final DateTime receivedDate;
  final String? clientEmail;
  final String? clientPhone;
  final String? priority;
  final String? notes;

  Task({
    required this.id,
    required this.clientName,
    required this.natureOfEntity,
    required this.natureOfWork,
    required this.assignDate,
    required this.deadline,
    required this.assignedStaffIds,
    this.status = 'Pending',
    this.reassignmentRequest,
    this.reassignmentReason,
    DateTime? receivedDate,
    this.clientEmail,
    this.clientPhone,
    this.priority = 'Medium',
    this.notes,
  }) : receivedDate = receivedDate ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clientName': clientName,
      'natureOfEntity': natureOfEntity,
      'natureOfWork': natureOfWork,
      'assignDate': assignDate.millisecondsSinceEpoch,
      'deadline': deadline.millisecondsSinceEpoch,
      'assignedStaffIds': assignedStaffIds,
      'status': status,
      'reassignmentRequest': reassignmentRequest,
      'reassignmentReason': reassignmentReason,
      'receivedDate': receivedDate.millisecondsSinceEpoch,
      'clientEmail': clientEmail,
      'clientPhone': clientPhone,
      'priority': priority,
      'notes': notes,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as String? ?? '',
      clientName: map['clientName'] as String? ?? '',
      natureOfEntity: map['natureOfEntity'] as String? ?? 'Individual',
      natureOfWork: map['natureOfWork'] as String? ?? 'General',
      assignDate: map['assignDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['assignDate'] as int)
          : DateTime.now(),
      deadline: map['deadline'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['deadline'] as int)
          : DateTime.now().add(const Duration(days: 7)),
      assignedStaffIds: map['assignedStaffIds'] != null
          ? List<String>.from(map['assignedStaffIds'] as List)
          : <String>[],
      status: map['status'] as String? ?? 'Pending',
      reassignmentRequest: map['reassignmentRequest'] as String?,
      reassignmentReason: map['reassignmentReason'] as String?,
      receivedDate: map['receivedDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['receivedDate'] as int)
          : DateTime.now(),
      clientEmail: map['clientEmail'] as String?,
      clientPhone: map['clientPhone'] as String?,
      priority: map['priority'] as String? ?? 'Medium',
      notes: map['notes'] as String?,
    );
  }

  Task copyWith({
    String? id,
    String? clientName,
    String? natureOfEntity,
    String? natureOfWork,
    DateTime? assignDate,
    DateTime? deadline,
    List<String>? assignedStaffIds,
    String? status,
    String? reassignmentRequest,
    String? reassignmentReason,
    DateTime? receivedDate,
    String? clientEmail,
    String? clientPhone,
    String? priority,
    String? notes,
  }) {
    return Task(
      id: id ?? this.id,
      clientName: clientName ?? this.clientName,
      natureOfEntity: natureOfEntity ?? this.natureOfEntity,
      natureOfWork: natureOfWork ?? this.natureOfWork,
      assignDate: assignDate ?? this.assignDate,
      deadline: deadline ?? this.deadline,
      assignedStaffIds: assignedStaffIds ?? this.assignedStaffIds,
      status: status ?? this.status,
      reassignmentRequest: reassignmentRequest ?? this.reassignmentRequest,
      reassignmentReason: reassignmentReason ?? this.reassignmentReason,
      receivedDate: receivedDate ?? this.receivedDate,
      clientEmail: clientEmail ?? this.clientEmail,
      clientPhone: clientPhone ?? this.clientPhone,
      priority: priority ?? this.priority,
      notes: notes ?? this.notes,
    );
  }
}

class LeaveRequest {
  final String id;
  final String userId;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final DateTime requestedAt;
  final String status;
  final String? approverId;
  final String? approverNotes;
  final LeaveType leaveType;

  LeaveRequest({
    required this.id,
    required this.userId,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.requestedAt,
    this.status = 'pending',
    this.approverId,
    this.approverNotes,
    this.leaveType = LeaveType.casual,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'reason': reason,
      'requestedAt': Timestamp.fromDate(requestedAt),
      'status': status,
      'approverId': approverId,
      'approverNotes': approverNotes,
      'leaveType': leaveType.name,
    };
  }

  factory LeaveRequest.fromMap(Map<String, dynamic> map) {
    return LeaveRequest(
      id: map['id'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      reason: map['reason'] as String? ?? '',
      requestedAt: (map['requestedAt'] as Timestamp).toDate(),
      status: map['status'] as String? ?? 'pending',
      approverId: map['approverId'] as String?,
      approverNotes: map['approverNotes'] as String?,
      leaveType: LeaveType.values.firstWhere(
        (e) => e.name == (map['leaveType'] as String? ?? 'casual'),
        orElse: () => LeaveType.casual,
      ),
    );
  }

  LeaveRequest copyWith({
    String? id,
    String? userId,
    DateTime? startDate,
    DateTime? endDate,
    String? reason,
    DateTime? requestedAt,
    String? status,
    String? approverId,
    String? approverNotes,
    LeaveType? leaveType,
  }) {
    return LeaveRequest(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      reason: reason ?? this.reason,
      requestedAt: requestedAt ?? this.requestedAt,
      status: status ?? this.status,
      approverId: approverId ?? this.approverId,
      approverNotes: approverNotes ?? this.approverNotes,
      leaveType: leaveType ?? this.leaveType,
    );
  }
}

enum LeaveType { casual, sick, paid, unpaid, maternity, paternity, bereavement }

class AttendanceRecord {
  final String id;
  final String userId;
  final DateTime date;
  final DateTime? clockIn;
  final DateTime? clockOut;
  final String? type;
  final String? location;
  final String? notes;
  final String? status;

  AttendanceRecord({
    required this.id,
    required this.userId,
    required this.date,
    this.clockIn,
    this.clockOut,
    this.type,
    this.location,
    this.notes,
    this.status = 'pending',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'date': Timestamp.fromDate(date),
      'clockIn': clockIn != null ? Timestamp.fromDate(clockIn!) : null,
      'clockOut': clockOut != null ? Timestamp.fromDate(clockOut!) : null,
      'type': type,
      'location': location,
      'notes': notes,
      'status': status,
    };
  }

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    // Helper function to convert dynamic timestamp to DateTime
    DateTime? _parseTimestamp(dynamic timestamp) {
      if (timestamp == null) return null;
      if (timestamp is Timestamp) {
        return timestamp.toDate();
      } else if (timestamp is int) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      return null;
    }

    // Parse date field
    DateTime date;
    final dateValue = map['date'];
    if (dateValue is Timestamp) {
      date = dateValue.toDate();
    } else if (dateValue is int) {
      date = DateTime.fromMillisecondsSinceEpoch(dateValue);
    } else {
      date = DateTime.now(); // fallback
    }

    return AttendanceRecord(
      id: map['id'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      date: date,
      clockIn: _parseTimestamp(map['clockIn']),
      clockOut: _parseTimestamp(map['clockOut']),
      type: map['type'] as String?,
      location: map['location'] as String?,
      notes: map['notes'] as String?,
      status: map['status'] as String? ?? 'pending',
    );
  }
}

class WaitRecord {
  final String id;
  final String staffId;
  final String staffName;
  final String clientName;
  final String fileName;
  final DateTime inWaitTime;
  final DateTime? outWaitTime;
  final bool isCompleted;
  final String? outFileName;
  final String? status;
  final String? notes;
  final Duration? waitDuration;

  WaitRecord({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.clientName,
    required this.fileName,
    required this.inWaitTime,
    this.outWaitTime,
    this.isCompleted = false,
    this.outFileName,
    this.status,
    this.notes,
    this.waitDuration,
  });

  factory WaitRecord.fromMap(Map<String, dynamic> map) {
    return WaitRecord(
      id: map['id'] as String? ?? '',
      staffId: map['staffId'] as String? ?? '',
      staffName: map['staffName'] as String? ?? '',
      clientName: map['clientName'] as String? ?? '',
      fileName: map['fileName'] as String? ?? '',
      inWaitTime: (map['inWaitTime'] as Timestamp).toDate(),
      outWaitTime: map['outWaitTime'] != null
          ? (map['outWaitTime'] as Timestamp).toDate()
          : null,
      isCompleted: map['isCompleted'] as bool? ?? false,
      outFileName: map['outFileName'] as String?,
      status: map['status'] as String?,
      notes: map['notes'] as String?,
      waitDuration: map['waitDuration'] != null
          ? Duration(milliseconds: map['waitDuration'] as int)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'staffId': staffId,
      'staffName': staffName,
      'clientName': clientName,
      'fileName': fileName,
      'inWaitTime': Timestamp.fromDate(inWaitTime),
      'outWaitTime': outWaitTime != null
          ? Timestamp.fromDate(outWaitTime!)
          : null,
      'isCompleted': isCompleted,
      'outFileName': outFileName,
      'status': status,
      'notes': notes,
      'waitDuration': waitDuration?.inMilliseconds,
    };
  }

  WaitRecord copyWith({
    String? id,
    String? staffId,
    String? staffName,
    String? clientName,
    String? fileName,
    DateTime? inWaitTime,
    DateTime? outWaitTime,
    bool? isCompleted,
    String? outFileName,
    String? status,
    String? notes,
    Duration? waitDuration,
  }) {
    return WaitRecord(
      id: id ?? this.id,
      staffId: staffId ?? this.staffId,
      staffName: staffName ?? this.staffName,
      clientName: clientName ?? this.clientName,
      fileName: fileName ?? this.fileName,
      inWaitTime: inWaitTime ?? this.inWaitTime,
      outWaitTime: outWaitTime ?? this.outWaitTime,
      isCompleted: isCompleted ?? this.isCompleted,
      outFileName: outFileName ?? this.outFileName,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      waitDuration: waitDuration ?? this.waitDuration,
    );
  }
}
