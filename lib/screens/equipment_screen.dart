
import 'package:flutter/material.dart';
import '../database/database_helper.dart';

class EquipmentScreen extends StatefulWidget {
  const EquipmentScreen({super.key});

  @override
  State<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends State<EquipmentScreen> {
  final db = DatabaseHelper.instance;

  List<Map<String, Object?>> equipment = [];
  String search = '';
  String categoryFilter = 'All';
  String availabilityFilter = 'All';
  bool loading = true;
  String? error;

  final categories = ['Laptop', 'Camera', 'Tablet', 'Other'];
  final conditions = ['Excellent', 'Good', 'Fair', 'Damaged'];

  @override
  void initState() {
    super.initState();
    loadEquipment();
  }

  Future<void> loadEquipment() async {
    try {
      final records = await db.getEquipment();
      if (!mounted) return;
      setState(() {
        equipment = records;
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

  void message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> showEquipmentForm(
      [Map<String, Object?>? existing]) async {
    final nameController = TextEditingController(
      text: existing?['name']?.toString() ?? '',
    );
    String category =
        existing?['category']?.toString() ?? 'Laptop';
    String condition =
        existing?['condition']?.toString() ?? 'Good';

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          title: Text(
            existing == null ? 'Add Equipment' : 'Edit Equipment',
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
                      labelText: 'Equipment Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value == null || value.trim().isEmpty
                            ? 'Enter an equipment name'
                            : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: categories.map((item) {
                      return DropdownMenuItem(
                        value: item,
                        child: Text(item),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        updateDialog(() => category = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: condition,
                    decoration: const InputDecoration(
                      labelText: 'Condition',
                      border: OutlineInputBorder(),
                    ),
                    items: conditions.map((item) {
                      return DropdownMenuItem(
                        value: item,
                        child: Text(item),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        updateDialog(() => condition = value);
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
                if (!formKey.currentState!.validate()) return;

                final item = <String, Object?>{
                  'name': nameController.text.trim(),
                  'category': category,
                  'condition': condition,
                };

                try {
                  if (existing == null) {
                    await db.addEquipment(item);
                  } else {
                    await db.updateEquipment(
                      existing['id'] as int,
                      item,
                    );
                  }

                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  await loadEquipment();
                  message('Equipment saved successfully.');
                } catch (e) {
                  message('Unable to save equipment: $e');
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
  }

  Future<void> deleteEquipment(
      Map<String, Object?> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Equipment?'),
        content: Text(
          'Delete ${item['name']}? Equipment with checkout '
          'history cannot be deleted.',
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
      await db.deleteEquipment(item['id'] as int);
      await loadEquipment();
      message('Equipment deleted.');
    } catch (e) {
      message('Unable to delete equipment: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = equipment.where((item) {
      final name = item['name'].toString().toLowerCase();

      return name.contains(search.toLowerCase()) &&
          (categoryFilter == 'All' ||
              item['category'] == categoryFilter) &&
          (availabilityFilter == 'All' ||
              item['availability'] == availabilityFilter);
    }).toList();

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search equipment',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() => search = value);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: categoryFilter,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: ['All', ...categories].map((value) {
                      return DropdownMenuItem(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => categoryFilter = value!);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: availabilityFilter,
                    decoration: const InputDecoration(
                      labelText: 'Availability',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      'All',
                      'Available',
                      'Checked Out',
                    ].map((value) {
                      return DropdownMenuItem(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => availabilityFilter = value!);
                    },
                  ),
                ),
              ],
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
                                'No equipment found. Add your first item!',
                              ),
                            )
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final item = filtered[index];
                                final available =
                                    item['availability'] == 'Available';

                                return Card(
                                  child: ListTile(
                                    leading: Icon(
                                      Icons.devices,
                                      color: available
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                    title: Text(item['name'].toString()),
                                    subtitle: Text(
                                      '${item['category']} | '
                                      '${item['condition']} | '
                                      '${item['availability']}',
                                    ),
                                    trailing: PopupMenuButton<String>(
                                      onSelected: (action) {
                                        if (action == 'Edit') {
                                          showEquipmentForm(item);
                                        } else {
                                          deleteEquipment(item);
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
        onPressed: () => showEquipmentForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add Equipment'),
      ),
    );
  }
}
