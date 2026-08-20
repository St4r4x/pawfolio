import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Picks an image from [source], uploads it to the `pet-photos` bucket, and
/// returns its public URL — or null if the user cancelled the picker.
typedef PetPhotoUploader = Future<String?> Function(ImageSource source);

final petPhotoUploaderProvider = Provider<PetPhotoUploader>((ref) => _uploadPetPhoto);

Future<String?> _uploadPetPhoto(ImageSource source) async {
  final picked = await ImagePicker().pickImage(
    source: source,
    imageQuality: 85,
    maxWidth: 512,
    maxHeight: 512,
  );
  if (picked == null) return null;

  final bytes = await picked.readAsBytes();
  final mimeType = picked.mimeType ?? 'image/jpeg';
  final ext = mimeType == 'image/png' ? 'png' : 'jpg';
  final ownerId = Supabase.instance.client.auth.currentUser!.id;
  final path = '$ownerId/${DateTime.now().millisecondsSinceEpoch}.$ext';

  final storage = Supabase.instance.client.storage.from('pet-photos');
  await storage.uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mimeType));
  return storage.getPublicUrl(path);
}
