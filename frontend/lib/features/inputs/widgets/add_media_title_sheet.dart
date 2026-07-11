import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/features/inputs/models/media_title.dart';
import 'package:frontend/features/inputs/services/imdb_search_api.dart';
import 'package:frontend/features/inputs/services/media_title_repository.dart';
import 'package:frontend/features/inputs/widgets/media_title_poster_thumbnail.dart';
import 'package:frontend/core/ui/companion_layout.dart';

Future<MediaTitle?> showAddMediaTitleSheet(BuildContext context) {
  final compact = CompanionLayout.isCompact(context);
  if (compact) {
    return showModalBottomSheet<MediaTitle>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const AddMediaTitleSheet(),
    );
  }
  return showDialog<MediaTitle>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: const AddMediaTitleSheet(),
      ),
    ),
  );
}

class AddMediaTitleSheet extends StatefulWidget {
  const AddMediaTitleSheet({super.key});

  @override
  State<AddMediaTitleSheet> createState() => _AddMediaTitleSheetState();
}

class _AddMediaTitleSheetState extends State<AddMediaTitleSheet> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _debounce;
  bool _loading = false;
  bool _saving = false;
  String? _error;
  List<ImdbTitleSummary> _results = const [];
  ImdbTitleDetail? _preview;

  late final ImdbSearchApi _imdbSearchApi = ImdbSearchApi(
    CompanionAnvilApp.instance.apiClient,
  );
  late final MediaTitleRepository _repository = MediaTitleRepository(
    CompanionAnvilApp.instance.apiClient,
  );

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _runSearch);
  }

  Future<void> _runSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
        _results = const [];
        _preview = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _preview = null;
    });

    try {
      final imdbId = normalizeImdbIdInput(query);
      if (imdbId != null) {
        final detail = await _imdbSearchApi.fetchTitle(imdbId);
        if (!mounted) return;
        setState(() {
          _loading = false;
          _results = const [];
          _preview = detail;
        });
        return;
      }

      final results = await _imdbSearchApi.searchTitles(query);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _results = results;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
        _results = const [];
      });
    }
  }

  Future<void> _saveTitle(String imdbId) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final created = await _repository.createFromImdbId(imdbId);
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } on MediaTitleAlreadyExistsException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _previewResult(ImdbTitleSummary summary) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await _imdbSearchApi.fetchTitle(summary.imdbId);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _preview = detail;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Widget _buildPreviewCard(ImdbTitleDetail detail) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MediaTitlePosterThumbnail(
              posterUrl: detail.posterUrl,
              width: 56,
              height: 84,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (detail.year != null) '${detail.year}',
                      mediaTypeLabel(detail.mediaType),
                      detail.imdbId,
                    ].join(' · '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _saving ? null : () => _saveTitle(detail.imdbId),
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add),
                    label: const Text('Add to library'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultTile(ImdbTitleSummary summary) {
    return ListTile(
      leading: MediaTitlePosterThumbnail(
        posterUrl: summary.posterUrl,
        width: 40,
        height: 60,
      ),
      title: Text(summary.name),
      subtitle: Text(
        [
          if (summary.year != null) '${summary.year}',
          mediaTypeLabel(summary.mediaType),
        ].join(' · '),
      ),
      onTap: _saving ? null : () => _previewResult(summary),
      trailing: IconButton(
        tooltip: 'Add',
        icon: const Icon(Icons.add),
        onPressed: _saving ? null : () => _saveTitle(summary.imdbId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Add Movies & TV',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search by title or IMDb ID (tt1234567)',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _runSearch();
                          },
                        )
                      : null,
                ),
                onSubmitted: (_) => _runSearch(),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              )
            else if (_preview != null)
              _buildPreviewCard(_preview!)
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final summary in _results) _buildResultTile(summary),
                    if (_results.isEmpty &&
                        _searchController.text.trim().isNotEmpty &&
                        _error == null)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('No matches found')),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
