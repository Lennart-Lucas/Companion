import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/core/records/companion_record_hydration.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';

/// Loads a project for edit hydration; submits via [RecordBloc].
class ProjectRecordSubmitHandler extends FormSubmitHandler {
  ProjectRecordSubmitHandler({
    required this.recordBloc,
    this.recordId,
    this.preloadedProject,
  });

  final RecordBloc recordBloc;
  final RecordId? recordId;
  final Project? preloadedProject;

  static const _projectsQuery = RecordQuery(recordType: 'projects', limit: 50);

  late final RecordSubmitHandler _delegate = RecordSubmitHandler(
    recordBloc: recordBloc,
    recordType: 'projects',
    recordId: recordId,
    toRecord: (values) => Project.fromFormValues(values, id: recordId),
    fromRecord: (record) => (record as Project).toFormValues(),
  );

  @override
  bool get canHydrate => recordId != null;

  @override
  Future<Map<String, dynamic>> hydrate() async {
    if (recordId == null) return {};

    if (preloadedProject != null) {
      return preloadedProject!.toFormValues();
    }

    return hydrateRecordValues(
      recordBloc: recordBloc,
      recordType: 'projects',
      recordId: recordId!,
      fromRecord: (record) => (record as Project).toFormValues(),
    );
  }

  @override
  Future<FormSubmitResult> submit(Map<String, dynamic> values) async {
    final result = await _delegate.submit(values);
    if (!result.success) return result;

    final id = _resolveProjectId(result);
    if (id == null) return result;

    recordBloc.add(GetRecordRequested(recordType: 'projects', recordId: id));
    recordBloc.remoteCoordinator?.refreshQueryRecords(_projectsQuery);
    return result;
  }

  String? _resolveProjectId(FormSubmitResult result) {
    if (recordId != null) return recordId;
    final data = result.data;
    if (data is Map<String, dynamic>) {
      final id = data['id']?.toString();
      if (id != null && id.isNotEmpty) return id;
    }
    return null;
  }

  @override
  void dispose() => _delegate.dispose();
}
