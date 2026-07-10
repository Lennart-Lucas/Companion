import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';

abstract class MediaTitleListTileActions {
  Future<void> deleteMediaTitle(String mediaTitleId);
}

class MediaTitleListActions implements MediaTitleListTileActions {
  MediaTitleListActions(this._api);

  final ApiClientService _api;

  bool get _isOffline =>
      !CompanionAnvilApp.instance.connectivity.isOnline;

  @override
  Future<void> deleteMediaTitle(String mediaTitleId) async {
    if (_isOffline) {
      throw Exception('Delete media title is not available offline');
    }
    final response = await _api.delete('/media-titles/$mediaTitleId');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Delete media title failed (HTTP ${response.statusCode})');
    }
  }
}
