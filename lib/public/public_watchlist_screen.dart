import 'dart:math';
import 'package:flutter/material.dart';
import 'package:movie_watchlist/core/supabase_client.dart';

class PublicWatchlistScreen extends StatefulWidget {
  final String username;

  const PublicWatchlistScreen({super.key, required this.username});

  @override
  State<PublicWatchlistScreen> createState() => _PublicWatchlistScreenState();
}

class _PublicWatchlistScreenState extends State<PublicWatchlistScreen> {
  Map? pickedMovie;

  Future<List> fetchMovies() async {
    final profile = await supabase
        .from('profiles')
        .select('id')
        .eq('username', widget.username)
        .single();

    final userId = profile['id'];

    final movies = await supabase.from('movies').select().eq('user_id', userId);

    return movies;
  }

  void pickRandom(List movies) {
    final random = Random();
    final movie = movies[random.nextInt(movies.length)];

    setState(() {
      pickedMovie = movie;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text("${widget.username}'s Watchlist"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder(
        future: fetchMovies(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final movies = snapshot.data as List;

          if (movies.isEmpty) {
            return const Center(child: Text("No movies yet"));
          }

          return Column(
            children: [
              /// RANDOM PICK BUTTON
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.casino),
                  label: const Text("Pick Random Movie"),
                  onPressed: () => pickRandom(movies),
                ),
              ),

              /// RANDOM RESULT
              if (pickedMovie != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    "🎬 ${pickedMovie!['title']}",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              /// MOVIE GRID
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 180,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.66,
                  ),
                  itemCount: movies.length,
                  itemBuilder: (_, i) {
                    final movie = movies[i];
                    final poster = movie['poster_path'];

                    final imageUrl = poster != null
                        ? "https://image.tmdb.org/t/p/w500$poster"
                        : null;

                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black54,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            /// POSTER
                            Positioned.fill(
                              child: imageUrl != null
                                  ? Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      loadingBuilder:
                                          (context, child, progress) {
                                        if (progress == null) return child;
                                        return const Center(
                                            child: CircularProgressIndicator());
                                      },
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Container(
                                          color: Colors.grey[800],
                                          child: Center(
                                            child: Text(
                                              movie['title'] ?? '',
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        );
                                      },
                                    )
                                  : Container(
                                      color: Colors.grey[800],
                                      child: Center(
                                        child: Text(
                                          movie['title'] ?? '',
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                            ),

                            /// GRADIENT OVERLAY
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.center,
                                    colors: [
                                      Colors.black.withOpacity(0.85),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            /// TITLE
                            Positioned(
                              bottom: 8,
                              left: 8,
                              right: 8,
                              child: Text(
                                movie['title'] ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
