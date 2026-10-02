import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:food_user_application/core/network/dio_client.dart';
import 'package:food_user_application/core/utils/multipart_utils.dart';
import 'package:food_user_application/features/auth/domain/restaurant_model.dart';

/// All Explore-section screens that read/write the restaurant's own profile
/// go through this repository — see restaurant_profile_controller.dart for
/// the caching layer on top.
class RestaurantRepository {
  RestaurantRepository(this._dio);

  final Dio _dio;

  Future<RestaurantModel> getCurrent() async {
    final response = await _dio.get('/food/restaurant/current');
    final data = Map<String, dynamic>.from(response.data as Map);
    return RestaurantModel.fromJson(
      Map<String, dynamic>.from(data['restaurant'] as Map),
    );
  }

  Future<RestaurantModel> updateProfile(Map<String, dynamic> patch) async {
    final response = await _dio.patch('/food/restaurant/profile', data: patch);
    final data = Map<String, dynamic>.from(response.data as Map);
    return RestaurantModel.fromJson(
      Map<String, dynamic>.from(data['restaurant'] as Map),
    );
  }

  Future<RestaurantModel> updateAvailability(bool isAcceptingOrders) async {
    final response = await _dio.patch(
      '/food/restaurant/availability',
      data: {'isAcceptingOrders': isAcceptingOrders},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return RestaurantModel.fromJson(
      Map<String, dynamic>.from(data['restaurant'] as Map),
    );
  }

  /// `{ "Monday": { "isOpen": true, "openingTime": "09:00", "closingTime": "22:00" }, ... }`
  Future<Map<String, dynamic>> getOutletTimings() async {
    final response = await _dio.get('/food/restaurant/outlet-timings');
    final data = Map<String, dynamic>.from(response.data as Map);
    return Map<String, dynamic>.from(data['outletTimings'] as Map);
  }

  Future<Map<String, dynamic>> updateOutletTimings(
    Map<String, dynamic> outletTimings,
  ) async {
    final response = await _dio.put(
      '/food/restaurant/outlet-timings',
      data: {'outletTimings': outletTimings},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return Map<String, dynamic>.from(data['outletTimings'] as Map);
  }

  /// Pre-uploads an image (menu photo/document/PAN/GST/FSSAI/etc.) and returns its
  /// URL via the global upload service (/uploads/image).
  Future<String> uploadAttachment(
    XFile file, {
    String folder = 'others',
  }) async {
    final formData = FormData.fromMap({
      'folder': folder,
      'file': await xFileToMultipart(file),
    });
    try {
      final response = await _dio.post(
        '/uploads/image',
        data: formData,
      );
      if (response.data is Map) {
        final data = response.data as Map;
        final url = data['url'] ?? data['data']?['url'];
        if (url != null && url.toString().isNotEmpty) {
          return url.toString();
        }
      }
      return '';
    } on DioException catch (dioErr) {
      // If /uploads/image returns 404, fallback to /food/restaurant/upload-attachment
      if (dioErr.response?.statusCode == 404) {
        final response = await _dio.post(
          '/food/restaurant/upload-attachment',
          data: formData,
        );
        final data = Map<String, dynamic>.from(response.data as Map);
        return (data['url'] ?? '').toString();
      }
      rethrow;
    }
  }


  /// Uploading a new logo resets the restaurant's approval status to
  /// `pending` server-side — callers must warn the owner before calling this
  /// on an already-approved restaurant.
  Future<String> uploadProfileImage(XFile file) async {
    final formData = FormData.fromMap({'file': await xFileToMultipart(file)});
    final response = await _dio.post(
      '/food/restaurant/profile/profile-image',
      data: formData,
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final profileImage = Map<String, dynamic>.from(data['profileImage'] as Map);
    return (profileImage['url'] ?? '').toString();
  }

  Future<Map<String, dynamic>> getMedia() async {
    try {
      final response = await _dio.get('/food/restaurant/current');
      final data = Map<String, dynamic>.from(response.data as Map);
      final r = Map<String, dynamic>.from((data['restaurant'] ?? data) as Map);
      final rawCovers = r['coverImages'];
      final List<String> coverList = [];
      if (rawCovers is List) {
        for (final item in rawCovers) {
          if (item is Map && item['url'] != null) {
            final u = item['url'].toString();
            if (u.isNotEmpty) coverList.add(u);
          } else if (item is String && item.isNotEmpty) {
            coverList.add(item);
          }
        }
      }
      final mainCover = coverList.isNotEmpty ? coverList.first : '';
      final gallery = coverList.length > 1 ? coverList.sublist(1) : <String>[];
      return {
        'coverImage': mainCover,
        'galleryImages': gallery,
        'maxGalleryImages': 10,
      };
    } catch (_) {
      return {
        'coverImage': '',
        'galleryImages': <String>[],
        'maxGalleryImages': 10,
      };
    }
  }

  Future<Map<String, dynamic>> uploadCoverImage(XFile file) async {
    // 1. Upload image to uploads service
    final uploadedUrl = await uploadAttachment(file, folder: 'restaurant/cover');
    if (uploadedUrl.isEmpty) {
      return await getMedia();
    }
    // 2. Fetch current gallery images so we don't overwrite them
    final currentMedia = await getMedia();
    final gallery = List<String>.from(currentMedia['galleryImages'] as List);
    final nextCovers = [uploadedUrl, ...gallery];
    // 3. Persist on restaurant profile
    await _dio.patch(
      '/food/restaurant/profile',
      data: {'coverImages': nextCovers},
    );
    return {
      'coverImage': uploadedUrl,
      'galleryImages': gallery,
      'maxGalleryImages': 10,
    };
  }

  Future<Map<String, dynamic>> uploadGalleryImages(List<XFile> files) async {
    final currentMedia = await getMedia();
    final cover = currentMedia['coverImage']?.toString() ?? '';
    final gallery = List<String>.from(currentMedia['galleryImages'] as List);

    for (final file in files) {
      final url = await uploadAttachment(file, folder: 'restaurant/gallery');
      if (url.isNotEmpty && !gallery.contains(url)) {
        gallery.add(url);
      }
    }

    final nextCovers = cover.isNotEmpty ? [cover, ...gallery] : gallery;
    await _dio.patch(
      '/food/restaurant/profile',
      data: {'coverImages': nextCovers},
    );

    return {
      'coverImage': cover,
      'galleryImages': gallery,
      'maxGalleryImages': 10,
    };
  }

  Future<Map<String, dynamic>> deleteGalleryImage(String imageUrl) async {
    final currentMedia = await getMedia();
    final cover = currentMedia['coverImage']?.toString() ?? '';
    final gallery = List<String>.from(currentMedia['galleryImages'] as List);
    gallery.remove(imageUrl);

    final nextCovers = cover.isNotEmpty ? [cover, ...gallery] : gallery;
    await _dio.patch(
      '/food/restaurant/profile',
      data: {'coverImages': nextCovers},
    );

    return {
      'coverImage': cover,
      'galleryImages': gallery,
      'maxGalleryImages': 10,
    };
  }
}

final restaurantRepositoryProvider = Provider<RestaurantRepository>((ref) {
  return RestaurantRepository(ref.watch(dioProvider));
});
