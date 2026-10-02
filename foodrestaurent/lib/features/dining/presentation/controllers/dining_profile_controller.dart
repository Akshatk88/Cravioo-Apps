import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/features/dining/data/dining_repository.dart';
import 'package:food_user_application/features/dining/domain/dining_profile_model.dart';

class DiningProfileController extends AsyncNotifier<DiningProfileResponse> {
  @override
  Future<DiningProfileResponse> build() {
    return ref.read(diningRepositoryProvider).getMyProfile();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(diningRepositoryProvider).getMyProfile(),
    );
  }

  Future<DiningProfileModel?> submitProfile(FormData formData) async {
    try {
      final res = await ref.read(diningRepositoryProvider).submitProfile(formData);
      await refresh();
      return res;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> updateSettings(Map<String, dynamic> settings) async {
    final current = state.value;
    if (current != null && current.profile != null && settings.containsKey('isOnline')) {
      final updatedProfile = DiningProfileModel(
        id: current.profile!.id,
        restaurantId: current.profile!.restaurantId,
        restaurantName: current.profile!.restaurantName,
        status: current.profile!.status,
        about: current.profile!.about,
        categories: current.profile!.categories,
        cuisines: current.profile!.cuisines,
        amenities: current.profile!.amenities,
        costForTwo: current.profile!.costForTwo,
        seatingCapacity: current.profile!.seatingCapacity,
        contactName: current.profile!.contactName,
        contactPhone: current.profile!.contactPhone,
        coverImage: current.profile!.coverImage,
        gallery: current.profile!.gallery,
        menuImages: current.profile!.menuImages,
        rejectionReason: current.profile!.rejectionReason,
        isOnline: settings['isOnline'] == true,
        autoConfirm: current.profile!.autoConfirm,
      );
      state = AsyncValue.data(
        DiningProfileResponse(
          profile: updatedProfile,
          availableCategories: current.availableCategories,
        ),
      );
    }
    try {
      await ref.read(diningRepositoryProvider).updateSettings(settings);
      await refresh();
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      await refresh();
      return false;
    }
  }
}

final diningProfileControllerProvider =
    AsyncNotifierProvider<DiningProfileController, DiningProfileResponse>(
  DiningProfileController.new,
);
