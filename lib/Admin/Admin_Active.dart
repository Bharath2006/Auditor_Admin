import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';

class Active_Admin_Selection extends StatefulWidget {
  const Active_Admin_Selection({super.key});

  @override
  _Active_Admin_SelectionState createState() => _Active_Admin_SelectionState();
}

class _Active_Admin_SelectionState extends State<Active_Admin_Selection> {
  List<String> selectedUserIds = [];
  List<Map<String, dynamic>> staffUsers = [];
  List<Map<String, dynamic>> filteredUsers = [];
  List<String> existingActiveAdmins = [];
  bool isLoading = true;
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadInitialData();
  }

  Future<void> loadInitialData() async {
    try {
      await fetchActiveAdmins();
      await fetchStaffUsers();
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error loading data: $e",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchActiveAdmins() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('activeadmin').get();
      existingActiveAdmins = snapshot.docs.map((doc) => doc.id).toList();
      selectedUserIds = List.from(existingActiveAdmins);
    } catch (e) {
      throw 'Failed to load active admins';
    }
  }

  Future<void> fetchStaffUsers() async {
    try {
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'staff')
              .get();

      staffUsers =
          querySnapshot.docs
              .map(
                (doc) => {
                  'id': doc.id,
                  'name': doc['name'] ?? 'Unnamed',
                  'email': doc['email'] ?? '',
                },
              )
              .toList();

      filteredUsers = List.from(staffUsers);
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      throw 'Failed to fetch staff users';
    }
  }

  void toggleSelection(String userId) {
    setState(() {
      if (selectedUserIds.contains(userId)) {
        selectedUserIds.remove(userId);
      } else {
        selectedUserIds.add(userId);
      }
    });
  }

  void selectAll() {
    setState(() {
      selectedUserIds =
          filteredUsers.map((user) => user['id'] as String).toList();
    });
  }

  void unselectAll() {
    setState(() {
      selectedUserIds.clear();
    });
  }

  void searchUsers(String query) {
    final searchLower = query.toLowerCase();
    final filtered =
        staffUsers.where((user) {
          return user['name'].toLowerCase().contains(searchLower) ||
              user['email'].toLowerCase().contains(searchLower);
        }).toList();

    setState(() {
      filteredUsers = filtered;
    });
  }

  Future<void> saveSelectedToActiveAdmin() async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final collection = FirebaseFirestore.instance.collection('activeadmin');

      // Remove deselected old admins
      for (String oldId in existingActiveAdmins) {
        if (!selectedUserIds.contains(oldId)) {
          batch.delete(collection.doc(oldId));
        }
      }

      // Add or update new selections
      for (String userId in selectedUserIds) {
        batch.set(collection.doc(userId), {
          'userId': userId,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      setState(() {
        existingActiveAdmins = List.from(selectedUserIds);
      });

      Fluttertoast.showToast(
        msg: "✅ Active admins updated successfully.",
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: "❌ Failed to save: $e",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  bool hasChanges() {
    final current = selectedUserIds.toSet();
    final original = existingActiveAdmins.toSet();
    return current.difference(original).isNotEmpty ||
        original.difference(current).isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Assign Active Admins"),
        backgroundColor: Colors.deepPurple,
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: TextField(
                      controller: searchController,
                      onChanged: searchUsers,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: "Search by name or email",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton.icon(
                          onPressed: selectAll,
                          icon: Icon(Icons.select_all),
                          label: Text("Select All"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: unselectAll,
                          icon: Icon(Icons.clear_all),
                          label: Text("Unselect All"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child:
                        filteredUsers.isEmpty
                            ? const Center(
                              child: Text("No matching staff found."),
                            )
                            : ListView.builder(
                              itemCount: filteredUsers.length,
                              itemBuilder: (context, index) {
                                final user = filteredUsers[index];
                                final isSelected = selectedUserIds.contains(
                                  user['id'],
                                );

                                return Card(
                                  elevation: 3,
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 6,
                                    horizontal: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: ListTile(
                                    leading: Icon(
                                      Icons.person,
                                      color:
                                          isSelected
                                              ? Colors.deepPurple
                                              : Colors.grey.shade600,
                                    ),
                                    title: Text(
                                      user['name'],
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    subtitle: Text(user['email']),
                                    trailing: Checkbox(
                                      value: isSelected,
                                      onChanged:
                                          (_) => toggleSelection(user['id']),
                                      activeColor: Colors.deepPurple,
                                    ),
                                    onTap: () => toggleSelection(user['id']),
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),
      floatingActionButton:
          hasChanges()
              ? FloatingActionButton.extended(
                onPressed: saveSelectedToActiveAdmin,
                icon: Icon(Icons.save),
                label: Text("Save (${selectedUserIds.length} selected)"),
                backgroundColor: Colors.deepPurple,
              )
              : null,
    );
  }
}
