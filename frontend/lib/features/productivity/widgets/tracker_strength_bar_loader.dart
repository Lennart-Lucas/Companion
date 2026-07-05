import 'package:flutter/material.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/services/tracker_check_in_repository.dart';
import 'package:frontend/features/productivity/services/tracker_stats.dart';
import 'package:frontend/features/productivity/widgets/tracker_display.dart';

/// Loads check-ins and renders a [TrackerStrengthBar] for list tiles.
class TrackerStrengthBarLoader extends StatefulWidget {
  const TrackerStrengthBarLoader({
    super.key,
    required this.tracker,
    this.repository,
  });

  final Tracker tracker;
  final TrackerCheckInRepository? repository;

  @override
  State<TrackerStrengthBarLoader> createState() =>
      _TrackerStrengthBarLoaderState();
}

class _TrackerStrengthBarLoaderState extends State<TrackerStrengthBarLoader> {
  double _strength = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(TrackerStrengthBarLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tracker.id != widget.tracker.id) {
      setState(() => _strength = 0);
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final checkIns = await fetchCheckInsForStrength(
        widget.tracker,
        repository: widget.repository,
      );
      if (!mounted) return;
      setState(() {
        _strength = computeTrackerStats(widget.tracker, checkIns).strength;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _strength = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TrackerStrengthBar(fraction: _strength);
  }
}
