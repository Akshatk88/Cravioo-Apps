import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';
import '../models/category_model.dart';
import '../models/food_model.dart';
import '../models/food_variant.dart';
import '../models/promo_banner_model.dart';
import '../models/restaurant_model.dart';
import '../models/zone_model.dart';

/// Transport for every public discovery endpoint: zones, banners, categories,
/// restaurants, menus, the cross-restaurant food feed, offers and search.
///
/// All of these are unauthenticated; the client still attaches a Bearer token
/// when one exists, which the offers endpoint uses to personalise results.
class CatalogRemoteDataSource {
  final ApiClient _client;

  const CatalogRemoteDataSource(this._client);

  /// Discovery content (banners, categories, restaurants, menus, feed) changes
  /// at most every few minutes, so it's safe to serve a short-lived cached
  /// copy instead of hitting the network on every screen visit.
  static const _cacheTtl = Duration(minutes: 3);

  // ------------------------------------------------------------------ zones

  Future<ZoneModel> detectZone({required double lat, required double lng}) async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiPaths.zoneDetect,
      query: {'lat': lat, 'lng': lng},
      auth: false,
    );
    return ZoneModel.fromApi(data);
  }

  // ----------------------------------------------------------------- home

  /// `GET /food/hero-banners/public` → `{ banners }`.
  /// Returned as [CategoryModel] because a banner renders as image + label,
  /// which is exactly what the existing carousels consume.
  Future<List<String>> getHeroBannerImages() async {
    final data = await _client.get<Map<String, dynamic>>(ApiPaths.heroBanners, auth: false, cacheTtl: _cacheTtl);
    return ((data['banners'] as List?) ?? const [])
        .whereType<Map>()
        .map((b) => ApiConfig.resolveMedia(b['imageUrl'] as String?))
        .where((url) => url.isNotEmpty)
        .toList();
  }

  /// Admin-managed promo banners for the home carousel.
  ///
  /// Banners without a usable image are dropped here rather than in the widget:
  /// an empty slide is worse than a shorter carousel, and the page-count dots
  /// would otherwise be wrong.
  Future<List<PromoBannerModel>> getPromoBanners({String? zoneId}) async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiPaths.promoBanners,
      query: {'zoneId': zoneId},
      auth: false,
      cacheTtl: _cacheTtl,
    );
    return ((data['banners'] as List?) ?? const [])
        .whereType<Map>()
        .map((b) => PromoBannerModel.fromApi(b.cast<String, dynamic>()))
        .where((b) => b.imageUrl.isNotEmpty)
        .toList();
  }

  List<CategoryModel> _deduplicateCategories(List<CategoryModel> list) {
    final seenIds = <String>{};
    final seenNames = <String>{};
    final result = <CategoryModel>[];
    for (final cat in list) {
      final idKey = cat.id.trim();
      final nameKey = cat.name.trim().toLowerCase();
      if (idKey.isNotEmpty && seenIds.contains(idKey)) continue;
      if (nameKey.isNotEmpty && seenNames.contains(nameKey)) continue;
      if (idKey.isNotEmpty) seenIds.add(idKey);
      if (nameKey.isNotEmpty) seenNames.add(nameKey);
      result.add(cat);
    }
    return result;
  }

  Future<List<CategoryModel>> getExploreIcons() async {
    final data = await _client.get<Map<String, dynamic>>(ApiPaths.exploreIcons, auth: false, cacheTtl: _cacheTtl);
    final raw = ((data['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => CategoryModel.fromApi(e.cast<String, dynamic>()))
        .toList();
    return _deduplicateCategories(raw);
  }

  Future<List<CategoryModel>> getCategories({
    String? zoneId,
    void Function(List<CategoryModel>)? onCache,
  }) async {
    List<CategoryModel> parse(Map<String, dynamic> data) {
      final raw = ((data['categories'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => CategoryModel.fromApi(e.cast<String, dynamic>()))
          .toList();
      return _deduplicateCategories(raw);
    }

    final data = await _client.get<Map<String, dynamic>>(
      ApiPaths.categories,
      query: {'zoneId': zoneId},
      auth: false,
      cacheTtl: _cacheTtl,
      onCache: onCache == null ? null : (cached) => onCache(parse(cached)),
    );
    return parse(data);
  }

  // ---------------------------------------------------------- restaurants

  Future<List<RestaurantModel>> getRestaurants({
    String? zoneId,
    double? lat,
    double? lng,
    double? radiusKm,
    String? cuisine,
    String? sortBy,
    int page = 1,
    int limit = 50,
    void Function(List<RestaurantModel>)? onCache,
  }) async {
    List<RestaurantModel> parse(Map<String, dynamic> data) => ((data['restaurants'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => RestaurantModel.fromApi(e.cast<String, dynamic>()))
        .toList();

    final data = await _client.get<Map<String, dynamic>>(
      ApiPaths.restaurants,
      query: {
        'page': page,
        'limit': limit,
        'zoneId': zoneId,
        'lat': lat,
        'lng': lng,
        'radiusKm': radiusKm,
        'cuisine': cuisine,
        'sortBy': sortBy,
      },
      auth: false,
      cacheTtl: _cacheTtl,
      onCache: onCache == null ? null : (cached) => onCache(parse(cached)),
    );
    return parse(data);
  }

  /// `GET /food/hero-banners/trending/public` - Trending Now rail (zone-filtered).
  Future<List<RestaurantModel>> getTrendingRestaurants({String? zoneId}) async {
    try {
      final dynamic raw = await _client.get<dynamic>(
        ApiPaths.trending,
        query: zoneId != null && zoneId.isNotEmpty ? {'zoneId': zoneId} : null,
        auth: false,
        cacheTtl: _cacheTtl,
      );
      final List? list = raw is Map
          ? ((raw['restaurants'] as List?) ?? (raw['data'] as List?))
          : (raw is List ? raw : null);
      return (list ?? const [])
          .whereType<Map>()
          .map((e) => RestaurantModel.fromApi(e.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// `GET /food/hero-banners/gourmet/public` - Top 10 Gourmet rail (zone-filtered).
  Future<List<RestaurantModel>> getGourmetRestaurants({String? zoneId}) async {
    try {
      final dynamic raw = await _client.get<dynamic>(
        ApiPaths.gourmet,
        query: zoneId != null && zoneId.isNotEmpty ? {'zoneId': zoneId} : null,
        auth: false,
        cacheTtl: _cacheTtl,
      );
      final List? list = raw is Map
          ? ((raw['restaurants'] as List?) ?? (raw['data'] as List?))
          : (raw is List ? raw : null);
      return (list ?? const [])
          .whereType<Map>()
          .map((e) => RestaurantModel.fromApi(e.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// `GET /food/restaurants/under-250` - Restaurants with offers/budget meals (zone-filtered).
  Future<List<RestaurantModel>> getOffersRestaurants({String? zoneId}) async {
    try {
      final dynamic raw = await _client.get<dynamic>(
        ApiPaths.under250Restaurants,
        query: zoneId != null && zoneId.isNotEmpty ? {'zoneId': zoneId} : null,
        auth: false,
        cacheTtl: _cacheTtl,
      );
      final List? list = raw is Map
          ? ((raw['restaurants'] as List?) ?? (raw['data'] as List?))
          : (raw is List ? raw : null);
      return (list ?? const [])
          .whereType<Map>()
          .map((e) => RestaurantModel.fromApi(e.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }


  /// [lat]/[lng] are optional but drive `distanceInKm` in the response — the
  /// backend has nothing to measure from without them, and the detail screen
  /// then shows 0.0 km. Same coordinates the list endpoint takes.
  Future<RestaurantModel?> getRestaurantById(String id, {double? lat, double? lng}) async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiPaths.restaurantById(id),
      query: {'lat': lat, 'lng': lng},
      auth: false,
      cacheTtl: _cacheTtl,
    );
    final dynamic raw = data['restaurant'] ??
        (data['data'] is Map ? data['data']['restaurant'] ?? data['data'] : null) ??
        data;
    if (raw is Map) {
      final map = raw.cast<String, dynamic>();
      if (map.containsKey('_id') || map.containsKey('id') || map.containsKey('name')) {
        return RestaurantModel.fromApi(map);
      }
    }
    return null;
  }

  /// `GET /restaurants/:id/menu` — flattened to the item list the menu screen
  /// consumes. Section grouping is derived client-side from `categoryName`,
  /// which every item carries.
  Future<List<FoodModel>> getRestaurantMenu(String restaurantId) async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiPaths.restaurantMenu(restaurantId),
      auth: false,
      cacheTtl: _cacheTtl,
    );
    final menu = data['menu'];
    if (menu is! Map) return const [];

    final items = <FoodModel>[];
    for (final section in (menu['sections'] as List?) ?? const []) {
      if (section is! Map) continue;
      for (final item in (section['items'] as List?) ?? const []) {
        if (item is Map) {
          items.add(FoodModel.fromApi(item.cast<String, dynamic>(), restaurantId: restaurantId));
        }
      }
    }
    return items;
  }

  /// Cross-restaurant dish feed. `promo` accepts `switch99` / `under-250`.
  Future<List<FoodModel>> getPublicFoods({
    String? zoneId,
    String? categorySlug,
    String? promo,
    int limit = 200,
    void Function(List<FoodModel>)? onCache,
  }) async {
    List<FoodModel> parse(Map<String, dynamic> data) => ((data['foods'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => FoodModel.fromApi(e.cast<String, dynamic>()))
        .toList();

    try {
      final data = await _client.get<Map<String, dynamic>>(
        ApiPaths.publicFoods,
        query: {'limit': limit, 'zoneId': zoneId, 'categorySlug': categorySlug, 'promo': promo},
        auth: false,
        cacheTtl: _cacheTtl,
        onCache: onCache == null ? null : (cached) => onCache(parse(cached)),
      );
      final foods = parse(data);
      if (foods.isNotEmpty) return foods;
    } catch (_) {}

    try {
      final underData = await _client.get<Map<String, dynamic>>(
        '/food/restaurant/restaurants/under-250',
        query: {'zoneId': zoneId},
        auth: false,
        cacheTtl: _cacheTtl,
      );
      final restaurants = ((underData['restaurants'] as List?) ?? const []).whereType<Map>();
      final fallbackFoods = <FoodModel>[];
      for (final r in restaurants) {
        final restId = r['id']?.toString() ?? r['restaurantId']?.toString() ?? '';
        final restName = r['name']?.toString() ?? '';
        final items = ((r['menuItems'] as List?) ?? const []).whereType<Map>();
        for (final item in items) {
          final itemMap = Map<String, dynamic>.from(item);
          itemMap['restaurantId'] ??= restId;
          itemMap['restaurantName'] ??= restName;
          fallbackFoods.add(FoodModel.fromApi(itemMap));
        }
      }
      return fallbackFoods;
    } catch (_) {
      return const [];
    }
  }

  /// `GET /restaurants/:id/addons` → `{ addons }`.
  ///
  /// Add-ons are restaurant-scoped, not per-dish: the same list applies to
  /// every item on that menu. Only approved + available ones are returned.
  Future<List<FoodAddon>> getAddons(String restaurantId) async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiPaths.restaurantAddons(restaurantId),
      auth: false,
    );
    return ((data['addons'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => FoodAddon.fromApi(e.cast<String, dynamic>()))
        .where((a) => a.name.isNotEmpty)
        .toList();
  }

  // --------------------------------------------------------------- search

  Future<List<RestaurantModel>> search(
    String query, {
    String? zoneId,
    double? lat,
    double? lng,
    int page = 1,
    int limit = 20,
  }) async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiPaths.searchUnified,
      query: {
        'q': query,
        'zoneId': zoneId,
        'lat': lat,
        'lng': lng,
        'page': page,
        'limit': limit,
      },
      auth: false,
    );
    return ((data['restaurants'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => RestaurantModel.fromApi(e.cast<String, dynamic>()))
        .toList();
  }

  // --------------------------------------------------------------- offers

  /// Raw offer maps — the backend prebuilds `title`, so the UI just renders it.
  /// Sending the Bearer token (default) filters out coupons the user has
  /// exhausted.
  Future<List<Map<String, dynamic>>> getOffers({String? restaurantId, num? subtotal}) async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiPaths.offers,
      query: {'restaurantId': restaurantId, 'subtotal': subtotal},
    );
    return ((data['allOffers'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }
}
