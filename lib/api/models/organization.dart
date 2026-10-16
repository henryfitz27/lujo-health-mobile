/// Organización (empresa contratante, v2 §2): identidad visual, módulos de la barra
/// inferior, políticas e integraciones.
class OrganizationModule {
  const OrganizationModule({
    required this.key,
    required this.name,
    required this.enabled,
  });

  factory OrganizationModule.fromJson(Map<String, dynamic> json) =>
      OrganizationModule(
        key: json['key'] as String,
        name: json['name'] as String? ?? '',
        enabled: json['enabled'] as bool? ?? false,
      );

  final String
  key; // media | learning | community | notebook | wellness | commerce
  final String name;
  final bool enabled;
}

class Organization {
  const Organization({
    required this.id,
    required this.slug,
    required this.name,
    required this.tagline,
    required this.logoUrl,
    required this.primaryColor,
    required this.secondaryColor,
    required this.modules,
    required this.accessMode,
    required this.publishingModel,
    required this.lmsBaseUrl,
    required this.lmsResource,
    required this.lmsWebUrl,
    required this.lmsOrganizationSlug,
    required this.businessUrl,
    required this.storeUrl,
    required this.supportEmail,
    required this.isDefault,
  });

  factory Organization.fromJson(Map<String, dynamic> json) {
    final theme = json['theme'] as Map<String, dynamic>? ?? const {};
    final integrations =
        json['integrations'] as Map<String, dynamic>? ?? const {};
    return Organization(
      id: json['id'] as String,
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? '',
      tagline: json['tagline'] as String? ?? '',
      logoUrl: json['logoUrl'] as String? ?? '',
      primaryColor: theme['primary'] as String? ?? '',
      secondaryColor: theme['secondary'] as String? ?? '',
      modules: [
        for (final m in json['modules'] as List? ?? const [])
          OrganizationModule.fromJson(m as Map<String, dynamic>),
      ],
      accessMode: json['accessMode'] as String? ?? 'public',
      publishingModel: json['publishingModel'] as String? ?? 'community',
      lmsBaseUrl: integrations['lmsBaseUrl'] as String? ?? '',
      lmsResource: integrations['lmsResource'] as String? ?? '',
      lmsWebUrl: integrations['lmsWebUrl'] as String? ?? '',
      lmsOrganizationSlug: integrations['lmsOrganizationSlug'] as String? ?? '',
      businessUrl: integrations['businessUrl'] as String? ?? '',
      storeUrl: integrations['storeUrl'] as String? ?? '',
      supportEmail: integrations['supportEmail'] as String? ?? '',
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }

  final String id;
  final String slug;
  final String name;
  final String tagline;
  final String logoUrl;
  final String primaryColor;
  final String secondaryColor;
  final List<OrganizationModule> modules;
  final String accessMode;
  final String publishingModel;
  final String lmsBaseUrl;
  final String lmsResource;
  final String lmsWebUrl;
  final String lmsOrganizationSlug;
  final String businessUrl;
  final String storeUrl;
  final String supportEmail;
  final bool isDefault;

  /// Módulos activos en el orden de la barra inferior (el cuaderno siempre está).
  List<OrganizationModule> get enabledModules =>
      modules.where((m) => m.enabled || m.key == 'notebook').toList();

  OrganizationModule? module(String key) {
    for (final m in modules) {
      if (m.key == key) return m;
    }
    return null;
  }

  String moduleName(String key, String fallback) {
    final m = module(key);
    return m == null || m.name.isEmpty ? fallback : m.name;
  }

  bool isEnabled(String key) =>
      key == 'notebook' || (module(key)?.enabled ?? false);
}

class OrganizationSummary {
  const OrganizationSummary({
    required this.id,
    required this.slug,
    required this.name,
    required this.logoUrl,
    required this.role,
  });

  factory OrganizationSummary.fromJson(Map<String, dynamic> json) =>
      OrganizationSummary(
        id: json['id'] as String,
        slug: json['slug'] as String? ?? '',
        name: json['name'] as String? ?? '',
        logoUrl: json['logoUrl'] as String? ?? '',
        role: json['role'] as String? ?? '',
      );

  static List<OrganizationSummary> listFromJson(Object? list) => [
    for (final item in list as List? ?? const [])
      OrganizationSummary.fromJson(item as Map<String, dynamic>),
  ];

  final String id;
  final String slug;
  final String name;
  final String logoUrl;
  final String role;
}
