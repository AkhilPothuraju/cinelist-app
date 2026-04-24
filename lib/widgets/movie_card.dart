import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../movies/edit_movie_screen.dart';

class MovieCard extends StatelessWidget {
  final Movie movie;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;

  const MovieCard({
    super.key,
    required this.movie,
    this.selected = false,
    this.onTap,
    this.onLongPress,
    this.onDoubleTap,
  });

  /// ================= POSTER URL =================

  String? _posterUrl() {
    if (movie.posterPath == null || movie.posterPath!.isEmpty) {
      return null;
    }

    /// Supabase / manual image
    if (movie.posterPath!.startsWith("http")) {
      return movie.posterPath;
    }

    /// TMDB poster
    return "https://image.tmdb.org/t/p/w500${movie.posterPath}";
  }

  @override
  Widget build(BuildContext context) {
    final posterUrl = _posterUrl();

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      onDoubleTap: onDoubleTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            /// ================= POSTER =================

            posterUrl == null
                ? Container(
                    color: const Color(0xFF0F172A),
                    child: const Center(
                      child: Icon(
                        Icons.movie,
                        size: 40,
                        color: Colors.white30,
                      ),
                    ),
                  )
                : CachedNetworkImage(
                    imageUrl: posterUrl,
                    cacheKey: movie.posterPath,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    errorWidget: (_, __, ___) {
                      return Container(
                        color: const Color(0xFF0F172A),
                        child: const Center(
                          child: Icon(
                            Icons.movie,
                            size: 40,
                            color: Colors.white30,
                          ),
                        ),
                      );
                    },
                  ),

            /// ================= GRADIENT =================

            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.center,
                  colors: [
                    Colors.black87,
                    Colors.transparent,
                  ],
                ),
              ),
            ),

            /// ================= EDIT BUTTON =================

            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditMovieScreen(movie: movie),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.edit,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),

            /// ================= PIN ICON =================

            if (movie.isFavorite)
              const Positioned(
                top: 8,
                left: 8,
                child: Icon(
                  Icons.push_pin,
                  size: 18,
                  color: Colors.amber,
                ),
              ),

            /// ================= SELECTED OVERLAY =================

            if (selected)
              Container(
                color: Colors.red.withOpacity(0.55),
                child: const Center(
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),

            /// ================= WATCHED OVERLAY =================

            if (!selected && movie.watched)
              Container(
                color: Colors.black45,
                child: const Center(
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.greenAccent,
                    size: 40,
                  ),
                ),
              ),

            /// ================= TITLE + RATING =================

            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(6),
                          bottomLeft: Radius.circular(6),
                        ),
                      ),
                      child: Text(
                        movie.year != null
                            ? "${movie.title} (${movie.year})"
                            : movie.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(6),
                        bottomRight: Radius.circular(6),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.star,
                          color: Colors.amber,
                          size: 14,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          movie.imdbRating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
