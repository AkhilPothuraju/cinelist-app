import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/franchise.dart';
import '../models/movie.dart';
import '../services/franchise_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:movie_watchlist/core/supabase_client.dart';
import '../utils/tmdb_helper.dart';

class FranchiseDetailScreen extends StatefulWidget {
  final Franchise franchise;
  final List<Movie> movies;

  const FranchiseDetailScreen({
    super.key,
    required this.franchise,
    required this.movies,
  });

  @override
  State<FranchiseDetailScreen> createState() => _FranchiseDetailScreenState();
}

class _FranchiseDetailScreenState extends State<FranchiseDetailScreen> {
  final FranchiseService _service = FranchiseService();
  final SupabaseClient _client = supabase;

  late List<Movie> movies;
  bool loading = true;
  String description = "";
  bool _changed = false;
  @override
  void initState() {
    super.initState();

    movies = [];

    _fetchDescription();

// always load movies from DB
    _loadFranchiseMovies();
  }

  Future<void> _addMovieToFranchise(Movie movie) async {
    await supabase.from('franchise_items').insert({
      'franchise_id': widget.franchise.id,
      'movie_id': movie.docId,
      'item_order': movies.length,
    });

    setState(() {
      movies.add(movie);
      _changed = true;
    });

    // 🔥 refresh franchise movies from DB
    await _loadFranchiseMovies();
  }

  Future<void> _loadFranchiseMovies() async {
    final data = await _service.fetchFranchiseMovies(widget.franchise.id!);

    if (!mounted) return;

    setState(() {
      movies = data;
      loading = false;
    });
  }

  // ================= FETCH DESCRIPTION =================

  Future<void> _fetchDescription() async {
    try {
      final data = await fetchMovie(widget.franchise.name);

      if (!mounted) return;

      setState(() {
        description = data.overview ?? "";
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        description = "";
      });
    }
  }

  // ================= WATCHED =================

  Future<void> _toggleWatched(Movie m) async {
    final newValue = !m.watched;

    await _client
        .from('movies')
        .update({'watched': newValue}).eq('id', m.docId!);

    if (!mounted) return;

    setState(() {
      m.watched = newValue;
    });
  }

  // ================= SELECT ALL =================

  Future<void> _toggleSelectAll() async {
    final shouldMarkAll = movies.any((m) => !m.watched);
    final ids = movies.map((m) => m.docId!).toList();

    setState(() {
      for (final m in movies) {
        m.watched = shouldMarkAll;
      }
    });

    await _client
        .from('movies')
        .update({'watched': shouldMarkAll}).inFilter('id', ids);
  }

  @override
  Widget build(BuildContext context) {
    final allWatched = movies.isNotEmpty && movies.every((m) => m.watched);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, _changed);
          },
        ),
        title: Text(widget.franchise.name),
        actions: [
          IconButton(
            icon: Icon(
              allWatched ? Icons.check_box : Icons.check_box_outline_blank,
            ),
            tooltip: "Toggle watched for all",
            onPressed: movies.isEmpty ? null : _toggleSelectAll,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : movies.isEmpty
              ? const Center(
                  child: Text(
                    'No movies found',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              : Stack(
                  children: [
                    // ================= BACKDROP =================

                    SizedBox(
                      height: 220,
                      width: double.infinity,
                      child: widget.franchise.posterPath != null
                          ? CachedNetworkImage(
                              imageUrl:
                                  "https://image.tmdb.org/t/p/w780${widget.franchise.posterPath}",
                              fit: BoxFit.cover,
                            )
                          : Container(color: Colors.black54),
                    ),

                    // gradient overlay
                    Container(
                      height: 220,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Color(0xFF0F172A),
                          ],
                        ),
                      ),
                    ),

                    // ================= CONTENT =================

                    ListView(
                      padding: const EdgeInsets.fromLTRB(16, 150, 16, 16),
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ⭐ HERO FIX
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: widget.franchise.posterPath != null
                                  ? CachedNetworkImage(
                                      imageUrl:
                                          "https://image.tmdb.org/t/p/w300${widget.franchise.posterPath}",
                                      width: 120,
                                      height: 170,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      width: 120,
                                      height: 170,
                                      color: Colors.white12,
                                      child: const Icon(Icons.movie),
                                    ),
                            ),

                            const SizedBox(width: 16),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.franchise.name,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.star,
                                          color: Colors.amber, size: 18),
                                      const SizedBox(width: 4),
                                      Text(
                                        movies.isNotEmpty
                                            ? movies.first.imdbRating
                                                .toStringAsFixed(1)
                                            : "0.0",
                                        style: const TextStyle(
                                            color: Colors.amber),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    "${movies.where((m) => m.watched).length} / ${movies.length} watched",
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    description.isEmpty
                                        ? "Loading description..."
                                        : description,
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        Builder(
                          builder: (_) {
                            double progress = movies.isEmpty
                                ? 0
                                : movies.where((m) => m.watched).length /
                                    movies.length;

                            return Row(
                              children: [
                                Expanded(
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    backgroundColor: Colors.white12,
                                    valueColor: const AlwaysStoppedAnimation(
                                        Colors.green),
                                    minHeight: 5,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  "${movies.where((m) => m.watched).length}/${movies.length}",
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                )
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 10),

                        // ================= MOVIE GRID =================

                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: movies.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.7,
                          ),
                          itemBuilder: (_, i) {
                            final m = movies[i];

                            return GestureDetector(
                              onTap: () => _toggleWatched(m),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    m.posterPath != null
                                        ? CachedNetworkImage(
                                            imageUrl:
                                                "https://image.tmdb.org/t/p/w500${m.posterPath}",
                                            fit: BoxFit.cover,
                                          )
                                        : Container(
                                            color: Colors.white12,
                                            child: const Icon(Icons.movie),
                                          ),
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
                                    if (m.watched)
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
                                    Positioned(
                                      left: 10,
                                      right: 10,
                                      bottom: 10,
                                      child: Text(
                                        m.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
    );
  }
}
