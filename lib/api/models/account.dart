/// Modelos de cuenta: preferencias de notificaciones, dispositivos y sesiones.
class NotificationPreferences {
  const NotificationPreferences({
    required this.pushEnabled,
    required this.emailEnabled,
    required this.newFollowers,
    required this.followRequests,
    required this.comments,
    required this.reactions,
    required this.mentions,
    required this.groups,
    required this.reminders,
    required this.newsletter,
    required this.quietHoursStart,
    required this.quietHoursEnd,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    bool flag(String key) => json[key] as bool? ?? true;
    return NotificationPreferences(
      pushEnabled: flag('pushEnabled'),
      emailEnabled: flag('emailEnabled'),
      newFollowers: flag('newFollowers'),
      followRequests: flag('followRequests'),
      comments: flag('comments'),
      reactions: flag('reactions'),
      mentions: flag('mentions'),
      groups: flag('groups'),
      reminders: flag('reminders'),
      newsletter: json['newsletter'] as bool? ?? false,
      quietHoursStart: json['quietHoursStart'] as String? ?? '',
      quietHoursEnd: json['quietHoursEnd'] as String? ?? '',
    );
  }

  final bool pushEnabled;
  final bool emailEnabled;
  final bool newFollowers;
  final bool followRequests;
  final bool comments;
  final bool reactions;
  final bool mentions;
  final bool groups;
  final bool reminders;
  final bool newsletter;
  final String quietHoursStart;
  final String quietHoursEnd;

  bool get hasQuietHours =>
      quietHoursStart.isNotEmpty && quietHoursEnd.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'pushEnabled': pushEnabled,
    'emailEnabled': emailEnabled,
    'newFollowers': newFollowers,
    'followRequests': followRequests,
    'comments': comments,
    'reactions': reactions,
    'mentions': mentions,
    'groups': groups,
    'reminders': reminders,
    'newsletter': newsletter,
    'quietHoursStart': quietHoursStart,
    'quietHoursEnd': quietHoursEnd,
  };

  NotificationPreferences copyWith({
    bool? pushEnabled,
    bool? emailEnabled,
    bool? newFollowers,
    bool? followRequests,
    bool? comments,
    bool? reactions,
    bool? mentions,
    bool? groups,
    bool? reminders,
    bool? newsletter,
    String? quietHoursStart,
    String? quietHoursEnd,
  }) {
    return NotificationPreferences(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
      newFollowers: newFollowers ?? this.newFollowers,
      followRequests: followRequests ?? this.followRequests,
      comments: comments ?? this.comments,
      reactions: reactions ?? this.reactions,
      mentions: mentions ?? this.mentions,
      groups: groups ?? this.groups,
      reminders: reminders ?? this.reminders,
      newsletter: newsletter ?? this.newsletter,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
    );
  }
}

class Device {
  const Device({
    required this.id,
    required this.installationId,
    required this.platform,
    required this.deviceName,
    required this.appVersion,
    required this.hasPushToken,
    required this.createdAt,
    required this.lastSeenAt,
  });

  factory Device.fromJson(Map<String, dynamic> json) => Device(
    id: json['id'] as String,
    installationId: json['installationId'] as String,
    platform: json['platform'] as String,
    deviceName: json['deviceName'] as String? ?? '',
    appVersion: json['appVersion'] as String? ?? '',
    hasPushToken: json['hasPushToken'] as bool? ?? false,
    createdAt: DateTime.parse(json['createdAt'] as String),
    lastSeenAt: DateTime.parse(json['lastSeenAt'] as String),
  );

  static List<Device> listFromJson(Object? items) => [
    for (final item in (items as List<dynamic>? ?? const []))
      Device.fromJson(item as Map<String, dynamic>),
  ];

  final String id;
  final String installationId;
  final String platform;
  final String deviceName;
  final String appVersion;
  final bool hasPushToken;
  final DateTime createdAt;
  final DateTime lastSeenAt;
}

class Session {
  const Session({
    required this.id,
    required this.clientId,
    required this.ip,
    required this.userAgent,
    required this.loginAt,
    required this.expiresAt,
  });

  factory Session.fromJson(Map<String, dynamic> json) => Session(
    id: json['id'] as String,
    clientId: json['clientId'] as String? ?? '',
    ip: json['ip'] as String? ?? '',
    userAgent: json['userAgent'] as String? ?? '',
    loginAt: DateTime.parse(json['loginAt'] as String),
    expiresAt: DateTime.parse(json['expiresAt'] as String),
  );

  static List<Session> listFromJson(Object? items) => [
    for (final item in (items as List<dynamic>? ?? const []))
      Session.fromJson(item as Map<String, dynamic>),
  ];

  final String id;
  final String clientId;
  final String ip;
  final String userAgent;
  final DateTime loginAt;
  final DateTime expiresAt;

  /// Describe el origen de la sesión a partir del user agent.
  String get label {
    final ua = userAgent;
    if (ua.isEmpty) return 'Desconocido';
    if (RegExp('okhttp|dart|flutter', caseSensitive: false).hasMatch(ua)) {
      return 'App móvil';
    }
    final os = ua.contains('Android')
        ? 'Android'
        : RegExp('iPhone|iPad').hasMatch(ua)
        ? 'iOS'
        : ua.contains('Windows')
        ? 'Windows'
        : ua.contains('Mac OS')
        ? 'macOS'
        : ua.contains('Linux')
        ? 'Linux'
        : '';
    final browser = ua.contains('Edg/')
        ? 'Edge'
        : ua.contains('Chrome/')
        ? 'Chrome'
        : ua.contains('Firefox/')
        ? 'Firefox'
        : ua.contains('Safari/')
        ? 'Safari'
        : 'Navegador';
    return os.isEmpty ? browser : '$browser · $os';
  }
}
