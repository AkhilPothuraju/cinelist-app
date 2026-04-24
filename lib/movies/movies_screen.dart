import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:movie_watchlist/core/supabase_client.dart';
import 'package:movie_watchlist/models/movie.dart';
import 'package:movie_watchlist/utils/tmdb_helper.dart';
import '../widgets/movie_card.dart';
import '../utils/storage_helper.dart';
import '../utils/confirm_delete_dialog.dart';
import '../movies/edit_movie_screen.dart';

class MoviesScreen extends StatefulWidget {
  final int filter;
  final int folderFilterMode;
  final bool showPinnedOnly;
  final bool sortByRating;
  final String searchQuery;

  const MoviesScreen({
    super.key,
    required this.filter,
    required this.folderFilterMode,
    required this.showPinnedOnly,
    required this.sortByRating,
    required this.searchQuery,
  });

  @override
  State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen> {
  Set<String> folderMovieIds = {};
  bool movieSelectionMode = false;
  List<Movie> visibleMovies = [];
  final Set<String> selectedMovieIds = {};

  final ImagePicker _picker = ImagePicker();

  Future<File?> _pickImageFile() async {
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery);

    if (file == null) return null;

    return File(file.path);
  }

  void _refreshStream() {
    final userId = supabase.auth.currentUser!.id;

    movieStream = supabase
        .from('movies')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('order_index', ascending: true)
        .map((data) async {
          final franchiseItems =
              await supabase.from('franchise_items').select('movie_id');

          final franchiseIds = franchiseItems.map((e) => e['movie_id']).toSet();

          return data
              .where((movie) => !franchiseIds.contains(movie['id']))
              .toList();
        })
        .asyncMap((e) async => e);
  }

  Future<void> fetchFolderMovies() async {
    final userId = supabase.auth.currentUser!.id;

    final data = await supabase.from('folder_items').select('movie_id');

    folderMovieIds = data.map<String>((e) => e['movie_id'].toString()).toSet();

    if (mounted) setState(() {});
  }

  /// ================= ADD MOVIE (TMDB) =================

  Future<void> _addMovieFromTMDB(Movie movie) async {
    final userId = supabase.auth.currentUser!.id;

    final existing = await supabase
        .from('movies')
        .select()
        .eq('lowercase_title', movie.title.toLowerCase())
        .eq('user_id', userId);

    if (existing.isNotEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Movie already exists")));
      return;
    }

    final currentMovies =
        await supabase.from('movies').select().eq('user_id', userId);

    final orderIndex = currentMovies.length;

    await supabase.from('movies').insert({
      'user_id': userId,
      'title': movie.title,
      'poster_path': movie.posterPath,
      'imdb_rating': movie.imdbRating,
      'watched': false,
      'is_favorite': false,
      'order_index': orderIndex,
      'lowercase_title': movie.title.toLowerCase(),
    });
  }

  /// ================= ADD MANUAL MOVIE =================

  Future<void> _addManualMovie(
      String title, String rating, String poster) async {
    final userId = supabase.auth.currentUser!.id;

    final existing = await supabase
        .from('movies')
        .select()
        .eq('lowercase_title', title.toLowerCase())
        .eq('user_id', userId);

    if (existing.isNotEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Movie already exists")));
      return;
    }

    final currentMovies =
        await supabase.from('movies').select().eq('user_id', userId);

    final orderIndex = currentMovies.length;

    await supabase.from('movies').insert({
      'user_id': userId,
      'title': title,
      'poster_path': poster.isEmpty ? null : poster,
      'imdb_rating': double.tryParse(rating) ?? 0,
      'watched': false,
      'is_favorite': false,
      'order_index': orderIndex,
      'lowercase_title': title.toLowerCase(),
    });
  }

  /// ================= DELETE MULTI =================

  Future<void> deleteSelected() async {
    final ids = List<String>.from(selectedMovieIds);

    await supabase.from('movies').delete().inFilter('id', ids);

    if (!mounted) return;

    setState(() {
      movieSelectionMode = false;
      selectedMovieIds.clear();
      _refreshStream(); // 🔥 forces UI refresh
    });
  }

  /// ================= MOVIE PICKER =================

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
              /// ===== BIG POSTER =====
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
                      best.year != null
                          ? "${best.title} (${best.year})"
                          : best.year != null
                              ? "${best.title} (${best.year})"
                              : best.title,
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

              /// ===== OTHER RESULTS =====
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

  /// ================= MOVIE GRID =================
  Future<List> _fetchMovies() async {
    final userId = supabase.auth.currentUser!.id;

    return await supabase.from('movies').select('''
        *,
        folder_items(movie_id),
        franchise_items(movie_id)
      ''').eq('user_id', userId).order('order_index', ascending: true);
  }

  late Stream<List<Map<String, dynamic>>> movieStream;

  @override
  void initState() {
    super.initState();
    _refreshStream();
    fetchFolderMovies();
  }

  Widget buildMovies() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: movieStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final moviesData = snapshot.data!;

        // refresh folder membership

        List<Movie> movies = [];

        for (final row in moviesData) {
          final movie = Movie.fromMap(row);

          /// Skip if deleted locally
          if (movie.docId == null) continue;

          final bool isInFolder =
              folderMovieIds.contains(movie.docId.toString());

          /// Folder filter modes

// Mode 1 → show ONLY folder movies
          if (widget.folderFilterMode == 1 && !isInFolder) {
            continue;
          }

// Mode 2 → show ONLY standalone movies
          if (widget.folderFilterMode == 2 && isInFolder) {
            continue;
          }

          final List franchiseItems = row['franchise_items'] ?? [];

          /// Franchise filter
          if (franchiseItems.isNotEmpty) continue;

          movies.add(movie);
        }

