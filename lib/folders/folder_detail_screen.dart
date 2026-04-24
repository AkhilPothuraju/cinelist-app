import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:movie_watchlist/core/supabase_client.dart';
import '../widgets/movie_card.dart';
import '../models/movie.dart';
import '../utils/tmdb_helper.dart';
import '../utils/storage_helper.dart';
import '../utils/confirm_delete_dialog.dart';

import '../pick/smart_pick_screen.dart'; // ✅ This replaces ???

import '../movies/edit_movie_screen.dart';

import 'dart:io';
import 'package:image_picker/image_picker.dart';

class FolderDetailScreen extends StatefulWidget {
  final String folderId;
  final String folderName;

  const FolderDetailScreen({
    super.key,
    required this.folderId,
    required this.folderName,
  });

  @override
  State<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

Future<Movie?> showMoviePicker(BuildContext context, List<Movie> movies) {
  final Movie best = movies.first;

  return showModalBottomSheet<Movie>(
    context: context,
    backgroundColor: Colors.black,
    isScrollControlled: true,
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// BIG POSTER
            GestureDetector(
              onTap: () {
                Navigator.pop(context, best);
              },
              child: Column(
                children: [
                  if (best.posterPath != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imageBaseUrl + best.posterPath!,
                        height: 260,
                      ),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    best.title,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "⭐ ${best.imdbRating}",
                    style: const TextStyle(color: Colors.amber),
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white24),
                ],
              ),
            ),

            /// OTHER RESULTS
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Other Results",
                style: TextStyle(color: Colors.white70),
              ),
            ),

            const SizedBox(height: 8),

            SizedBox(
              height: 300,
              child: ListView.builder(
                itemCount: movies.length - 1,
                itemBuilder: (context, index) {
                  final movie = movies[index + 1];

                  return ListTile(
                    leading: movie.posterPath != null
                        ? Image.network(
                            imageBaseUrl + movie.posterPath!,
                            width: 40,
                          )
                        : const Icon(Icons.movie, color: Colors.white),
                    title: Text(
                      movie.title,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      "⭐ ${movie.imdbRating}",
                      style: const TextStyle(color: Colors.grey),
                    ),
                    onTap: () {
                      Navigator.pop(context, movie);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _FolderDetailScreenState extends State<FolderDetailScreen> {
  final searchController = TextEditingController();
  final addController = TextEditingController();

  bool searching = false;
  bool sortByRating = false;
  bool showPinnedOnly = false;
  int eyeMode = 0;

  bool loading = true;
  bool selectionMode = false;

  List<Movie> movies = [];
  final Set<String> selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadMovies();
  }

  final ImagePicker _picker = ImagePicker();

  Future<File?> _pickImageFile() async {
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery);

    if (file == null) return null;

    return File(file.path);
  }

  void _showSearchDialog() {
    final titleController = TextEditingController();
    final yearController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Search Movie"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: "Movie Title",
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: yearController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Year",
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              child: const Text("Search TMDB"),
              onPressed: () async {
                final title = titleController.text.trim();
                final year = yearController.text.trim();

                if (title.isEmpty) return;

                final results = await searchMovies(title, year);

                if (results.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("No TMDB results found")),
                  );
                  return;
                }

                final selectedMovie = await showMoviePicker(context, results);

                if (selectedMovie == null) return;

                final userId = supabase.auth.currentUser!.id;

                final existing = await supabase
                    .from('movies')
                    .select()
                    .eq('user_id', userId)
                    .eq('lowercase_title', selectedMovie.title.toLowerCase())
                    .maybeSingle();

                String movieId;

                if (existing != null) {
                  movieId = existing['id'];
                } else {
                  final inserted = await supabase
                      .from('movies')
                      .insert({
                        'user_id': userId,
                        'title': selectedMovie.title,
                        'poster_path': selectedMovie.posterPath,
                        'imdb_rating': selectedMovie.imdbRating,
                        'watched': false,
                        'is_favorite': false,
                        'order_index': 0,
                        'lowercase_title': selectedMovie.title.toLowerCase(),
                      })
                      .select()
                      .single();

                  movieId = inserted['id'];
                }

                // check if movie already exists in this folder
                final existingInFolder = await supabase
                    .from('folder_items')
                    .select()
                    .eq('folder_id', widget.folderId)
                    .eq('movie_id', movieId)
                    .maybeSingle();

                if (existingInFolder != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Movie already exists in this folder"),
                    ),
                  );
                  return;
                }

                await supabase.from('folder_items').insert({
                  'folder_id': widget.folderId,
                  'movie_id': movieId,
                  'item_order': movies.length,
                });
                await _loadMovies(); // ADD THIS

                Navigator.pop(ctx);

                await _loadMovies();
              },
            ),
          ],
        );
      },
    );
  }

  void _showManualDialog() {
    final titleController = TextEditingController();
    final ratingController = TextEditingController();
    final posterController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Add Movie Manually"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              /// Title
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: "Movie Title",
                ),
              ),

              const SizedBox(height: 8),

              /// Rating
              TextField(
                controller: ratingController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "IMDb Rating",
                ),
              ),

              const SizedBox(height: 8),

              /// Poster URL
              TextField(
                controller: posterController,
                decoration: const InputDecoration(
                  labelText: "Poster URL",
                ),
              ),

              const SizedBox(height: 12),

              /// Choose From Gallery
              ElevatedButton.icon(
                icon: const Icon(Icons.image),
                label: const Text("Choose From Gallery"),
                onPressed: () async {
                  final file = await _pickImageFile();
                  if (file == null) return;

                  final url = await uploadPoster(file);

                  if (url != null) {
                    posterController.text = url;
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              child: const Text("Add Manually"),
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) return;

                final userId = supabase.auth.currentUser!.id;

                final existing = await supabase
                    .from('movies')
                    .select()
                    .eq('user_id', userId)
                    .eq('lowercase_title', title.toLowerCase())
                    .maybeSingle();

                String movieId;

                if (existing != null) {
                  movieId = existing['id'];
                } else {
                  final inserted = await supabase
                      .from('movies')
                      .insert({
                        'user_id': userId,
                        'title': title,
                        'poster_path': posterController.text,
                        'imdb_rating':
                            double.tryParse(ratingController.text) ?? 0,
                        'watched': false,
                        'is_favorite': false,
                        'order_index': 0,
                        'lowercase_title': title.toLowerCase(),
                      })
                      .select()
                      .single();

                  movieId = inserted['id'];
                }

                // check if movie already exists in this folder
                final existingInFolder = await supabase
                    .from('folder_items')
                    .select()
                    .eq('folder_id', widget.folderId)
                    .eq('movie_id', movieId)
                    .maybeSingle();

                if (existingInFolder != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Movie already exists in this folder"),
                    ),
                  );
                  return;
                }

                await supabase.from('folder_items').insert({
                  'folder_id': widget.folderId,
                  'movie_id': movieId,
                  'item_order': movies.length,
                });

                Navigator.pop(ctx);
                await _loadMovies();
              },
            ),
          ],
        );
      },
    );
  }

  // ================= LOAD MOVIES =================
  Future<void> _loadMovies() async {
    final userId = supabase.auth.currentUser!.id;

    final folderItems = await supabase
        .from('folder_items')
        .select('movie_id,item_order,is_pinned')
        .eq('folder_id', widget.folderId)
        .order('item_order', ascending: true);

    if (folderItems.isEmpty) {
      setState(() {
        movies = [];
        loading = false;
      });
      return;
    }

    final movieIds = folderItems.map((e) => e['movie_id']).toList();

    final movieData = await supabase
        .from('movies')
        .select()
        .eq('user_id', userId)
        .inFilter('id', movieIds);

    final fetchedMovies = <Movie>[];

    for (final item in folderItems) {
      final movieMap = movieData.firstWhere((m) => m['id'] == item['movie_id']);

      final movie = Movie.fromMap(movieMap);

      movie.isPinned = item['is_pinned'] ?? false;
      movie.orderIndex = item['item_order'] ?? 0;

      fetchedMovies.add(movie);
    }

    setState(() {
      movies = fetchedMovies;
      loading = false;
    });
  }

  // ================= FILTER / SORT =================
  List<Movie> get visibleMovies {
    List<Movie> list = List.from(movies);

    if (searchController.text.isNotEmpty) {
      list = list
          .where((m) => m.title
              .toLowerCase()
              .contains(searchController.text.toLowerCase()))
          .toList();
    }

    if (eyeMode == 1) {
      list = list.where((m) => m.watched).toList();
    } else if (eyeMode == 2) {
      list = list.where((m) => !m.watched).toList();
    }

    if (showPinnedOnly) {
      list = list.where((m) => m.isPinned).toList();
    }

    if (sortByRating) {
      list.sort((a, b) => b.imdbRating.compareTo(a.imdbRating));
    } else {
      list.sort((a, b) {
        if (a.isPinned != b.isPinned) {
          return b.isPinned ? 1 : -1;
        }
        return a.orderIndex.compareTo(b.orderIndex);
      });
    }

    return list;
  }

  // ================= ADD MOVIE =================
  Future<void> _addMovie() async {
    final name = addController.text.trim();
    if (name.isEmpty) return;

    final userId = supabase.auth.currentUser!.id;
    final movie = await fetchMovie(name);

    final existing = await supabase
        .from('movies')
        .select()
        .eq('user_id', userId)
        .eq('lowercase_title', movie.title.toLowerCase())
        .maybeSingle();

    String movieId;

    if (existing != null) {
      movieId = existing['id'];
    } else {
      final insertedMovie = await supabase
          .from('movies')
          .insert({
            'user_id': userId,
            'title': movie.title,
            'poster_path': movie.posterPath,
            'imdb_rating': movie.imdbRating,
            'watched': false,
            'is_favorite': false,
            'order_index': 0,
            'lowercase_title': movie.title.toLowerCase(),
          })
          .select()
          .single();

      movieId = insertedMovie['id'];
    }

    await supabase.from('folder_items').insert({
      'folder_id': widget.folderId,
      'movie_id': movieId,
      'item_order': movies.length,
    });
    await _loadMovies(); // ADD THIS

    await _loadMovies();
    addController.clear();
    Navigator.pop(context);
  }

  // ================= MULTI DELETE =================
  Future<void> _deleteSelected() async {
    if (selectedIds.isEmpty) return;

    final action = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Remove Movie"),
        content: Text(
          "What do you want to do with ${selectedIds.length} selected movies?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, "folder"),
            child: const Text("Remove from folder"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, "delete"),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text("Delete from CineList"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, "cancel"),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );

    if (action == "folder") {
      for (final id in selectedIds) {
        await supabase
            .from('folder_items')
            .delete()
            .eq('folder_id', widget.folderId)
            .eq('movie_id', id);
      }
    }
    await _loadMovies(); // ADD THIS

    if (action == "delete") {
      for (final id in selectedIds) {
        await supabase.from('movies').delete().eq('id', id);
      }
    }

    selectedIds.clear();
    selectionMode = false;

    await _loadMovies();
  }

  // ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    final visible = visibleMovies;

    return Scaffold(
      appBar: AppBar(
        title: selectionMode
            ? Text("${selectedIds.length} selected")
            : searching
                ? TextField(
                    controller: searchController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search',
                      border: InputBorder.none,
                    ),
                    onChanged: (_) => setState(() {}),
                  )
                : Text(widget.folderName),
        actions: [
          if (!selectionMode) ...[
            IconButton(
              icon: Icon(
                eyeMode == 0
                    ? Icons.visibility
                    : eyeMode == 1
                        ? Icons.visibility_outlined
                        : Icons.visibility_off,
                color: Colors.amber,
              ),
              onPressed: () => setState(() => eyeMode = (eyeMode + 1) % 3),
            ),
            IconButton(
              icon: Icon(
                showPinnedOnly ? Icons.push_pin : Icons.push_pin_outlined,
                color: showPinnedOnly ? Colors.amber : Colors.white,
              ),
              onPressed: () => setState(() => showPinnedOnly = !showPinnedOnly),
            ),
            IconButton(
              icon: Icon(sortByRating ? Icons.star : Icons.star_border),
              onPressed: () => setState(() => sortByRating = !sortByRating),
            ),
            IconButton(
              icon: Icon(searching ? Icons.close : Icons.search),
              onPressed: () {
                setState(() {
                  searching = !searching;
                  searchController.clear();
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.casino),
              tooltip: "Smart Pick",
              onPressed: () {
                final folderMovies = movies.where((m) => !m.watched).toList();

                if (folderMovies.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("All movies in this folder are watched")),
                  );
                  return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SmartPickScreen(
                      source: SmartPickSource.movies,
                      movies: folderMovies,
                    ),
                  ),
                );
              },
            ),
          ],
          if (selectionMode)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteSelected,
            ),
          if (selectionMode)
            IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: () {
                setState(() {
                  if (selectedIds.length == visible.length) {
                    selectedIds.clear();
                  } else {
                    selectedIds
                      ..clear()
                      ..addAll(visible.map((m) => m.docId!));
                  }
                });
              },
            ),
        ],
      ),
      floatingActionButton: selectionMode
          ? null
          : FloatingActionButton(
              child: const Icon(Icons.add),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.black,
                  builder: (_) {
                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading:
                                const Icon(Icons.search, color: Colors.white),
                            title: const Text(
                              "Search Movie",
                              style: TextStyle(color: Colors.white),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              _showSearchDialog();
                            },
                          ),
                          ListTile(
                            leading:
                                const Icon(Icons.edit, color: Colors.white),
                            title: const Text(
                              "Add Manually",
                              style: TextStyle(color: Colors.white),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              _showManualDialog();
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.68,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: visible.length,
              itemBuilder: (_, i) {
                final m = visible[i];
                final selected = selectedIds.contains(m.docId);

                return MovieCard(
                  movie: m,
                  selected: selected,
                  onTap: () async {
                    if (selectionMode) {
                      setState(() {
                        selected
                            ? selectedIds.remove(m.docId)
                            : selectedIds.add(m.docId!);
                      });
                    } else {
                      await supabase
                          .from('movies')
                          .update({'watched': !m.watched}).eq('id', m.docId!);
                      _loadMovies();
                    }
                  },
                  onLongPress: () {
                    setState(() {
                      selectionMode = true;
                      selectedIds.add(m.docId!);
                    });
                  },
                  onDoubleTap: () async {
                    final newValue = !m.isPinned;

                    setState(() {
                      m.isPinned = newValue;
                    });

                    await supabase
                        .from('folder_items')
                        .update({'is_pinned': newValue})
                        .eq('folder_id', widget.folderId)
                        .eq('movie_id', m.docId!);
                  },
                );
              },
            ),
    );
  }
}
