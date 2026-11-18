
import 'package:flutter/material.dart';
import '../database/database_helper.dart';

class CheckoutsScreen extends StatefulWidget {
  const CheckoutsScreen({super.key});

  @override
  State<CheckoutsScreen> createState() => _CheckoutsScreenState();
}

class _CheckoutsScreenState extends State<CheckoutsScreen> {
  final db = DatabaseHelper.instance;

  List<Map<String, Object?>> checkouts = [];
  List<Map<String, Object?>> equipment = [];
  List<Map<String, Object?>> borrowers = [];

  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      final results = await Future.wait([
        db.getCheckoutHistory(),
        db.getEquipment(),
        db.getBorrowers(),
      ]);

      if (!mounted) return;

      setState(() {
        checkouts = results[0]
            .where((item) => item['return_date'] == null)
            .toList();
        equipment = results[1];
        borrowers = results[2];
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> createCheckout() async {
    await loadData();

    if (!mounted) return;

    final availableEquipment = equipment
        .where((item) => item['availability'] == 'Available')
        .toList();

    if (borrowers.isEmpty) {
      showMessage('Register a borrower before creating a checkout.');
      return;
    }

    if (availableEquipment.isEmpty) {
      showMessage('Add available equipment before creating a checkout.');
      return;
    }

    int? selectedBorrower;
    int? selectedEquipment;

    DateTime checkoutDate = DateUtils.dateOnly(DateTime.now());
    DateTime dueDate = checkoutDate.add(const Duration(days: 7));

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) {
          return AlertDialog(
            title: const Text('New Equipment Checkout'),
            content: SizedBox(
              width: 430,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: selectedBorrower,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Select Borrower',
                        border: OutlineInputBorder(),
                      ),
                      items: borrowers.map((borrower) {
                        return DropdownMenuItem<int>(
                          value: borrower['id'] as int,
                          child: Text(
                            borrower['name'].toString(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        updateDialog(() => selectedBorrower = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: selectedEquipment,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Select Available Equipment',
                        border: OutlineInputBorder(),
                      ),
                      items: availableEquipment.map((item) {
                        return DropdownMenuItem<int>(
                          value: item['id'] as int,
                          child: Text(
                            item['name'].toString(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        updateDialog(() => selectedEquipment = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('Checkout Date'),
                      subtitle: Text(formatDate(checkoutDate)),
                      trailing: const Icon(Icons.calendar_month),
                      onTap: () async {
                        final selected = await showDatePicker(
                          context: dialogContext,
                          initialDate: checkoutDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );

                        if (selected != null) {
                          updateDialog(() {
                            checkoutDate = selected;
                            if (!dueDate.isAfter(checkoutDate)) {
                              dueDate = checkoutDate.add(
                                const Duration(days: 7),
                              );
                            }
                          });
                        }
                      },
                    ),
                    ListTile(
                      title: const Text('Due Date'),
                      subtitle: Text(formatDate(dueDate)),
                      trailing: const Icon(Icons.event),
                      onTap: () async {
                        final selected = await showDatePicker(
                          context: dialogContext,
                          initialDate: dueDate.isAfter(checkoutDate)
                              ? dueDate
                              : checkoutDate.add(
                                  const Duration(days: 1),
                                ),
                          firstDate: checkoutDate.add(
                            const Duration(days: 1),
                          ),
                          lastDate: DateTime(2100),
                        );

                        if (selected != null) {
                          updateDialog(() => dueDate = selected);
                        }
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
                  if (selectedBorrower == null ||
                      selectedEquipment == null) {
                    showMessage(
                      'Select both a borrower and equipment.',
                    );
                    return;
                  }

                  if (!dueDate.isAfter(checkoutDate)) {
                    showMessage(
                      'Due date must be after checkout date.',
                    );
                    return;
                  }

                  try {
                    await db.createCheckout(
                      equipmentId: selectedEquipment!,
                      borrowerId: selectedBorrower!,
                      checkoutDate: checkoutDate,
                      dueDate: dueDate,
                    );

                    if (!dialogContext.mounted) return;

                    Navigator.pop(dialogContext);
                    await loadData();
                    showMessage('Equipment checked out successfully.');
                  } catch (e) {
                    showMessage('Unable to create checkout: $e');
                  }
                },
                child: const Text('Confirm Checkout'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> processReturn(
    Map<String, Object?> checkout,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Return Equipment'),
        content: Text(
          'Mark ${checkout['equipment_name']} as returned by '
          '${checkout['borrower_name']}?',
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
            child: const Text('Confirm Return'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await db.returnEquipment(
        checkout['id'] as int,
        DateTime.now(),
      );

      await loadData();
      showMessage('Equipment returned successfully.');
    } catch (e) {
      showMessage('Unable to return equipment: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text('Database error: $error'))
              : checkouts.isEmpty
                  ? const Center(
                      child: Text(
                        'No active checkouts.\n'
                        'Create a checkout to get started.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: loadData,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: checkouts.length,
                        itemBuilder: (context, index) {
                          final checkout = checkouts[index];
                          final overdue =
                              checkout['status'] == 'Overdue';

                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  ListTile(
                                    leading: Icon(
                                      Icons.assignment,
                                      color: overdue
                                          ? Colors.red
                                          : Colors.deepPurple,
                                    ),
                                    title: Text(
                                      checkout['equipment_name']
                                          .toString(),
                                    ),
                                    subtitle: Text(
                                      'Borrower: ${checkout['borrower_name']}\n'
                                      'Checkout: ${checkout['checkout_date']}\n'
                                      'Due: ${checkout['due_date']}',
                                    ),
                                    isThreeLine: true,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Text(
                                      overdue ? 'OVERDUE' : 'ACTIVE',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: overdue
                                            ? Colors.red
                                            : Colors.green,
                                      ),
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: () =>
                                          processReturn(checkout),
                                      icon: const Icon(
                                        Icons.assignment_turned_in,
                                      ),
                                      label: const Text('Return Equipment'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: createCheckout,
        icon: const Icon(Icons.add),
        label: const Text('New Checkout'),
      ),
    );
  }
}
