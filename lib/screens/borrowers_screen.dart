
import 'package:flutter/material.dart';
import '../database/database_helper.dart';

class BorrowersScreen extends StatefulWidget {
  const BorrowersScreen({super.key});

  @override
  State<BorrowersScreen> createState() => _BorrowersScreenState();
}

class _BorrowersScreenState extends State<BorrowersScreen> {
  final db = DatabaseHelper.instance;

  List<Map<String, Object?>> borrowers = [];
  bool loading = true;
  String search = '';
  String? error;

  @override
  void initState() {
    super.initState();
    loadBorrowers();
  }

  Future<void> loadBorrowers() async {
    try {
      final records = await db.getBorrowers();

      if (!mounted) return;
      setState(() {
        borrowers = records;
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  void showMessage(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> showBorrowerForm(
    [Map<String, Object?>? existing]
  ) async {
    final nameController = TextEditingController(
      text: existing?['name']?.toString() ?? '',
    );
    final emailController = TextEditingController(
      text: existing?['email']?.toString() ?? '',
    );
    final departmentController = TextEditingController(
      text: existing?['department']?.toString() ?? '',
    );

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          existing == null ? 'Register Borrower' : 'Edit Borrower',
        ),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Full name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    final emailPattern = RegExp(
                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                    );

                    if (email.isEmpty) {
                      return 'Email is required';
                    }
                    if (!emailPattern.hasMatch(email)) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: departmentController,
                  decoration: const InputDecoration(
                    labelText: 'Department',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Department is required';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final borrower = <String, Object?>{
                'name': nameController.text.trim(),
                'email': emailController.text.trim(),
                'department': departmentController.text.trim(),
              };

              try {
                if (existing == null) {
                  await db.addBorrower(borrower);
                } else {
                  await db.updateBorrower(
                    existing['id'] as int,
                    borrower,
                  );
                }

                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);

                await loadBorrowers();
                showMessage('Borrower saved successfully.');
              } catch (e) {
                showMessage('Unable to save borrower: $e');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    nameController.dispose();
    emailController.dispose();
    departmentController.dispose();
  }

  Future<void> deleteBorrower(
    Map<String, Object?> borrower,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Borrower?'),
        content: Text(
          'Delete ${borrower['name']}? Borrowers with '
          'checkout history cannot be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await db.deleteBorrower(borrower['id'] as int);
      await loadBorrowers();
      showMessage('Borrower deleted.');
    } catch (e) {
      showMessage('Unable to delete borrower: $e');
    }
  }

  Future<void> showBorrowerDetails(
    Map<String, Object?> borrower,
  ) async {
    try {
      final history = await db.getCheckoutHistory();

      final transactions = history.where(
        (item) => item['borrower_id'] == borrower['id'],
      ).toList();

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(borrower['name'].toString()),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Email: ${borrower['email']}'),
                  const SizedBox(height: 8),
                  Text('Department: ${borrower['department']}'),
                  const SizedBox(height: 8),
                  Text(
                    'Currently Borrowed: ${borrower['active_count']}',
                  ),
                  const Divider(height: 28),
                  const Text(
                    'Checkout Transactions',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (transactions.isEmpty)
                    const Text('No checkout history yet.')
                  else
                    ...transactions.map((item) {
                      return Card(
                        child: ListTile(
                          title: Text(
                            item['equipment_name'].toString(),
                          ),
                          subtitle: Text(
                            'Checkout: ${item['checkout_date']}\n'
                            'Due: ${item['due_date']}\n'
                            'Returned: ${item['return_date'] ?? 'Not yet'}',
                          ),
                          trailing: Text(
                            item['status'].toString(),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      showMessage('Unable to load borrower details: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = borrowers.where((borrower) {
      final name = borrower['name'].toString().toLowerCase();
      final department =
          borrower['department'].toString().toLowerCase();
      final query = search.toLowerCase();

      return name.contains(query) || department.contains(query);
    }).toList();

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search borrowers',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() => search = value);
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: loading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : error != null
                      ? Center(
                          child: Text('Database error: $error'),
                        )
                      : filtered.isEmpty
                          ? const Center(
                              child: Text(
                                'No borrowers found. Register your first borrower!',
                              ),
                            )
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final borrower = filtered[index];

                                return Card(
                                  child: ListTile(
                                    leading: const CircleAvatar(
                                      child: Icon(Icons.person),
                                    ),
                                    title: Text(
                                      borrower['name'].toString(),
                                    ),
                                    subtitle: Text(
                                      '${borrower['department']}\n'
                                      'Active checkouts: ${borrower['active_count']}',
                                    ),
                                    isThreeLine: true,
                                    onTap: () =>
                                        showBorrowerDetails(borrower),
                                    trailing: PopupMenuButton<String>(
                                      onSelected: (action) {
                                        if (action == 'Edit') {
                                          showBorrowerForm(borrower);
                                        } else {
                                          deleteBorrower(borrower);
                                        }
                                      },
                                      itemBuilder: (context) => const [
                                        PopupMenuItem(
                                          value: 'Edit',
                                          child: Text('Edit'),
                                        ),
                                        PopupMenuItem(
                                          value: 'Delete',
                                          child: Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showBorrowerForm(),
        icon: const Icon(Icons.person_add),
        label: const Text('Register Borrower'),
      ),
    );
  }
}
