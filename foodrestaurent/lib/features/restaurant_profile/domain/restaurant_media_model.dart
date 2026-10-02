class RestaurantMediaModel {
  const RestaurantMediaModel({
    required this.coverImage,
    required this.galleryImages,
    required this.maxGalleryImages,
  });

  final String coverImage;
  final List<String> galleryImages;
  final int maxGalleryImages;

  factory RestaurantMediaModel.fromJson(Map<String, dynamic> json) {
    return RestaurantMediaModel(
      coverImage: (json['coverImage'] ?? '').toString(),
      galleryImages: (json['galleryImages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      maxGalleryImages: (json['maxGalleryImages'] as num?)?.toInt() ?? 10,
    );
  }
}
