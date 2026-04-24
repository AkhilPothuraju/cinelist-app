import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'models/movie.dart';

class CollectionsScreen extends StatefulWidget {
  final List<Movie> movies;
  final String searchQuery;

  const CollectionsScreen({
    super.key,
    required this.movies,
    required this.searchQuery,
  });

  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  Movie? _recentlyDeletedMovie;
  Timer? _deleteTimer;

  List<Movie> get visibleMovies {
    List<Movie> list = List.from(widget.movies);

    // 🔍 SEARCH
    if (widget.searchQuery.isNotEmpty) {
      list = list
          .where((m) =>
              m.title.toLowerCase().contains(widget.searchQuery.toLowerCase()))
          .toList();
    }

    // 📌 PINNED FIRST + ORDER SAFE
    list.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return b.isPinned ? 1 : -1;
      }
      return a.orderIndex.compareTo(b.orderIndex);
    });

    return list;
  }

  // =========================================================
  // DELETE WITH UNDO (PRODUCTION SAFE)
  // =========================================================

  void _deleteMovieWithUndo(Movie movie) {
    _recentlyDeletedMovie = movie;

    setState(() {
      widget.movies.remove(movie);
    });

    // Cancel previous timer if user deletes quickly multiple items
    _deleteTimer?.cancel();

    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Text('"${movie.title}" deleted'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () {
            _deleteTimer?.cancel();
            if (_recentlyDeletedMovie != null) {
              setState(() {
                widget.movies.add(_recentlyDeletedMovie!);
                widget.movies.sort(Movie.sortByOrder);
              });
            }
            _recentlyDeletedMovie = null;
          },
        ),
      ),
    );

    // After snackbar duration → permanent delete hook
    _deleteTimer = Timer(const Duration(seconds: 3), () {
      if (_recentlyDeletedMovie != null) {
        // TODO: Call Supabase delete here
        // Example:
        // await movieService.deleteMovie(_recentlyDeletedMovie!.id);

        _recentlyDeletedMovie = null;
      }
    });
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final movies = visibleMovies;

    if (movies.isEmpty) {
      return const Center(
        child: Text(
          'No movies found',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.68,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: movies.length,
      itemBuilder: (_, i) {
        final m = movies[i];

        return Dismissible(
          key: ValueKey(m.orderIndex),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Colors.red,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (_) async {
            return await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Movie'),
                    content: Text(
                      'Are you sure you want to delete "${m.title}"?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                ) ??
                false;
          },
          onDismissed: (_) => _deleteMovieWithUndo(m),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() {
                m.watched = !m.watched;
              });
            },
            onDoubleTap: () {
              setState(() {
                m.isPinned = !m.isPinned;
              });
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: 'https://image.tmdb.org/t/p/w500${m.bestImage}',
                    fit: BoxFit.cover,
                  ),

                  // 📌 PIN ICON
                  if (m.isPinned)
                    const Positioned(
                      top: 8,
                      left: 8,
                      child: Icon(
                        Icons.push_pin,
                        color: Colors.amber,
                        size: 18,
                      ),
                    ),

                  // TITLE
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        m.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),

                  // ✅ WATCHED OVERLAY
                  if (m.watched)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      color: Colors.black45,
                      child: const Center(
                        child: Icon(
                          Icons.check_circle,
                          color: Colors.greenAccent,
                          size: 40,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
