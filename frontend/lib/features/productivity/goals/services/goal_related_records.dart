import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/features/productivity/trackers/models/tracker.dart';
import 'package:frontend/features/productivity/projects/models/project.dart';


const goalRelatedProjectsQuery = RecordQuery(recordType: 'projects', limit: 50);
const goalRelatedTrackersQuery = RecordQuery(recordType: 'trackers', limit: 50);

bool goalIdsMatch(String? recordGoalId, String goalId) {
  if (recordGoalId == null || recordGoalId.isEmpty) return false;
  return recordGoalId == goalId;
}

List<Project> projectsLinkedToGoal(RecordState state, String goalId) {
  final cached = state.snapshot.queries[goalRelatedProjectsQuery.queryKey];
  if (cached == null) return const [];

  final projects = <Project>[];
  for (final id in cached.recordIds) {
    final record = state.snapshot.records[id]?.record;
    if (record is Project && goalIdsMatch(record.goalId, goalId)) {
      projects.add(record);
    }
  }
  projects.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return projects;
}

List<Tracker> trackersLinkedToGoal(RecordState state, String goalId) {
  final cached = state.snapshot.queries[goalRelatedTrackersQuery.queryKey];
  if (cached == null) return const [];

  final trackers = <Tracker>[];
  for (final id in cached.recordIds) {
    final record = state.snapshot.records[id]?.record;
    if (record is Tracker && goalIdsMatch(record.goalId, goalId)) {
      trackers.add(record);
    }
  }
  trackers.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return trackers;
}
