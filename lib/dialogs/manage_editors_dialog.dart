import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/collection.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageEditorsDialog extends StatefulWidget {
  final Collection collection;

  const ManageEditorsDialog({super.key, required this.collection});

  @override
  State<ManageEditorsDialog> createState() => _ManageEditorsDialogState();
}

class _ManageEditorsDialogState extends State<ManageEditorsDialog> {
  final FirestoreService _dbService = FirestoreService();
  final TextEditingController _usernameController = TextEditingController();
  bool _isLoading = false;

  final Color _backgroundColor = const Color(0xFF1E1E1E);
  final Color _accentColor = const Color(0xFFBB86FC);
  final TextStyle _textStyle = const TextStyle(color: Colors.white);

  Future<void> _addEditor() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) return;

    setState(() => _isLoading = true);

    final result = await _dbService.addEditorByUsername(
      widget.collection.id!,
      username,
    );

    setState(() => _isLoading = false);

    if (mounted) {
      if (result == "Success") {
        _usernameController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Added $username as editor!"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _removeEditor(String uid) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _backgroundColor,
        title: Text("Remove Editor?", style: _textStyle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              "Cancel",
              style: TextStyle(color: Colors.grey.shade400),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Remove",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _dbService.removeEditorFromCollection(widget.collection.id!, uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 15, 10, 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Manage Editors",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _usernameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Enter username (e.g. user1234)",
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.black12,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isLoading ? null : _addEditor,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(14),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.person_add, color: Colors.black),
                ),
              ],
            ),
          ),

          Flexible(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('collections')
                  .doc(widget.collection.id!)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const SizedBox(
                    height: 50,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final data = snapshot.data!.data() as Map<String, dynamic>?;
                final List<String> editorUids = List<String>.from(
                  data?['editor_uids'] ?? [],
                );

                if (editorUids.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text(
                      "No editors added yet.",
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: editorUids.length,
                  itemBuilder: (context, index) {
                    final uid = editorUids[index];
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .get(),
                      builder: (context, userSnap) {
                        if (!userSnap.hasData) {
                          return const ListTile(title: Text("Loading..."));
                        }
                        final userData =
                            userSnap.data?.data() as Map<String, dynamic>?;
                        final username =
                            userData?['username'] ?? "Unknown User";

                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.white12,
                            child: Icon(Icons.person, color: Colors.white70),
                          ),
                          title: Text(username, style: _textStyle),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.remove_circle,
                              color: Colors.redAccent,
                            ),
                            onPressed: () => _removeEditor(uid),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
