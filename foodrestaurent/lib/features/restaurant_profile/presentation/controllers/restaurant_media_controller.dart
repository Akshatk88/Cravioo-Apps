import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:food_user_application/features/restaurant_profile/data/restaurant_repository.dart';
import 'package:food_user_application/features/restaurant_profile/domain/restaurant_media_model.dart';

class RestaurantMediaController extends AsyncNotifier<RestaurantMediaModel> {
  @override
  Future<RestaurantMediaModel> build() async {
    final data = await ref.read(restaurantRepositoryProvider).getMedia();
    return RestaurantMediaModel.fromJson(data);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final data = await ref.read(restaurantRepositoryProvider).getMedia();
      return RestaurantMediaModel.fromJson(data);
    });
  }

  Future<void> uploadCoverImage(XFile file) async {
    final data = await ref.read(restaurantRepositoryProvider).uploadCoverImage(file);
    state = AsyncValue.data(RestaurantMediaModel.fromJson(data));
  }

  Future<void> uploadGalleryImages(List<XFile> files) async {
    final data = await ref.read(restaurantRepositoryProvider).uploadGalleryImages(files);
    state = AsyncValue.data(RestaurantMediaModel.fromJson(data));
  }

  Future<void> deleteGalleryImage(String imageUrl) async {
    final data = await ref.read(restaurantRepositoryProvider).deleteGalleryImage(imageUrl);
    state = AsyncValue.data(RestaurantMediaModel.fromJson(data));
  }
}

final restaurantMediaControllerProvider =
    AsyncNotifierProvider<RestaurantMediaController, RestaurantMediaModel>(
  RestaurantMediaController.new,
);
