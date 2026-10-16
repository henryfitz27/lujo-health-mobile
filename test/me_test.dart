import 'package:flutter_test/flutter_test.dart';
import 'package:lujo_health_mobile/api/models/catalog_item.dart';
import 'package:lujo_health_mobile/api/models/me.dart';
import 'package:lujo_health_mobile/api/models/profile.dart';

void main() {
  test('Me.fromJson lee la respuesta de GET /me', () {
    final me = Me.fromJson({
      'id': 'uuid',
      'logtoUserId': 'xb6',
      'username': 'e2e_admin',
      'name': 'Usuario E2E',
      'email': 'e2e@lujo-health.local',
      'avatarUrl': '',
      'bio': 'Hola',
      'visibility': 'private',
      'language': 'es',
      'country': 'PE',
      'status': 'active',
      'onboardingCompleted': true,
      'roles': ['admin'],
      'permissions': ['users.read', 'users.manage'],
      'interests': [
        {
          'id': 1,
          'key': 'cocina',
          'name': 'Cocina',
          'sortOrder': 10,
          'active': true,
        },
      ],
      'dietaryPreferences': <Map<String, dynamic>>[],
      'allergens': <Map<String, dynamic>>[],
      'counts': {'followers': 3, 'following': 1},
    });

    expect(me.username, 'e2e_admin');
    expect(me.isPrivate, isTrue);
    expect(me.onboardingCompleted, isTrue);
    expect(me.interests.single.name, 'Cocina');
    expect(me.followers, 3);
    expect(me.hasPermission('users.manage'), isTrue);
    expect(me.hasPermission('nope'), isFalse);
  });

  test('Me.fromJson tolera nulos y campos ausentes', () {
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
    expect(me.onboardingCompleted, isFalse);
    expect(me.interests, isEmpty);
  });

  test('Catalogs y PublicProfile se parsean', () {
    final catalogs = Catalogs.fromJson({
      'interests': [
        {'id': 1, 'key': 'a', 'name': 'A'},
      ],
      'dietaryPreferences': [],
      'allergens': [
        {'id': 2, 'key': 'b', 'name': 'B', 'active': false},
      ],
    });
    expect(catalogs.interests.single.sortOrder, 0);
    expect(catalogs.allergens.single.active, isFalse);

    final profile = PublicProfile.fromJson({
      'id': 'p',
      'username': 'bob',
      'name': 'Bob',
      'avatarUrl': '',
      'bio': '',
      'visibility': 'private',
      'interests': [],
      'counts': {'followers': 0, 'following': 0},
      'relation': {'followRequested': true},
    });
    expect(profile.isPrivate, isTrue);
    expect(profile.relation.followRequested, isTrue);
    expect(profile.relation.following, isFalse);
    expect(
      profile
          .withRelation(
            const Relation(
              following: true,
              followRequested: false,
              followedBy: false,
              blocked: false,
              blockedBy: false,
            ),
          )
          .relation
          .following,
      isTrue,
    );
  });
}
