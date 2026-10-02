import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../di/restaurant_providers.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/restaurant_model.dart';
import '../../../data/models/food_model.dart';
import '../../../domain/repository/restaurant_repository.dart';
import 'zone_viewmodel.dart';

class HomeState {
  final AsyncValue<List<CategoryModel>> categories;
  final AsyncValue<List<FoodModel>> popularFoods;
  final AsyncValue<List<FoodModel>> bestOffers;
  final AsyncValue<List<RestaurantModel>> nearbyRestaurants;

  HomeState({
    required this.categories,
    required this.popularFoods,
    required this.bestOffers,
    required this.nearbyRestaurants,
  });

  HomeState copyWith({
    AsyncValue<List<CategoryModel>>? categories,
    AsyncValue<List<FoodModel>>? popularFoods,
    AsyncValue<List<FoodModel>>? bestOffers,
    AsyncValue<List<RestaurantModel>>? nearbyRestaurants,
  }) {
    return HomeState(
      categories: categories ?? this.categories,
      popularFoods: popularFoods ?? this.popularFoods,
      bestOffers: bestOffers ?? this.bestOffers,
      nearbyRestaurants: nearbyRestaurants ?? this.nearbyRestaurants,
    );
  }
}

final homeViewModelProvider = NotifierProvider<HomeViewModel, HomeState>(() {
  return HomeViewModel();
});

class HomeViewModel extends Notifier<HomeState> {
  late final RestaurantRepository _repository;

  @override
  HomeState build() {
    _repository = ref.watch(restaurantRepositoryProvider);

    ref.listen(currentZoneIdProvider, (previous, next) {
      if (previous != next) {
        unawaited(loadHomeData(isRefresh: true));
      }
    });

    ref.listen(zoneViewModelProvider, (previous, next) {
      final prevInService = previous?.value?.isInService;
      final nextInService = next.value?.isInService;
      if (prevInService != nextInService) {
        unawaited(loadHomeData(isRefresh: true));
      }
    });

    Future.microtask(() => loadHomeData());
    return HomeState(
      categories: const AsyncValue.loading(),
      popularFoods: const AsyncValue.loading(),
      bestOffers: const AsyncValue.loading(),
      nearbyRestaurants: const AsyncValue.loading(),
    );
  }

  Future<void> loadHomeData({bool isRefresh = false}) async {
    final zone = ref.read(zoneViewModelProvider).value;
    if (zone != null && !zone.isInService) {
      state = state.copyWith(
        categories: const AsyncValue.data([]),
        popularFoods: const AsyncValue.data([]),
        bestOffers: const AsyncValue.data([]),
        nearbyRestaurants: const AsyncValue.data([]),
      );
      return;
    }

    if (!isRefresh) {
      state = state.copyWith(
        categories: const AsyncValue.loading(),
        popularFoods: const AsyncValue.loading(),
        bestOffers: const AsyncValue.loading(),
        nearbyRestaurants: const AsyncValue.loading(),
      );
    }

    // Each onCache fires synchronously, right here, with whatever's still
    // cached from the last fetch — paints the screen instantly instead of a
    // spinner, and gets overwritten below once the live response lands.
    final responses = await Future.wait([
      _repository.getCategories(
        onCache: (c) => state = state.copyWith(categories: AsyncValue.data(c)),
      ),
      _repository.getPopularFoods(
        onCache: (f) => state = state.copyWith(popularFoods: AsyncValue.data(f)),
      ),
      _repository.getBestOffers(
        onCache: (f) => state = state.copyWith(bestOffers: AsyncValue.data(f)),
      ),
      _repository.getPopularRestaurants(
        onCache: (r) => state = state.copyWith(nearbyRestaurants: AsyncValue.data(r)),
      ), // mapping popular to nearby
    ]);

    final categoriesRes = responses[0] as dynamic; 
    final popularFoodsRes = responses[1] as dynamic;
    final bestOffersRes = responses[2] as dynamic;
    final nearbyRes = responses[3] as dynamic;

    state = state.copyWith(
      categories: categoriesRes.isSuccess 
          ? AsyncValue.data(categoriesRes.data) 
          : AsyncValue.error(categoriesRes.message, StackTrace.current),
      popularFoods: popularFoodsRes.isSuccess 
          ? AsyncValue.data(popularFoodsRes.data) 
          : AsyncValue.error(popularFoodsRes.message, StackTrace.current),
      bestOffers: bestOffersRes.isSuccess 
          ? AsyncValue.data(bestOffersRes.data) 
          : AsyncValue.error(bestOffersRes.message, StackTrace.current),
      nearbyRestaurants: nearbyRes.isSuccess 
          ? AsyncValue.data(nearbyRes.data) 
          : AsyncValue.error(nearbyRes.message, StackTrace.current),
    );
  }
}
