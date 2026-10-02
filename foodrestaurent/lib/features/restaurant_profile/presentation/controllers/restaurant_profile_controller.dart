import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:food_user_application/features/auth/domain/restaurant_model.dart';
import 'package:food_user_application/features/restaurant_profile/data/restaurant_repository.dart';

/// Single cached source of the restaurant's own profile — every Explore
/// screen that needs restaurant data (outlet info, status, delivery
/// settings, bank details, zone setup) watches this instead of fetching on
/// its own.
class RestaurantProfileController extends AsyncNotifier<RestaurantModel> {
  @override
  Future<RestaurantModel> build() {
    return ref.read(restaurantRepositoryProvider).getCurrent();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(restaurantRepositoryProvider).getCurrent(),
    );
  }

  /// Throws on failure — callers should catch and surface the message,
  /// rather than have it silently swallowed into an error state.
  Future<void> updateProfile(Map<String, dynamic> patch) async {
    final updated = await ref
        .read(restaurantRepositoryProvider)
        .updateProfile(patch);
    state = AsyncValue.data(updated);
  }

  Future<void> updateAvailability(bool isAcceptingOrders) async {
    final updated = await ref
        .read(restaurantRepositoryProvider)
        .updateAvailability(isAcceptingOrders);
    state = AsyncValue.data(updated);
  }

  /// Resets approval status to `pending` server-side — caller must warn the
  /// owner before invoking this on an already-approved restaurant.
  Future<void> uploadProfileImage(XFile file) async {
    await ref.read(restaurantRepositoryProvider).uploadProfileImage(file);
    await refresh();
  }
}

final restaurantProfileControllerProvider =
    AsyncNotifierProvider<RestaurantProfileController, RestaurantModel>(
      RestaurantProfileController.new,
    );
