import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:food_user_application/features/advertisements/data/advertisement_repository.dart';
import 'package:food_user_application/features/advertisements/domain/advertisement_model.dart';

class AdvertisementController extends AsyncNotifier<List<AdvertisementModel>> {
  @override
  Future<List<AdvertisementModel>> build() {
    return ref.read(advertisementRepositoryProvider).list();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(advertisementRepositoryProvider).list(),
    );
  }

  Future<void> create({
    required String title,
    required String description,
    required String adsType,
    required String validity,
    required String fileDescription,
    required String videoDescription,
    XFile? image,
    XFile? video,
  }) async {
    await ref
        .read(advertisementRepositoryProvider)
        .create(
          title: title,
          description: description,
          adsType: adsType,
          validity: validity,
          fileDescription: fileDescription,
          videoDescription: videoDescription,
          image: image,
          video: video,
        );
    await refresh();
  }

  Future<void> updateAd(
    String id, {
    required String title,
    required String description,
    required String adsType,
    required String validity,
    required String fileDescription,
    required String videoDescription,
    XFile? image,
    XFile? video,
  }) async {
    await ref
        .read(advertisementRepositoryProvider)
        .update(
          id,
          title: title,
          description: description,
          adsType: adsType,
          validity: validity,
          fileDescription: fileDescription,
          videoDescription: videoDescription,
          image: image,
          video: video,
        );
    await refresh();
  }

  Future<void> togglePause(String id) async {
    await ref.read(advertisementRepositoryProvider).togglePause(id);
    await refresh();
  }

  Future<void> delete(String id) async {
    await ref.read(advertisementRepositoryProvider).delete(id);
    await refresh();
  }
}

final advertisementControllerProvider =
    AsyncNotifierProvider<AdvertisementController, List<AdvertisementModel>>(
      AdvertisementController.new,
    );

/// Single ad details (auto-disposed; re-fetched on each open).
final advertisementDetailProvider = FutureProvider.autoDispose
    .family<AdvertisementModel, String>((ref, id) {
      return ref.read(advertisementRepositoryProvider).getById(id);
    });
