class CatalogItem {
  const CatalogItem({
    required this.id,
    required this.key,
    required this.name,
    required this.sortOrder,
    required this.active,
  });

  final int id;
  final String key;
  final String name;
  final int sortOrder;
  final bool active;

  factory CatalogItem.fromJson(Map<String, dynamic> json) => CatalogItem(
    id: json['id'] as int,
    key: json['key'] as String,
    name: json['name'] as String,
    sortOrder: json['sortOrder'] as int? ?? 0,
    active: json['active'] as bool? ?? true,
  );

  static List<CatalogItem> listFromJson(dynamic json) =>
      (json as List<dynamic>? ?? const [])
          .map((e) => CatalogItem.fromJson(e as Map<String, dynamic>))
          .toList();
}

class Catalogs {
  const Catalogs({
    required this.interests,
    required this.dietaryPreferences,
    required this.allergens,
  });

  final List<CatalogItem> interests;
  final List<CatalogItem> dietaryPreferences;
  final List<CatalogItem> allergens;

  factory Catalogs.fromJson(Map<String, dynamic> json) => Catalogs(
    interests: CatalogItem.listFromJson(json['interests']),
    dietaryPreferences: CatalogItem.listFromJson(json['dietaryPreferences']),
    allergens: CatalogItem.listFromJson(json['allergens']),
  );
}
