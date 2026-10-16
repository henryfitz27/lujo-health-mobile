import 'catalog_item.dart';
import 'post.dart';
import 'profile.dart';

class RecipeCategory {
  const RecipeCategory({
    required this.id,
    required this.key,
    required this.name,
    required this.kind,
    required this.requiresReview,
  });

  factory RecipeCategory.fromJson(Map<String, dynamic> json) => RecipeCategory(
    id: json['id'] as int,
    key: json['key'] as String,
    name: json['name'] as String,
    kind: json['kind'] as String? ?? 'meal',
    requiresReview: json['requiresReview'] as bool? ?? false,
  );

  static List<RecipeCategory> listFromJson(Object? items) => [
    for (final i in (items as List<dynamic>? ?? const []))
      RecipeCategory.fromJson(i as Map<String, dynamic>),
  ];

  final int id;
  final String key;
  final String name;
  final String kind;
  final bool requiresReview;
}

class RecipeIngredient {
  const RecipeIngredient({
    required this.id,
    required this.ingredientId,
    required this.ingredientSlug,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.note,
    required this.substitutions,
    required this.optional,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) =>
      RecipeIngredient(
        id: json['id'] as int? ?? 0,
        ingredientId: json['ingredientId'] as int?,
        ingredientSlug: json['ingredientSlug'] as String? ?? '',
        name: json['name'] as String,
        quantity: (json['quantity'] as num?)?.toDouble(),
        unit: json['unit'] as String? ?? '',
        note: json['note'] as String? ?? '',
        substitutions: json['substitutions'] as String? ?? '',
        optional: json['optional'] as bool? ?? false,
      );

  final int id;
  final int? ingredientId;
  final String ingredientSlug;
  final String name;
  final double? quantity;
  final String unit;
  final String note;
  final String substitutions;
  final bool optional;

  /// «150 g» / «1.5 l» / «» para escalar en cliente sin pedir a la API.
  String amount([double factor = 1]) {
    final q = quantity;
    if (q == null) return '';
    final v = q * factor;
    final text = v >= 100
        ? v.round().toString()
        : v >= 10
        ? (v * 10).round() / 10 == v.roundToDouble()
              ? v.round().toString()
              : ((v * 10).round() / 10).toString()
        : v == v.roundToDouble()
        ? v.round().toString()
        : ((v * 100).round() / 100).toString();
    return unit.isEmpty ? text : '$text $unit';
  }
}

class RecipeStep {
  const RecipeStep({
    required this.id,
    required this.text,
    required this.durationSeconds,
    required this.media,
  });

  factory RecipeStep.fromJson(Map<String, dynamic> json) => RecipeStep(
    id: json['id'] as int? ?? 0,
    text: json['text'] as String,
    durationSeconds: json['durationSeconds'] as int? ?? 0,
    media: json['media'] is Map<String, dynamic>
        ? PostMedia.fromJson(json['media'] as Map<String, dynamic>)
        : null,
  );

  final int id;
  final String text;
  final int durationSeconds;
  final PostMedia? media;
}

class RecipeSummary {
  const RecipeSummary({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.status,
    required this.reviewStatus,
    required this.servings,
    required this.totalMinutes,
    required this.difficulty,
    required this.ratingsCount,
    required this.clarityAvg,
    required this.author,
  });

  factory RecipeSummary.fromJson(Map<String, dynamic> json) => RecipeSummary(
    id: json['id'] as String,
    title: json['title'] as String,
    coverUrl: json['coverUrl'] as String? ?? '',
    status: json['status'] as String? ?? 'published',
    reviewStatus: json['reviewStatus'] as String? ?? 'none',
    servings: json['servings'] as int? ?? 0,
    totalMinutes: json['totalMinutes'] as int? ?? 0,
    difficulty: json['difficulty'] as String? ?? 'easy',
    ratingsCount: json['ratingsCount'] as int? ?? 0,
    clarityAvg: (json['clarityAvg'] as num?)?.toDouble() ?? 0,
    author: ProfileSummary.fromJson(json['author'] as Map<String, dynamic>),
  );

  static List<RecipeSummary> listFromJson(Object? items) => [
    for (final i in (items as List<dynamic>? ?? const []))
      RecipeSummary.fromJson(i as Map<String, dynamic>),
  ];

