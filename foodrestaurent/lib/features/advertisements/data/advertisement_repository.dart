import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/core/network/dio_client.dart';
import 'package:food_user_application/core/utils/multipart_utils.dart';
import 'package:food_user_application/features/advertisements/domain/advertisement_model.dart';

class AdvertisementRepository {
  AdvertisementRepository(this._dio);

  final Dio _dio;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException(
        e.message ?? 'Something went wrong',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<List<AdvertisementModel>> list() => _guard(() async {
    final response = await _dio.get('/food/restaurant/advertisements');
    final data = response.data;
    final list = data is List ? data : const [];
    return list
        .whereType<Map>()
        .map((e) => AdvertisementModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  });

  Future<AdvertisementModel> getById(String id) => _guard(() async {
    final response = await _dio.get('/food/restaurant/advertisements/$id');
    return AdvertisementModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  });

  Future<MultipartFile> _videoToMultipart(XFile file) async {
    final bytes = await file.readAsBytes();
    final name = file.name.isNotEmpty ? file.name : 'video.mp4';
    final ext = name.split('.').last.toLowerCase();
    final subtype = switch (ext) {
      'mov' => 'quicktime',
      'webm' => 'webm',
      '3gp' => '3gpp',
      _ => 'mp4',
    };
    return MultipartFile.fromBytes(
      bytes,
      filename: name,
      contentType: DioMediaType('video', subtype),
    );
  }

  Future<FormData> _buildForm({
    required String title,
    required String description,
    required String adsType,
    required String validity,
    required String fileDescription,
    required String videoDescription,
    XFile? image,
    XFile? video,
  }) async {
    final map = <String, dynamic>{
      'title': title,
      'description': description,
      'adsType': adsType,
      'category': adsType,
      'validity': validity,
      'fileDescription': fileDescription,
      'videoDescription': videoDescription,
    };
    if (image != null) map['image'] = await xFileToMultipart(image);
    if (video != null) map['video'] = await _videoToMultipart(video);
    return FormData.fromMap(map);
  }

  static final _uploadOptions = Options(
    contentType: 'multipart/form-data',
    sendTimeout: const Duration(minutes: 3),
    receiveTimeout: const Duration(minutes: 3),
  );

  Future<void> create({
    required String title,
    required String description,
    required String adsType,
    required String validity,
    required String fileDescription,
    required String videoDescription,
    XFile? image,
    XFile? video,
  }) => _guard(() async {
    final form = await _buildForm(
      title: title,
      description: description,
      adsType: adsType,
      validity: validity,
      fileDescription: fileDescription,
      videoDescription: videoDescription,
      image: image,
      video: video,
    );
    await _dio.post(
      '/food/restaurant/advertisements',
      data: form,
      options: _uploadOptions,
    );
  });

  Future<void> update(
    String id, {
    required String title,
    required String description,
    required String adsType,
    required String validity,
    required String fileDescription,
    required String videoDescription,
    XFile? image,
    XFile? video,
  }) => _guard(() async {
    final form = await _buildForm(
      title: title,
      description: description,
      adsType: adsType,
      validity: validity,
      fileDescription: fileDescription,
      videoDescription: videoDescription,
      image: image,
      video: video,
    );
    await _dio.put(
      '/food/restaurant/advertisements/$id',
      data: form,
      options: _uploadOptions,
    );
  });

  /// Toggles Approved <-> Paused (the backend flips the state).
  Future<void> togglePause(String id) => _guard(() async {
    await _dio.patch('/food/restaurant/advertisements/$id/pause');
  });

  Future<void> delete(String id) => _guard(() async {
    await _dio.delete('/food/restaurant/advertisements/$id');
  });
}

final advertisementRepositoryProvider = Provider<AdvertisementRepository>((
  ref,
) {
  return AdvertisementRepository(ref.watch(dioProvider));
});
