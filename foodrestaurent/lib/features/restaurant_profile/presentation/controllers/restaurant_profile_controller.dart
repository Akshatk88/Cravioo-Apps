import 'package:cached_network_image/cached_network_image.dart';
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
  ///
  /// Returns true when the backend staged the edit for admin review
  /// (already-approved outlet) instead of applying it live.
  Future<bool> updateProfile(Map<String, dynamic> patch) async {
    final updated = await ref
        .read(restaurantRepositoryProvider)
        .updateProfile(patch);
    state = AsyncValue.data(updated);
    return updated.pendingReviewSubmitted;
  }

  Future<void> updateAvailability(bool isAcceptingOrders) async {
    final updated = await ref
        .read(restaurantRepositoryProvider)
        .updateAvailability(isAcceptingOrders);
    state = AsyncValue.data(updated);
  }

  /// Uploads a new logo and re-syncs the cached profile so every screen
  /// watching this provider (orders app bar, drawer, explore header, outlet
  /// info) shows the result immediately.
  ///
  /// For an already-approved outlet the backend stages the logo for admin
  /// review; the result's `pendingReview` is then true and the live logo is
  /// unchanged — the caller must say so instead of claiming it changed.
  Future<ProfileImageUploadResult> uploadProfileImage(XFile file) async {
    final previousUrl = state.value?.profileImage ?? '';
    final result = await ref
        .read(restaurantRepositoryProvider)
        .uploadProfileImage(file);

    // CachedNetworkImage caches by URL — if the server re-used the same URL
    // the old bitmap would keep showing, so drop it from both caches.
    if (!result.pendingReview && previousUrl.isNotEmpty) {
      await _evictImage(previousUrl);
    }
    if (result.url.isNotEmpty && result.url != previousUrl) {
      await _evictImage(result.url);
    }

    // Silent reload: keep showing the current data instead of flashing a
    // full-screen spinner on every screen watching this provider.
    try {
      final fresh = await ref.read(restaurantRepositoryProvider).getCurrent();
      state = AsyncValue.data(fresh);
    } catch (_) {
      final current = state.value;
      if (current != null && result.url.isNotEmpty && !result.pendingReview) {
        state = AsyncValue.data(_withProfileImage(current, result.url));
      }
    }
    return result;
  }

  Future<void> _evictImage(String url) async {
    try {
      await CachedNetworkImage.evictFromCache(url);
    } catch (_) {
      // Cache eviction is best-effort only.
    }
  }

  RestaurantModel _withProfileImage(RestaurantModel r, String url) {
    return RestaurantModel(
      id: r.id,
      restaurantName: r.restaurantName,
      ownerName: r.ownerName,
      ownerEmail: r.ownerEmail,
      ownerPhone: r.ownerPhone,
      primaryContactNumber: r.primaryContactNumber,
      pureVegRestaurant: r.pureVegRestaurant,
      status: r.status,
      rejectionReason: r.rejectionReason,
      isAcceptingOrders: r.isAcceptingOrders,
      profileImage: url,
      addressLine1: r.addressLine1,
      addressLine2: r.addressLine2,
      area: r.area,
      city: r.city,
      state: r.state,
      pincode: r.pincode,
      landmark: r.landmark,
      formattedAddress: r.formattedAddress,
      cuisines: r.cuisines,
      openDays: r.openDays,
      openingTime: r.openingTime,
      closingTime: r.closingTime,
      estimatedDeliveryTime: r.estimatedDeliveryTime,
      panNumber: r.panNumber,
      nameOnPan: r.nameOnPan,
      panImage: r.panImage,
      gstRegistered: r.gstRegistered,
      gstNumber: r.gstNumber,
      gstLegalName: r.gstLegalName,
      gstAddress: r.gstAddress,
      gstImage: r.gstImage,
      fssaiNumber: r.fssaiNumber,
      fssaiExpiry: r.fssaiExpiry,
      fssaiImage: r.fssaiImage,
      accountHolderName: r.accountHolderName,
      accountNumber: r.accountNumber,
      ifscCode: r.ifscCode,
      accountType: r.accountType,
      upiId: r.upiId,
      upiQrImage: r.upiQrImage,
      latitude: r.latitude,
      longitude: r.longitude,
      pendingLatitude: r.pendingLatitude,
      pendingLongitude: r.pendingLongitude,
      locationUpdateStatus: r.locationUpdateStatus,
      locationRejectionReason: r.locationRejectionReason,
      zoneId: r.zoneId,
      rating: r.rating,
      totalRatings: r.totalRatings,
      restaurantId: r.restaurantId,
      hasPendingProfileChanges: r.hasPendingProfileChanges,
      pendingProfileImage: r.pendingProfileImage,
      pendingChangeFields: r.pendingChangeFields,
    );
  }
}

final restaurantProfileControllerProvider =
    AsyncNotifierProvider<RestaurantProfileController, RestaurantModel>(
      RestaurantProfileController.new,
    );
