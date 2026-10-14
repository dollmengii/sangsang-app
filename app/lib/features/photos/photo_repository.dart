import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase.dart';
import '../../core/uuid.dart';

const maxPhotos = 3;

class MyPhoto {
  const MyPhoto({
    required this.id,
    required this.originalPath,
    required this.moodPath,
    required this.isPrimary,
    required this.isFace,
    required this.status,
  });

  factory MyPhoto.fromRow(Map<String, dynamic> r) => MyPhoto(
        id: r['id'] as String,
        originalPath: r['original_path'] as String,
        moodPath: r['mood_path'] as String?,
        isPrimary: r['is_primary'] as bool,
        isFace: r['is_face'] as bool,
        status: r['status'] as String,
      );

  final String id;
  final String originalPath;
  final String? moodPath;
  final bool isPrimary;
  final bool isFace;
  final String status;
}

/// 사진 올리기에서 사람에게 보여줄 실패 이유.
class PhotoUploadException implements Exception {
  const PhotoUploadException(this.message);
  final String message;
}

class PhotoRepository {
  PhotoRepository(this._client);

  final SupabaseClient _client;
  final _picker = ImagePicker();

  String get _uid => _client.auth.currentUser!.id;

  Future<List<MyPhoto>> list() async {
    final rows = await _client
        .from('photos')
        .select('id, original_path, mood_path, is_primary, is_face, status')
        .eq('owner', _uid)
        .order('created_at');
    return rows.map(MyPhoto.fromRow).toList();
  }

  /// 안드로이드 시스템 사진 선택기로 한 장을 고른다. 고르지 않으면 null.
  /// 폰에서 먼저 줄여서 올리고, 서버가 다시 1080px로 줄이며 위치 정보를 지운다.
  Future<Uint8List?> pick() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2160,
      maxHeight: 2160,
      imageQuality: 90,
      requestFullMetadata: false,
    );
    return file?.readAsBytes();
  }

  Future<void> upload(Uint8List bytes, {required bool isFace}) async {
    final id = uuidV4();
    await _client.storage.from('originals').uploadBinary(
          '$_uid/$id.jpg',
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    try {
      await _client.functions.invoke('process-photo', body: {'photoId': id, 'isFace': isFace});
    } on FunctionException catch (e) {
      final code = e.details is Map ? (e.details as Map)['error'] : null;
      throw PhotoUploadException(switch (code) {
        'too_many_photos' => '사진은 $maxPhotos장까지 올릴 수 있어요.',
        'not_an_image' => '이 파일은 사진으로 읽을 수 없어요. JPG나 PNG로 다시 골라 주세요.',
        'too_large' => '사진이 너무 커요. 다른 사진으로 골라 주세요.',
        _ => '사진을 처리하지 못했어요. 잠시 뒤 다시 해 주세요.',
      });
    }
  }

  Future<Uint8List> original(String path) => _client.storage.from('originals').download(path);

  Future<void> setPrimary(String id) => _client.rpc('set_primary_photo', params: {'p_photo': id});

  Future<void> delete(String id) async {
    final rows = await _client.rpc('delete_my_photo', params: {'p_photo': id}) as List;
    final row = rows.first as Map<String, dynamic>;
    await _client.storage.from('originals').remove([row['original_path'] as String]);
    final mood = row['mood_path'] as String?;
    if (mood != null) await _client.storage.from('moods').remove([mood]);
  }
}

final photoRepositoryProvider =
    Provider<PhotoRepository>((ref) => PhotoRepository(ref.watch(supabaseProvider)));

final myPhotosProvider = FutureProvider<List<MyPhoto>>((ref) async {
  ref.watch(sessionProvider);
  return ref.watch(photoRepositoryProvider).list();
});

/// 내 원본 사진 바이트 (내 사진 화면에서만 쓴다).
final myOriginalProvider = FutureProvider.family<Uint8List, String>((ref, path) {
  return ref.watch(photoRepositoryProvider).original(path);
});