  final String id;
  final String title;
  final String coverUrl;
  final String status;
  final String reviewStatus;
  final int servings;
  final int totalMinutes;
  final String difficulty;
  final int ratingsCount;
  final double clarityAvg;
  final ProfileSummary author;
}

class Recipe {
  const Recipe({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.reviewStatus,
    required this.reviewNote,
    required this.servings,
    required this.prepMinutes,
    required this.cookMinutes,
    required this.difficulty,
    required this.cover,
    required this.video,
    required this.utensils,
    required this.tags,
    required this.nutrition,
    required this.nutritionSource,
    required this.nutritionBasis,
    required this.removedReason,
    required this.ratingsCount,
    required this.clarityAvg,
    required this.easeAvg,
    required this.savesCount,
    required this.author,
    required this.parent,
    required this.categories,
    required this.dietaryPreferences,
    required this.allergens,
    required this.ingredients,
    required this.steps,
    required this.saved,
    required this.myClarity,
    required this.myEase,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    final viewer = json['viewer'] as Map<String, dynamic>? ?? const {};
    return Recipe(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'published',
      reviewStatus: json['reviewStatus'] as String? ?? 'none',
      reviewNote: json['reviewNote'] as String? ?? '',
      servings: json['servings'] as int? ?? 1,
      prepMinutes: json['prepMinutes'] as int? ?? 0,
      cookMinutes: json['cookMinutes'] as int? ?? 0,
      difficulty: json['difficulty'] as String? ?? 'easy',
      cover: json['cover'] is Map<String, dynamic>
          ? PostMedia.fromJson(json['cover'] as Map<String, dynamic>)
          : null,
      video: json['video'] is Map<String, dynamic>
          ? PostMedia.fromJson(json['video'] as Map<String, dynamic>)
          : null,
      utensils: [
        for (final u in (json['utensils'] as List<dynamic>? ?? const []))
          u as String,
      ],
      tags: [
        for (final t in (json['tags'] as List<dynamic>? ?? const []))
          t as String,
      ],
      nutrition: (json['nutrition'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ),
      nutritionSource: json['nutritionSource'] as String? ?? '',
      nutritionBasis: json['nutritionBasis'] as String? ?? '',
      removedReason: json['removedReason'] as String? ?? '',
      ratingsCount: json['ratingsCount'] as int? ?? 0,
      clarityAvg: (json['clarityAvg'] as num?)?.toDouble() ?? 0,
      easeAvg: (json['easeAvg'] as num?)?.toDouble() ?? 0,
      savesCount: json['savesCount'] as int? ?? 0,
      author: ProfileSummary.fromJson(json['author'] as Map<String, dynamic>),
      parent: json['parent'] is Map<String, dynamic>
          ? RecipeSummary.fromJson(json['parent'] as Map<String, dynamic>)
          : null,
      categories: RecipeCategory.listFromJson(json['categories']),
      dietaryPreferences: CatalogItem.listFromJson(json['dietaryPreferences']),
      allergens: CatalogItem.listFromJson(json['allergens']),
      ingredients: [
        for (final i in (json['ingredients'] as List<dynamic>? ?? const []))
          RecipeIngredient.fromJson(i as Map<String, dynamic>),
      ],
      steps: [
        for (final s in (json['steps'] as List<dynamic>? ?? const []))
          RecipeStep.fromJson(s as Map<String, dynamic>),
      ],
      saved: viewer['saved'] as bool? ?? false,
      myClarity: viewer['clarity'] as int? ?? 0,
      myEase: viewer['ease'] as int? ?? 0,
    );
  }

  final String id;
  final String title;
  final String description;
  final String status;
  final String reviewStatus;
  final String reviewNote;
  final int servings;
  final int prepMinutes;
  final int cookMinutes;
  final String difficulty;
  final PostMedia? cover;
  final PostMedia? video;
  final List<String> utensils;
  final List<String> tags;
  final Map<String, double>? nutrition;
  final String nutritionSource;
  final String nutritionBasis;
  final String removedReason;
  final int ratingsCount;
  final double clarityAvg;
  final double easeAvg;
  final int savesCount;
  final ProfileSummary author;
  final RecipeSummary? parent;
  final List<RecipeCategory> categories;
  final List<CatalogItem> dietaryPreferences;
  final List<CatalogItem> allergens;
  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> steps;
  final bool saved;
  final int myClarity;
  final int myEase;

  int get totalMinutes => prepMinutes + cookMinutes;
  bool get awaitingReview =>
      reviewStatus == 'pending' || reviewStatus == 'in_review';
}

class IngredientSummary {
  const IngredientSummary({
    required this.id,
    required this.slug,
    required this.name,
    required this.imageUrl,
  });

  factory IngredientSummary.fromJson(Map<String, dynamic> json) =>
      IngredientSummary(
        id: json['id'] as int,
        slug: json['slug'] as String,
        name: json['name'] as String,
        imageUrl: json['imageUrl'] as String? ?? '',
      );

  static List<IngredientSummary> listFromJson(Object? items) => [
    for (final i in (items as List<dynamic>? ?? const []))
      IngredientSummary.fromJson(i as Map<String, dynamic>),
  ];

  final int id;
  final String slug;
  final String name;
  final String imageUrl;
}

class Reference {
  const Reference({required this.title, required this.url, required this.year});

  factory Reference.fromJson(Map<String, dynamic> json) => Reference(
    title: json['title'] as String? ?? '',
    url: json['url'] as String? ?? '',
    year: json['year'] as int? ?? 0,
  );

  final String title;
  final String url;
  final int year;
}

class Ingredient {
  const Ingredient({
    required this.id,
    required this.slug,
    required this.name,
    required this.otherNames,
    required this.scientificName,
    required this.description,
    required this.origin,
    required this.partUsed,
    required this.presentations,
    required this.culinaryUses,
    required this.nutrition,
    required this.traditionalUse,
    required this.evidence,
    required this.evidenceLimits,
    required this.precautions,
    required this.references,
    required this.imageUrl,
    required this.reviewedAt,
    required this.reviewer,
    required this.allergens,
    required this.recipesCount,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) => Ingredient(
    id: json['id'] as int,
    slug: json['slug'] as String,
    name: json['name'] as String,
    otherNames: [
      for (final n in (json['otherNames'] as List<dynamic>? ?? const []))
        n as String,
    ],
    scientificName: json['scientificName'] as String? ?? '',
    description: json['description'] as String? ?? '',
    origin: json['origin'] as String? ?? '',
    partUsed: json['partUsed'] as String? ?? '',
    presentations: json['presentations'] as String? ?? '',
    culinaryUses: json['culinaryUses'] as String? ?? '',
    nutrition: json['nutrition'] as String? ?? '',
    traditionalUse: json['traditionalUse'] as String? ?? '',
    evidence: json['evidence'] as String? ?? '',
    evidenceLimits: json['evidenceLimits'] as String? ?? '',
    precautions: json['precautions'] as String? ?? '',
    references: [
      for (final r in (json['references'] as List<dynamic>? ?? const []))
        Reference.fromJson(r as Map<String, dynamic>),
    ],
    imageUrl: json['imageUrl'] as String? ?? '',
    reviewedAt: json['reviewedAt'] is String
        ? DateTime.tryParse(json['reviewedAt'] as String)
        : null,
    reviewer: json['reviewer'] is Map<String, dynamic>
        ? ProfileSummary.fromJson(json['reviewer'] as Map<String, dynamic>)
        : null,
    allergens: CatalogItem.listFromJson(json['allergens']),
    recipesCount: json['recipesCount'] as int? ?? 0,
  );

  final int id;
  final String slug;
  final String name;
  final List<String> otherNames;
  final String scientificName;
  final String description;
  final String origin;
  final String partUsed;
  final String presentations;
  final String culinaryUses;
  final String nutrition;
  final String traditionalUse;
  final String evidence;
  final String evidenceLimits;
  final String precautions;
  final List<Reference> references;
  final String imageUrl;
  final DateTime? reviewedAt;
  final ProfileSummary? reviewer;
  final List<CatalogItem> allergens;
  final int recipesCount;
}

class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.recipeId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.checked,
  });

