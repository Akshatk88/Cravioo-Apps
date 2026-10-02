import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:food_user_application/config/theme/app_colors.dart';

Future<XFile?> pickImageWithSourceSheet(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(
              Icons.photo_camera_outlined,
              color: AppColors.primary,
            ),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(
              Icons.photo_library_outlined,
              color: AppColors.primary,
            ),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null) return null;
  // Camera sensors on modern phones commonly output 12-108MP photos.
  // imageQuality alone only re-encodes at that same resolution — decoding
  // one of those into memory just to show a small thumbnail is a common
  // OutOfMemoryError crash on low-end devices, especially with several
  // document photos on screen at once (see Step3Documents). Capping the
  // dimensions here fixes it at the source for every caller.
  return ImagePicker().pickImage(
    source: source,
    imageQuality: 82,
    maxWidth: 1600,
    maxHeight: 1600,
  );
}

/// A single-image upload tile: dashed placeholder when empty, thumbnail +
/// remove button once a file is picked.
class ImagePickerTile extends StatelessWidget {
  const ImagePickerTile({
    super.key,
    required this.label,
    required this.image,
    required this.onPick,
    required this.onRemove,
    this.required = false,
    this.height = 120,
  });

  final String label;
  final XFile? image;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  final bool required;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
            children: [
              TextSpan(text: label),
              if (required)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: AppColors.error),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onPick,
          child: Container(
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black12, width: 1),
            ),
            child: image == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_upload_outlined,
                        color: AppColors.primary,
                        size: 28,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Tap to upload',
                        style: TextStyle(fontSize: 12, color: Colors.black45),
                      ),
                    ],
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: kIsWeb
                            ? Image.network(image!.path, fit: BoxFit.cover)
                            : Image.file(
                                File(image!.path),
                                fit: BoxFit.cover,
                                cacheHeight:
                                    (height * MediaQuery.devicePixelRatioOf(context))
                                        .round(),
                              ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: GestureDetector(
                          onTap: onRemove,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

/// Multi-image picker grid (menu photos) — up to [maxCount] thumbnails plus
/// an "add" tile.
class MultiImagePickerGrid extends StatelessWidget {
  const MultiImagePickerGrid({
    super.key,
    required this.images,
    required this.onAdd,
    required this.onRemove,
    this.maxCount = 10,
  });

  final List<XFile> images;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: images.length < maxCount ? images.length + 1 : images.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        if (index == images.length) {
          return GestureDetector(
            onTap: onAdd,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
              ),
              child: Icon(
                Icons.add_photo_alternate_outlined,
                color: AppColors.primary,
              ),
            ),
          );
        }
        final image = images[index];
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: kIsWeb
                  ? Image.network(image.path, fit: BoxFit.cover)
                  : Image.file(File(image.path), fit: BoxFit.cover),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => onRemove(index),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
