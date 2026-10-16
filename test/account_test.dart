import 'package:flutter_test/flutter_test.dart';
import 'package:lujo_health_mobile/api/models/account.dart';

void main() {
  test('NotificationPreferences va y vuelve de JSON', () {
    final prefs = NotificationPreferences.fromJson({
      'pushEnabled': true,
      'emailEnabled': false,
      'newFollowers': true,
      'followRequests': true,
      'comments': false,
      'reactions': true,
      'mentions': true,
      'groups': true,
      'reminders': true,
      'newsletter': true,
      'quietHoursStart': '22:00',
      'quietHoursEnd': '07:00',
    });
    expect(prefs.emailEnabled, isFalse);
    expect(prefs.comments, isFalse);
    expect(prefs.hasQuietHours, isTrue);

    final json = prefs
        .copyWith(quietHoursStart: '', quietHoursEnd: '')
        .toJson();
    expect(json['quietHoursStart'], '');
    expect(json.length, 12);
    expect(NotificationPreferences.fromJson(json).hasQuietHours, isFalse);
  });

  test('Session.label resume el user agent', () {
    Session make(String ua) => Session(
      id: 'x',
      clientId: 'c',
      ip: '',
      userAgent: ua,
      loginAt: DateTime.utc(2026),
      expiresAt: DateTime.utc(2026, 2),
    );
    expect(make('Dart/3.9 (dart:io)').label, 'App móvil');
    expect(
      make(
        'Mozilla/5.0 (Windows NT 10.0) AppleWebKit/537.36 Chrome/120 Safari/537.36',
      ).label,
      'Chrome · Windows',
    );
    expect(make('').label, 'Desconocido');
  });

  test('Device.listFromJson tolera listas vacías', () {
    expect(Device.listFromJson(null), isEmpty);
    final devices = Device.listFromJson([
      {
        'id': 'd1',
        'installationId': 'inst',
        'platform': 'android',
        'deviceName': 'Pixel 8',
        'appVersion': '1.0.0+1',
        'hasPushToken': false,
        'createdAt': '2026-10-15T00:00:00Z',
        'lastSeenAt': '2026-10-15T01:00:00Z',
      },
    ]);
    expect(devices.single.deviceName, 'Pixel 8');
    expect(devices.single.lastSeenAt.isAfter(devices.single.createdAt), isTrue);
  });
}
