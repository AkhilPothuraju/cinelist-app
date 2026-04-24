import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';

Future<String?> uploadPoster(File file) async {
  try {
    final fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";
    final path = "movies/$fileName";

    await supabase.storage.from('posters').upload(
          path,
          file,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );

    final url = supabase.storage.from('posters').getPublicUrl(path);

    return url;
  } catch (e) {
    print("Poster upload failed: $e");
    return null;
  }
}
