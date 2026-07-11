import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/records/companion_record_registry.dart';
import 'package:frontend/core/records/productivity_record.dart';
import 'package:frontend/features/productivity/shared/widgets/record_grid_list_page.dart';

typedef EntityListTileBuilder<T extends ProductivityRecord> = Widget Function(
  BuildContext context,
  T record,
  VoidCallback onTap,
  VoidCallback onEdit,
  VoidCallback onDeleted,
);

/// Shared scaffold for goals, trackers, and projects list pages.
class EntityListPage<T extends ProductivityRecord> extends StatefulWidget {
  const EntityListPage({
    super.key,
    required this.title,
    required this.iconName,
    required this.recordType,
    required this.fabTooltip,
    required this.emptyStateHint,
    required this.createPage,
    required this.buildDetailPage,
    required this.buildEditPage,
    required this.buildTile,
    this.additionalRefreshQueries = const [],
    this.onInit,
  });

  final String title;
  final String iconName;
  final RecordType recordType;
  final String fabTooltip;
  final String emptyStateHint;
  final Widget createPage;
  final Widget Function(T record) buildDetailPage;
  final Widget Function(T record) buildEditPage;
  final EntityListTileBuilder<T> buildTile;
  final List<RecordQuery> additionalRefreshQueries;
  final void Function(BuildContext context)? onInit;

  @override
  State<EntityListPage<T>> createState() => _EntityListPageState<T>();
}

class _EntityListPageState<T extends ProductivityRecord>
    extends State<EntityListPage<T>> {
  int _refreshNonce = 0;

  @override
  void initState() {
    super.initState();
    if (widget.onInit != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onInit!(context);
      });
    }
  }

  void _refreshList() {
    if (!mounted) return;
    setState(() => _refreshNonce++);
  }

  Future<void> _openCreate() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => widget.createPage),
    );
    _refreshList();
  }

  void _openDetail(T record) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => widget.buildDetailPage(record),
          ),
        )
        .then((_) => _refreshList());
  }

  void _openEdit(T record) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => widget.buildEditPage(record),
          ),
        )
        .then((_) => _refreshList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: widget.fabTooltip,
        onPressed: _openCreate,
        child: const Icon(Icons.add),
      ),
      body: RecordGridListPage(
        title: widget.title,
        iconName: widget.iconName,
        recordType: widget.recordType,
        emptyStateHint: widget.emptyStateHint,
        refreshNonce: _refreshNonce,
        additionalRefreshQueries: widget.additionalRefreshQueries,
        showDividers: false,
        wrapLayout: true,
        itemBuilder: (context, record, index, itemCount) {
          if (record is! T) {
            return const SizedBox.shrink();
          }
          return widget.buildTile(
            context,
            record,
            () => _openDetail(record),
            () => _openEdit(record),
            _refreshList,
          );
        },
      ),
    );
  }
}
