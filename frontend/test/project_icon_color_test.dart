import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';

void main() {
  group('Project icon/color serialization', () {
    test('fromFormValues + toJson includes icon and color on update', () {
      final values = {
        'name': 'Test',
        'status': 'active',
        'description': '',
        'goal_id': '',
        'icon': 'Person Digging',
        'color': 0xFF22AA88,
      };
      final project = Project.fromFormValues(values, id: '42');
      final json = project.toJson();

      expect(json['icon'], 'Person Digging');
      expect(json['color'], '#22AA88');
      expect(json['id'], '42');
    });

    test('toFormValues round-trips color as ARGB int', () {
      final project = Project(
        id: '1',
        name: 'P',
        icon: 'Hammer',
        color: '#FF0000',
      );
      final formValues = project.toFormValues();
      expect(formValues['icon'], 'Hammer');
      expect(formValues['color'], 0xFFFF0000);

      final rebuilt = Project.fromFormValues(formValues, id: '1');
      expect(rebuilt.icon, 'Hammer');
      expect(rebuilt.color, '#FF0000');
    });

    test('toJson omits null icon and color', () {
      final project = Project(id: '1', name: 'P');
      final json = project.toJson();
      expect(json.containsKey('icon'), isFalse);
      expect(json.containsKey('color'), isFalse);
    });
  });
}
