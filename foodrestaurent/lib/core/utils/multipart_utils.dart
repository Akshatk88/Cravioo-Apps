import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

/// Converts a picked image into a Dio [MultipartFile] using in-memory bytes
/// with appropriate MIME MediaType for backend multer upload validation.
Future<MultipartFile> xFileToMultipart(XFile file) async {
  final bytes = await file.readAsBytes();
  final mime = file.mimeType ?? lookupMimeType(file.name, headerBytes: bytes) ?? 'image/jpeg';
  final parts = mime.split('/');
  final mediaType = parts.length == 2
      ? MediaType(parts[0], parts[1])
      : MediaType('image', 'jpeg');

  return MultipartFile.fromBytes(
    bytes,
    filename: file.name.isNotEmpty ? file.name : 'image.jpg',
    contentType: mediaType,
  );
}

