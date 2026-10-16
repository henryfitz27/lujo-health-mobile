import 'package:flutter/material.dart';

/// Perfil de contacto y tarjeta digital (etapa 9).

const contactLinkKinds = [
  'whatsapp',
  'telegram',
  'instagram',
  'tiktok',
  'facebook',
  'youtube',
  'x',
  'linkedin',
  'other',
];

String contactKindLabel(String kind) => switch (kind) {
  'whatsapp' => 'WhatsApp',
  'telegram' => 'Telegram',
  'instagram' => 'Instagram',
  'tiktok' => 'TikTok',
  'facebook' => 'Facebook',
  'youtube' => 'YouTube',
  'x' => 'X',
  'linkedin' => 'LinkedIn',
  _ => 'Enlace',
};

IconData contactKindIcon(String kind) => switch (kind) {
  'whatsapp' => Icons.chat,
  'telegram' => Icons.send,
  'instagram' => Icons.camera_alt_outlined,
  'tiktok' => Icons.music_note,
  'facebook' => Icons.facebook,
  'youtube' => Icons.play_circle_outline,
  'x' => Icons.alternate_email,
  'linkedin' => Icons.work_outline,
  _ => Icons.link,
};

String contactKindHint(String kind) => switch (kind) {
  'whatsapp' => '+51 999 888 777',
  'telegram' => '@usuario o número',
  'other' => 'https://…',
  _ => '@usuario o enlace',
};

class ContactLink {
  const ContactLink({
    this.id = '',
    required this.kind,
    this.label = '',
    this.value = '',
    this.url = '',
    this.clicksCount = 0,
    this.hidden = false,
    this.hiddenReason = '',
  });

  factory ContactLink.fromJson(Map<String, dynamic> j) => ContactLink(
    id: j['id'] as String? ?? '',
    kind: j['kind'] as String? ?? 'other',
    label: j['label'] as String? ?? '',
    value: j['value'] as String? ?? '',
    url: j['url'] as String? ?? '',
    clicksCount: j['clicksCount'] as int? ?? 0,
    hidden: j['hidden'] as bool? ?? false,
    hiddenReason: j['hiddenReason'] as String? ?? '',
  );

  static List<ContactLink> listFromJson(Object? list) => [
    for (final e in list as List? ?? const [])
      ContactLink.fromJson(e as Map<String, dynamic>),
  ];

  final String id;
  final String kind;
  final String label;
  final String value;
  final String url;
  final int clicksCount;
  final bool hidden;
  final String hiddenReason;

  String get title => label.isNotEmpty ? label : contactKindLabel(kind);

  Map<String, dynamic> toJson() => {
    if (id.isNotEmpty) 'id': id,
    'kind': kind,
    'label': label,
    'value': value,
  };

  ContactLink copyWith({String? kind, String? label, String? value}) =>
      ContactLink(
        id: id,
        kind: kind ?? this.kind,
        label: label ?? this.label,
        value: value ?? this.value,
        url: url,
        clicksCount: clicksCount,
        hidden: hidden,
        hiddenReason: hiddenReason,
      );
}

/// Tarjeta que edita el dueño (`GET/PUT /me/contact`).
class ContactCard {
  const ContactCard({
    this.enabled = false,
    this.title = '',
    this.intro = '',
    this.phone = '',
    this.phonePublic = false,
    this.email = '',
    this.emailPublic = false,
    this.website = '',
    this.websitePublic = false,
    this.viewsCount = 0,
    this.savesCount = 0,
    this.links = const [],
  });

  factory ContactCard.fromJson(Map<String, dynamic> j) => ContactCard(
    enabled: j['enabled'] as bool? ?? false,
    title: j['title'] as String? ?? '',
    intro: j['intro'] as String? ?? '',
    phone: j['phone'] as String? ?? '',
    phonePublic: j['phonePublic'] as bool? ?? false,
    email: j['email'] as String? ?? '',
    emailPublic: j['emailPublic'] as bool? ?? false,
    website: j['website'] as String? ?? '',
    websitePublic: j['websitePublic'] as bool? ?? false,
    viewsCount: j['viewsCount'] as int? ?? 0,
    savesCount: j['savesCount'] as int? ?? 0,
    links: ContactLink.listFromJson(j['links']),
  );

  final bool enabled;
  final String title;
  final String intro;
  final String phone;
  final bool phonePublic;
  final String email;
  final bool emailPublic;
  final String website;
  final bool websitePublic;
  final int viewsCount;
  final int savesCount;
  final List<ContactLink> links;

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'title': title,
    'intro': intro,
    'phone': phone,
    'phonePublic': phonePublic,
    'email': email,
    'emailPublic': emailPublic,
    'website': website,
    'websitePublic': websitePublic,
    'links': [for (final l in links) l.toJson()],
  };
}

/// Política de la organización: módulo activo y redes permitidas (vacío = todas).
class ContactPolicy {
  const ContactPolicy({this.enabled = true, this.linkKinds = const []});

  factory ContactPolicy.fromJson(Map<String, dynamic> j) => ContactPolicy(
    enabled: j['enabled'] as bool? ?? true,
    linkKinds: [for (final k in j['linkKinds'] as List? ?? const []) '$k'],
  );

  final bool enabled;
  final List<String> linkKinds;

  bool allows(String kind) => linkKinds.isEmpty || linkKinds.contains(kind);
}

class ContactState {
  const ContactState({
    required this.card,
    required this.policy,
    required this.partner,
    required this.organization,
  });

  factory ContactState.fromJson(Map<String, dynamic> j) => ContactState(
    card: ContactCard.fromJson(j['card'] as Map<String, dynamic>? ?? const {}),
    policy: ContactPolicy.fromJson(
      j['policy'] as Map<String, dynamic>? ?? const {},
    ),
    partner: j['partner'] as bool? ?? false,
    organization: j['organization'] as String? ?? '',
  );

  final ContactCard card;
  final ContactPolicy policy;
  final bool partner;
  final String organization;
}

/// Lo que ve otra persona en un perfil: solo los datos marcados como públicos.
class ContactPublic {
  const ContactPublic({
    required this.title,
    required this.intro,
    required this.phone,
    required this.email,
    required this.website,
    required this.organization,
    required this.links,
  });

  factory ContactPublic.fromJson(Map<String, dynamic> j) => ContactPublic(
    title: j['title'] as String? ?? '',
    intro: j['intro'] as String? ?? '',
    phone: j['phone'] as String? ?? '',
    email: j['email'] as String? ?? '',
    website: j['website'] as String? ?? '',
    organization: j['organization'] as String? ?? '',
    links: ContactLink.listFromJson(j['links']),
  );

  final String title;
  final String intro;
  final String phone;
  final String email;
  final String website;
  final String organization;
  final List<ContactLink> links;

  /// Hay datos para una tarjeta digital (el QR necesita al menos un dato de contacto).
  bool get hasCard =>
      phone.isNotEmpty || email.isNotEmpty || website.isNotEmpty;
}
