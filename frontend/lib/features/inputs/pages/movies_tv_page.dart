import 'package:flutter/material.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/features/inputs/models/media_title.dart';
import 'package:frontend/features/inputs/pages/media_title_detail_page.dart';
import 'package:frontend/features/inputs/services/media_title_list_actions.dart';
import 'package:frontend/features/inputs/widgets/add_media_title_sheet.dart';
import 'package:frontend/features/inputs/widgets/media_title_list_tile.dart';
import 'package:frontend/features/productivity/shared/widgets/record_grid_list_page.dart';

/// Movies & TV library backed by saved IMDb titles.
class MoviesTvPage extends StatefulWidget {
  const MoviesTvPage({super.key});

  @override
  State<MoviesTvPage> createState() => _MoviesTvPageState();
}

class _MoviesTvPageState extends State<MoviesTvPage> {
  int _refreshNonce = 0;

  late final MediaTitleListActions _actions = MediaTitleListActions(
    CompanionAnvilApp.instance.apiClient,
  );

  void _refreshList() {
    if (!mounted) return;
    setState(() => _refreshNonce++);
  }

  Future<void> _openAdd() async {
    final created = await showAddMediaTitleSheet(context);
    if (!mounted || created == null) return;
    _refreshList();
    _openDetail(context, created);
  }

  void _openDetail(BuildContext context, MediaTitle mediaTitle) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => MediaTitleDetailPage(
              mediaTitleId: mediaTitle.id,
              mediaTitle: mediaTitle,
              actions: _actions,
            ),
          ),
        )
        .then((_) => _refreshList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add title',
        onPressed: _openAdd,
        child: const Icon(Icons.add),
      ),
      body: ProductivityListPage(
        title: 'Movies & TV',
        iconName: 'Clapperboard',
        recordType: 'media_titles',
        emptyStateHint: 'Tap + to add a movie or TV show',
        refreshNonce: _refreshNonce,
        showDividers: false,
        wrapLayout: true,
        itemBuilder: (context, record, index, itemCount) {
          if (record is! MediaTitle) {
            return const SizedBox.shrink();
          }
          return MediaTitleListTile(
            mediaTitle: record,
            actions: _actions,
            inGrid: true,
            onTap: () => _openDetail(context, record),
            onDeleted: _refreshList,
          );
        },
      ),
    );
  }
}
