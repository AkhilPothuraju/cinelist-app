import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'folder_detail_screen.dart';
import '../utils/confirm_delete_dialog.dart';

class FoldersScreen extends StatefulWidget {
  final String searchQuery;
  final int filterMode;
  final int sortMode;
  final bool showPinnedOnly;

  const FoldersScreen({
    super.key,
    required this.searchQuery,
    required this.filterMode,
    required this.sortMode,
    required this.showPinnedOnly,
  });

  static Future<bool> openAddFolder(BuildContext context) async {
    final controller = TextEditingController();
    final supabase = Supabase.instance.client;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Create Folder"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "Folder Name",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final user = supabase.auth.currentUser;
              if (user == null) return;

              final name = controller.text.trim();
              if (name.isEmpty) return;

              await supabase.from('folders').insert({
                'name': name,
                'user_id': user.id,
                'is_pinned': false,
                'is_completed': false,
                'cover_type': 'color',
              });

              Navigator.pop(dialogContext, true);
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  State<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends State<FoldersScreen> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> folders = [];
  List<Map<String, dynamic>> filtered = [];

  bool selectionMode = false;
  Set<String> selectedFolders = {};
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void initState() {
    super.initState();
    fetchFolders();
  }

  @override
  void didUpdateWidget(covariant FoldersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    applyFilters();
  }

  void randomFolderPick() {
    if (filtered.isEmpty) return;

    filtered.shuffle();
    final folder = filtered.first;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FolderDetailScreen(
          folderId: folder['id'],
          folderName: folder['name'],
        ),
      ),
    );
  }

  Widget buildPosterCollage(List posters) {
    if (posters.isEmpty) {
      return Container(color: const Color(0xFF5C6BC0));
    }

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
      ),
      itemCount: posters.length.clamp(0, 4),
      itemBuilder: (_, i) {
        final posterUrl = "https://image.tmdb.org/t/p/w500${posters[i]}";

        return Image.network(
          posterUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(color: Colors.black26),
        );
      },
    );
  }

  Widget buildProgressBar(int watched, int total) {
    double progress = total == 0 ? 0 : watched / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TweenAnimationBuilder(
          tween: Tween<double>(begin: 0, end: progress),
          duration: const Duration(milliseconds: 600),
          builder: (_, value, __) {
            return LinearProgressIndicator(
              value: value,
              minHeight: 5,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(Colors.green),
            );
          },
        ),
        const SizedBox(height: 4),
        Text(
          "$watched / $total",
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
        )
      ],
    );
  }

  Future<void> fetchFolders() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final data = await supabase.from('folders').select().eq('user_id', user.id);

    folders = List<Map<String, dynamic>>.from(data);

    for (var folder in folders) {
      final items = await supabase
          .from('folder_items')
          .select('movies(poster_path, watched)')
          .eq('folder_id', folder['id']);

      final posters = <String>[];
      int watched = 0;

      for (var m in items) {
        final movie = m['movies'];

        if (movie == null) continue;

        if (posters.length < 4 && movie['poster_path'] != null) {
          posters.add(movie['poster_path']);
        }

        if (movie['watched'] == true) {
          watched++;
        }
      }

      folder['posters'] = posters;
      folder['total_movies'] = items.length;
      folder['watched_movies'] = watched;
    }

    if (mounted) {
      applyFilters();
    }
  }

  void applyFilters() {
    filtered = [...folders];

    if (widget.searchQuery.isNotEmpty) {
      filtered = filtered
          .where((f) => f['name']
              .toString()
              .toLowerCase()
              .contains(widget.searchQuery.toLowerCase()))
          .toList();
    }

    if (widget.filterMode == 1) {
      // completed folders
      filtered = filtered
          .where((f) =>
              (f['watched_movies'] ?? 0) > 0 &&
              (f['watched_movies'] ?? 0) == (f['total_movies'] ?? 0))
          .toList();
    }

    if (widget.filterMode == 2) {
      // not completed
      filtered = filtered
          .where((f) => (f['watched_movies'] ?? 0) < (f['total_movies'] ?? 0))
          .toList();
    }

    if (widget.showPinnedOnly) {
      filtered = filtered.where((f) => f['is_pinned'] == true).toList();
    }

    // SORT: pinned first, then alphabetical
    filtered.sort((a, b) {
      // Step 1: keep pinned folders at the top
      if (a['is_pinned'] != b['is_pinned']) {
        return (b['is_pinned'] ? 1 : 0).compareTo(a['is_pinned'] ? 1 : 0);
      }

      // Step 2: alphabetical sorting
      final nameA = a['name'].toString().toLowerCase();
      final nameB = b['name'].toString().toLowerCase();

      if (widget.sortMode == 2) {
        return nameB.compareTo(nameA); // Z → A
      }

      return nameA.compareTo(nameB); // A → Z
    });

    setState(() {});
  }

  Future<void> deleteSelected() async {
    if (selectedFolders.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Folders"),
        content: Text(
          "Delete ${selectedFolders.length} selected folder(s)?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await supabase
        .from('folders')
        .delete()
        .inFilter('id', selectedFolders.toList());

    setState(() {
      selectionMode = false;
      selectedFolders.clear();
    });

    await fetchFolders();
  }

  Future<void> togglePin(Map folder) async {
    await supabase.from('folders').update(
        {'is_pinned': !(folder['is_pinned'] ?? false)}).eq('id', folder['id']);

    await fetchFolders();
    setState(() {});
  }

  Future<void> deleteFolder(String id) async {
    await supabase.from('folders').delete().eq('id', id);
    await fetchFolders();
    setState(() {});
  }

  Future<void> renameFolder(Map folder) async {
    final controller = TextEditingController(text: folder['name']);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Rename Folder"),
        content: TextField(
          controller: controller,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;

              await supabase
                  .from('folders')
                  .update({'name': name}).eq('id', folder['id']);

              Navigator.pop(context);
              await fetchFolders();
              setState(() {});
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }

  Future<void> setFirstPoster(Map folder) async {
    final movie = await supabase
        .from('folder_items')
        .select('movies(poster_path)')
        .eq('folder_id', folder['id'])
        .limit(1);

    if (movie.isEmpty) return;

    final poster = movie[0]['movies']['poster_path'];

    await supabase.from('folders').update({
      'cover_type': 'poster',
      'cover_value': poster,
    }).eq('id', folder['id']);

    await fetchFolders();
    setState(() {}); // instant refresh
  }

  Future<void> setCustomCover(Map folder) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    final user = supabase.auth.currentUser;
    if (user == null) return;

    final bytes = await File(image.path).readAsBytes();
    final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    await supabase.storage.from('folder_covers').uploadBinary(fileName, bytes);

    final url = supabase.storage.from('folder_covers').getPublicUrl(fileName);

    await supabase.from('folders').update({
      'cover_type': 'custom',
      'cover_value': url,
    }).eq('id', folder['id']);

    await fetchFolders();
  }

  Widget buildCover(Map folder) {
    // custom uploaded image
    if (folder['cover_type'] == 'custom' && folder['cover_value'] != null) {
      return Image.network(
        folder['cover_value'],
        fit: BoxFit.cover,
      );
    }

    // manually set poster
    if (folder['cover_type'] == 'poster' && folder['cover_value'] != null) {
      final posterUrl =
          "https://image.tmdb.org/t/p/w500${folder['cover_value']}";

      return Image.network(
        posterUrl,
        fit: BoxFit.cover,
      );
    }

    // poster collage
    final posters = folder['posters'] ?? [];

    if (posters.isNotEmpty) {
      return buildPosterCollage(posters);
    }

    // default
    return Container(
      color: const Color(0xFF5C6BC0),
    );
  }

  void showOptions(Map folder) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text("Set Cover"),
              onTap: () {
                Navigator.pop(context);
                setFirstPoster(folder);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text("Custom Cover"),
              onTap: () {
                Navigator.pop(context);
                setCustomCover(folder);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text("Rename"),
              onTap: () {
                Navigator.pop(context);
                renameFolder(folder);
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_box),
              title: const Text("Select"),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  selectionMode = true;
                  selectedFolders.add(folder['id']);
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.push_pin),
              title: const Text("Pin"),
              onTap: () {
                Navigator.pop(context);
                togglePin(folder);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text("Delete", style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                deleteFolder(folder['id']);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (selectionMode)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            color: Colors.black87,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      selectionMode = false;
                      selectedFolders.clear();
                    });
                  },
                ),
                Text("${selectedFolders.length} selected"),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.delete,
                    color:
                        selectedFolders.isNotEmpty ? Colors.red : Colors.white,
                  ),
                  onPressed: selectedFolders.isEmpty ? null : deleteSelected,
                )
              ],
            ),
          ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(14),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemCount: filtered.length,
            itemBuilder: (_, index) {
              final folder = filtered[index];
              final selected = selectedFolders.contains(folder['id']);

              return GestureDetector(
                onLongPress: () => showOptions(folder),
                onTap: () {
                  if (selectionMode) {
                    setState(() {
                      if (selected) {
                        selectedFolders.remove(folder['id']);
                      } else {
                        selectedFolders.add(folder['id']);
                      }
                    });
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FolderDetailScreen(
                        folderId: folder['id'],
                        folderName: folder['name'],
                      ),
                    ),
                  ).then((_) => fetchFolders());
                },
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        buildCover(folder),
                        if (selected)
                          Container(
                            color: Colors.red.withOpacity(0.35),
                            child: const Center(
                              child: Icon(
                                Icons.check_circle,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                          ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.center,
                              colors: [
                                Colors.black.withOpacity(0.8),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 12,
                          left: 12,
                          right: 12,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                folder['name'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 6),
                              buildProgressBar(
                                folder['watched_movies'] ?? 0,
                                folder['total_movies'] ?? 0,
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Icon(
                            Icons.push_pin,
                            color: folder['is_pinned'] == true
                                ? Colors.amber
                                : Colors.white24,
                          ),
                        ),
                        if ((folder['total_movies'] ?? 0) > 0 &&
                            (folder['watched_movies'] ?? 0) ==
                                (folder['total_movies'] ?? 0))
                          Positioned(
                            top: 10,
                            left: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.check_circle,
                                      size: 14, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    "",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    )),
              );
            },
          ),
        ),
      ],
    );
  }
}
