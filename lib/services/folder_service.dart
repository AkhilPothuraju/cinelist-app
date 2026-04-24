import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/folder.dart';
import '../models/movie.dart';
import 'package:movie_watchlist/core/supabase_client.dart';

class FolderService {
  final SupabaseClient _client = supabase;

  String get _userId => _client.auth.currentUser!.id;

  // ================= FETCH FOLDERS =================
  Future<List<Folder>> fetchFolders() async {
    final folderResponse = await _client
        .from('folders')
        .select()
        .eq('user_id', _userId)
        .order('is_pinned', ascending: false)
        .order('sort_order', ascending: true);

    final folderData = List<Map<String, dynamic>>.from(folderResponse);

    if (folderData.isEmpty) return [];

    final folderIds = folderData.map((f) => f['id']).toList();

    // 2️⃣ Fetch folder_items (ORDERED)
    final folderItemsResponse = await _client
        .from('folder_items')
        .select()
        .inFilter('folder_id', folderIds)
        .order('item_order', ascending: true);

    final folderItems = List<Map<String, dynamic>>.from(folderItemsResponse);

    if (folderItems.isEmpty) {
      return folderData.map((f) => Folder.fromMap(f, [])).toList();
    }

    // 3️⃣ Fetch movies
    final movieIds = folderItems.map((fi) => fi['movie_id']).toSet().toList();

    final moviesResponse =
        await _client.from('movies').select().inFilter('id', movieIds);

    final movies = List<Map<String, dynamic>>.from(moviesResponse)
        .map((m) => Movie.fromMap(m))
        .toList();

    // 4️⃣ Build folders safely
    List<Folder> folders = [];

    for (final folder in folderData) {
      final itemsForFolder =
          folderItems.where((fi) => fi['folder_id'] == folder['id']).toList();

      final moviesForFolder = itemsForFolder
          .map((fi) {
            try {
              return movies.firstWhere(
                (m) => m.docId == fi['movie_id'],
              );
            } catch (_) {
              return null;
            }
          })
          .whereType<Movie>() // removes nulls
          .toList();

      folders.add(
        Folder.fromMap(folder, moviesForFolder),
      );
    }

    return folders;
  }

  // ================= CREATE =================
  Future<void> createFolder(String name) async {
    await _client.from('folders').insert({
      'name': name,
      'user_id': _userId,
      'is_pinned': false,
      'sort_order': 0,
    });
  }

  // ================= ADD MOVIE TO FOLDER =================
  Future<void> addMovieToFolder({
    required String folderId,
    required String movieId,
    required int orderIndex,
  }) async {
    await _client.from('folder_items').insert({
      'folder_id': folderId,
      'movie_id': movieId,
      'item_order': orderIndex,
    });
  }

  // ================= GENERIC UPDATE =================
  Future<void> updateFolder(String folderId, Map<String, dynamic> data) async {
    await _client.from('folders').update(data).eq('id', folderId);
  }

  // ================= DELETE =================
  Future<void> deleteFolder(String folderId) async {
    await _client.from('folder_items').delete().eq('folder_id', folderId);
    await _client.from('folders').delete().eq('id', folderId);
  }

  // ================= PIN =================
  Future<void> togglePin(String folderId, bool isPinned) async {
    await _client
        .from('folders')
        .update({'is_pinned': isPinned}).eq('id', folderId);
  }

  // ================= RENAME =================
  Future<void> renameFolder(String folderId, String newName) async {
    await _client.from('folders').update({'name': newName}).eq('id', folderId);
  }

  // ================= ORDER =================
  Future<void> updateOrder(String folderId, int order) async {
    await _client
        .from('folders')
        .update({'sort_order': order}).eq('id', folderId);
  }
}