  factory ShoppingItem.fromJson(Map<String, dynamic> json) => ShoppingItem(
    id: json['id'] as int,
    recipeId: json['recipeId'] as String?,
    name: json['name'] as String,
    quantity: (json['quantity'] as num?)?.toDouble(),
    unit: json['unit'] as String? ?? '',
    checked: json['checked'] as bool? ?? false,
  );

  static List<ShoppingItem> listFromJson(Object? items) => [
    for (final i in (items as List<dynamic>? ?? const []))
      ShoppingItem.fromJson(i as Map<String, dynamic>),
  ];

  final int id;
  final String? recipeId;
  final String name;
  final double? quantity;
  final String unit;
  final bool checked;

  String get amount {
    final q = quantity;
    if (q == null) return '';
    final text = q == q.roundToDouble()
        ? q.round().toString()
        : q.toStringAsFixed(2);
    return unit.isEmpty ? text : '$text $unit';
  }
}

class SearchResults {
  const SearchResults({
    required this.recipes,
    required this.ingredients,
    required this.posts,
    required this.people,
  });

  factory SearchResults.fromJson(Map<String, dynamic> json) => SearchResults(
    recipes: RecipeSummary.listFromJson(json['recipes']),
    ingredients: IngredientSummary.listFromJson(json['ingredients']),
    posts: Post.listFromJson(json['posts']),
    people: ProfileSummary.listFromJson(json['people']),
  );

  final List<RecipeSummary> recipes;
  final List<IngredientSummary> ingredients;
  final List<Post> posts;
  final List<ProfileSummary> people;

  bool get isEmpty =>
      recipes.isEmpty && ingredients.isEmpty && posts.isEmpty && people.isEmpty;
}
