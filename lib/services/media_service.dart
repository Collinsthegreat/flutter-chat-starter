import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_compress/video_compress.dart';

class PreparedMedia {
  final File file;
  final File? thumbnail;
  final int? durationSeconds;

  const PreparedMedia({
    required this.file,
    this.thumbnail,
    this.durationSeconds,
  });
}

class MediaService {
  MediaService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<PreparedMedia?> pickImage(ImageSource source) async {
    await _requestMediaPermission(source == ImageSource.camera);
    final image = await _picker.pickImage(source: source);
    if (image == null) {
      return null;
    }
    return PreparedMedia(file: await compressImage(File(image.path)));
  }

  Future<PreparedMedia?> pickVideo() async {
    await _requestMediaPermission(false);
    final video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video == null) {
      return null;
    }

    final info = await VideoCompress.getMediaInfo(video.path);
    final durationSeconds = ((info.duration ?? 0) / 1000).ceil();
    if (durationSeconds > 60) {
      throw StateError('Videos must be 60 seconds or shorter.');
    }

    final compressed = await VideoCompress.compressVideo(
      video.path,
      quality: VideoQuality.MediumQuality,
      deleteOrigin: true,
      includeAudio: true,
    );
    final compressedFile = compressed?.file ?? File(video.path);
    final thumbnail = await VideoCompress.getFileThumbnail(
      compressedFile.path,
      quality: 75,
      position: 1000,
    );

    return PreparedMedia(
      file: compressedFile,
      thumbnail: await compressImage(thumbnail),
      durationSeconds: durationSeconds,
    );
  }

  Future<File> compressImage(File original) async {
    final size = await original.length();
    if (size < 200 * 1024) {
      return original;
    }
    final dir = await getTemporaryDirectory();
    final targetPath = p.join(
      dir.path,
      '${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    final compressed = await FlutterImageCompress.compressAndGetFile(
      original.path,
      targetPath,
      minWidth: 1280,
      minHeight: 1280,
      quality: 75,
      format: CompressFormat.jpeg,
    );
    return compressed == null ? original : File(compressed.path);
  }

  Future<void> _requestMediaPermission(bool camera) async {
    final permissions = <Permission>[
      if (camera) Permission.camera,
      Permission.photos,
      Permission.storage,
    ];
    for (final permission in permissions) {
      final status = await permission.request();
      if (status.isPermanentlyDenied) {
        await openAppSettings();
      }
    }
  }
}
