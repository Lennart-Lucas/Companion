import 'package:flutter/material.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/pages/goal_create_page.dart';
import 'package:frontend/features/productivity/pages/goal_edit_page.dart';
import 'package:frontend/features/productivity/widgets/goal_list_tile.dart';
import 'package:frontend/features/productivity/widgets/productivity_list_page.dart';

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  int _refreshNonce = 0;

  void _refreshList() {
    if (!mounted) return;
    setState(() => _refreshNonce++);
  }

  Future<void> _openCreate() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const GoalCreatePage(),
      ),
    );
    _refreshList();
  }

  void _openEdit(BuildContext context, Goal goal) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => GoalEditPage(
              goalId: goal.id,
              goal: goal,
            ),
          ),
        )
        .then((_) => _refreshList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-goals',
        tooltip: 'Add goal',
        onPressed: _openCreate,
        child: const Icon(Icons.add),
      ),
      body: ProductivityListPage(
        title: 'Goals',
        iconName: 'Bullseye',
        recordType: 'goals',
        emptyStateHint: 'Tap + to add a goal',
        refreshNonce: _refreshNonce,
        itemBuilder: (context, record, index, itemCount) {
          if (record is! Goal) {
            return const SizedBox.shrink();
          }
          return GoalListTile(
            goal: record,
            onTap: () => _openEdit(context, record),
          );
        },
      ),
    );
  }
}
