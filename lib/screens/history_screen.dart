
import 'package:flutter/material.dart';
import '../database/database_helper.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final db = DatabaseHelper.instance;

  List<Map<String, Object?>> history = [];
  String selectedFilter = 'All';
  bool loading = true;
  String? error;

  final filters = ['All', 'Active', 'Returned', 'Overdue'];

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  Future<void> loadHistory() async {
    if (mounted) {
      setState(() => loading = true);
    }

    try {
      final records = await db.getCheckoutHistory();

      if (!mounted) return;

      setState(() {
        history = records;
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

  Color statusColor(String status) {
    switch (status) {
      case 'Returned':
        return Colors.blue;
      case 'Overdue':
        return Colors.red;
      default:
        return Colors.green;
    }
  }

  IconData statusIcon(String status) {
    switch (status) {
      case 'Returned':
        return Icons.assignment_turned_in;
      case 'Overdue':
        return Icons.warning_amber_rounded;
      default:
        return Icons.schedule;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = history.where((transaction) {
      return selectedFilter == 'All' ||
          transaction['status'] == selectedFilter;
    }).toList();

    final activeCount =
        history.where((item) => item['status'] == 'Active').length;
    final returnedCount =
        history.where((item) => item['status'] == 'Returned').length;
    final overdueCount =
        history.where((item) => item['status'] == 'Overdue').length;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: loadHistory,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Checkout History',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Track equipment checkouts, returns, and overdue items.',
            ),
            const SizedBox(height: 18),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SummaryCard(
                  title: 'Total',
                  count: history.length,
                  color: Colors.deepPurple,
                ),
                _SummaryCard(
                  title: 'Active',
                  count: activeCount,
                  color: Colors.green,
                ),
                _SummaryCard(
                  title: 'Returned',
                  count: returnedCount,
                  color: Colors.blue,
                ),
                _SummaryCard(
                  title: 'Overdue',
                  count: overdueCount,
                  color: Colors.red,
                ),
              ],
            ),

            const SizedBox(height: 18),

            Wrap(
              spacing: 8,
              children: filters.map((filter) {
                return ChoiceChip(
                  label: Text(filter),
                  selected: selectedFilter == filter,
                  onSelected: (_) {
                    setState(() => selectedFilter = filter);
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            if (loading)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (error != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load history: $error',
                  textAlign: TextAlign.center,
                ),
              )
            else if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    selectedFilter == 'All'
                        ? 'No checkout history yet.'
                        : 'No $selectedFilter transactions found.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ...filtered.map((transaction) {
                final status =
                    transaction['status']?.toString() ?? 'Active';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor:
                                statusColor(status).withValues(alpha: 0.12),
                            child: Icon(
                              statusIcon(status),
                              color: statusColor(status),
                            ),
                          ),
                          title: Text(
                            transaction['equipment_name'].toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'Borrower: ${transaction['borrower_name']}',
                          ),
                          trailing: Chip(
                            label: Text(status),
                            labelStyle: TextStyle(
                              color: statusColor(status),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Divider(),
                        Text(
                          'Checkout Date: ${transaction['checkout_date']}',
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Due Date: ${transaction['due_date']}',
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Return Date: ${transaction['return_date'] ?? 'Not returned'}',
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Transaction ID: ${transaction['id']}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final int count;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
