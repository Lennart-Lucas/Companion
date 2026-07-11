import 'package:anvil_foundry/anvil_foundry.dart';

import 'package:frontend/core/records/record_json_utils.dart';

/// Shared list-display record for Companion productivity entities.
abstract class ProductivityRecord extends Record {
  String get name;

  static String idFromJson(Map<String, dynamic> json) =>
      RecordJsonUtils.idFromJson(json);

  static String nameFromJson(Map<String, dynamic> json) =>
      RecordJsonUtils.nameFromJson(json);

  static Map<String, dynamic> unwrapJson(Map<String, dynamic> json) =>
      RecordJsonUtils.unwrapJson(json);
}
