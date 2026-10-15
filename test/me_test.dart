import 'package:flutter_test/flutter_test.dart';
import 'package:lujo_health_mobile/api/models/me.dart';

void main() {
  test('Me.fromJson lee la respuesta de GET /me', () {
    final me = Me.fromJson({
      'id': 'uuid',
      'logtoUserId': 'xb6',
      'username': 'e2e_admin',
      'name': 'Usuario E2E',
      'email': 'e2e@lujo-health.local',
      'avatarUrl': '',
      'status': 'active',
      'roles': ['admin'],
      'permissions': ['users.read', 'users.manage'],
    });

    expect(me.username, 'e2e_admin');
    expect(me.roles, ['admin']);
    expect(me.hasPermission('users.manage'), isTrue);
    expect(me.hasPermission('nope'), isFalse);
  });

  test('Me.fromJson tolera nulos', () {
    final me = Me.fromJson({
      'id': 'uuid',
      'logtoUserId': 'x',
      'username': null,
      'name': 'x',
      'email': null,
      'avatarUrl': '',
      'status': 'active',
      'roles': <String>[],
      'permissions': <String>[],
    });
    expect(me.email, isNull);
    expect(me.roles, isEmpty);
  });
}