        /// WATCHED FILTER
        if (widget.filter == 1) {
          movies = movies.where((m) => m.watched).toList();
        } else if (widget.filter == 2) {
          movies = movies.where((m) => !m.watched).toList();
        }

        /// PIN FILTER
        if (widget.showPinnedOnly) {
          movies = movies.where((m) => m.isFavorite).toList();
        }

        /// SEARCH FILTER
        if (widget.searchQuery.isNotEmpty) {
          movies = movies
              .where((m) => m.title
                  .toLowerCase()
                  .contains(widget.searchQuery.toLowerCase()))
              .toList();
        }

        /// SORT
        /// SORT (PINNED ALWAYS FIRST)
        movies.sort((a, b) {
          if (a.isFavorite && !b.isFavorite) return -1;
          if (!a.isFavorite && b.isFavorite) return 1;

          if (widget.sortByRating) {
            return b.imdbRating.compareTo(a.imdbRating);
          } else {
            return a.orderIndex.compareTo(b.orderIndex);
          }
        });
        visibleMovies = movies;
        if (movies.isEmpty) {
          return const Center(
            child: Text(
              "No movies yet",
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: .68,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: movies.length,
          itemBuilder: (_, i) {
            final m = movies[i];
            final selected = selectedMovieIds.contains(m.docId);

            return AnimatedScale(
              scale: selected ? 0.96 : 1,
              duration: const Duration(milliseconds: 120),
              child: MovieCard(
                key: ValueKey(m.docId),
                movie: m,
                selected: selected,

                /// DOUBLE TAP = PIN / UNPIN
                onDoubleTap: () async {
                  setState(() {
                    m.isFavorite = !m.isFavorite; // instant UI change
                  });

                  await supabase
                      .from('movies')
                      .update({'is_favorite': m.isFavorite}).eq('id', m.docId!);
                },

                /// SINGLE TAP = WATCHED
                onTap: () async {
                  if (movieSelectionMode) {
                    setState(() {
                      if (selected) {
                        selectedMovieIds.remove(m.docId);
                      } else {
                        selectedMovieIds.add(m.docId!);
                      }

                      if (selectedMovieIds.isEmpty) {
                        movieSelectionMode = false;
                      }
                    });
                    return;
                  }

                  await supabase
                      .from('movies')
                      .update({'watched': !m.watched}).eq('id', m.docId!);
                },

                /// LONG PRESS = SELECT
                onLongPress: () {
                  setState(() {
                    movieSelectionMode = true;
                    selectedMovieIds.add(m.docId ?? "");
                  });
                },
              ),
            );
          },
        );
      },
    );
  }

  void _showSearchDialog() {
    final titleController = TextEditingController();
    final yearController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Search Movie"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: "Movie Title"),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: yearController,
              decoration: const InputDecoration(labelText: "Year"),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
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
                  const SnackBar(content: Text("No results found")),
                );
                return;
              }

              final selectedMovie = await showMoviePicker(context, results);

              if (selectedMovie == null) return;

              await _addMovieFromTMDB(selectedMovie);

              if (!mounted) return;
              Navigator.pop(context);
            },
          )
        ],
      ),
    );
  }

  void _showManualDialog() {
    final titleController = TextEditingController();
    final ratingController = TextEditingController();
    final posterController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Movie Manually"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: "Movie Title"),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: ratingController,
              decoration: const InputDecoration(labelText: "IMDb Rating"),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: posterController,
              decoration: const InputDecoration(labelText: "Poster URL"),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.image),
              label: const Text("Choose From Gallery"),
              onPressed: () async {
                final file = await _pickImageFile();

                if (file == null) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Uploading poster...")),
                );

                final url = await uploadPoster(file);

                if (url != null) {
                  posterController.text = url;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Poster uploaded")),
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            child: const Text("Add Manually"),
            onPressed: () async {
              final title = titleController.text.trim();
              if (title.isEmpty) return;

              await _addManualMovie(
                title,
                ratingController.text,
                posterController.text,
              );

              if (!mounted) return;
              Navigator.pop(context);
            },
          )
        ],
      ),
    );
  }

  /// ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: movieSelectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    movieSelectionMode = false;
                    selectedMovieIds.clear();
                  });
                },
              ),
              title: Text("${selectedMovieIds.length} selected"),
              actions: [
                /// SELECT ALL / UNSELECT ALL
                TextButton(
                  onPressed: () {
                    setState(() {
                      final allIds = visibleMovies.map((m) => m.docId!).toSet();

                      if (selectedMovieIds.length == allIds.length) {
                        selectedMovieIds.clear(); // Unselect All
                      } else {
                        selectedMovieIds
                          ..clear()
                          ..addAll(allIds); // Select visible movies
                      }
                    });
                  },
                  child: Text(
                    selectedMovieIds.length == visibleMovies.length
                        ? "Unselect All"
                        : "Select All",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),

                /// DELETE
                IconButton(
                  tooltip: "Delete",
                  icon: const Icon(Icons.delete),
                  onPressed: selectedMovieIds.isEmpty
                      ? null
                      : () async {
                          final confirm = await confirmDelete(
                            context,
                            title: "Delete Movies",
                            message: selectedMovieIds.length == 1
                                ? "Delete this movie?"
                                : "Delete ${selectedMovieIds.length} movies?",
                          );

                          if (confirm == true) {
                            await deleteSelected();

                            setState(() {
                              movieSelectionMode = false;
                              selectedMovieIds.clear();
                            });
                          }
                        },
                ),
              ],
            )
          : null,
      body: buildMovies(),
      floatingActionButton: movieSelectionMode
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
    );
  }
}
