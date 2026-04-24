import 'package:flutter/material.dart';
import 'package:movie_watchlist/core/supabase_client.dart';

import '../models/movie.dart';
import '../models/franchise.dart';
import '../models/folder.dart';
import '../services/series_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final SeriesService _seriesService = SeriesService();

  List<Movie> movies = [];
  List<Map<String, dynamic>> allMovies = [];

  List<Folder> folders = [];
  List<Franchise> franchises = [];
  List<Map<String, dynamic>> series = [];

  List<Map<String, dynamic>> folderItems = [];
  List<Map<String, dynamic>> franchiseItems = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // ================= MOVIES =================

    final allMoviesData =
        await supabase.from('movies').select().eq('user_id', user.id);

    final franchiseItemsData = await supabase.from('franchise_items').select();

    final franchiseMovieIds =
        franchiseItemsData.map((e) => e['movie_id']).toSet();

    final standaloneMovies = allMoviesData
        .where((m) => !franchiseMovieIds.contains(m['id']))
        .toList();

    // ================= FRANCHISE =================

    final franchiseData =
        await supabase.from('franchises').select().eq('user_id', user.id);

    // ================= FOLDERS =================

    final folderData =
        await supabase.from('folders').select().eq('user_id', user.id);

    final folderItemsData = await supabase.from('folder_items').select();

    // ================= SERIES =================

    final seriesData = await _seriesService.fetchSeries();

    if (!mounted) return;

    setState(() {
      allMovies = List<Map<String, dynamic>>.from(allMoviesData);

      movies = List<Map<String, dynamic>>.from(standaloneMovies)
          .map<Movie>((json) => Movie(
                docId: json['id'],
                title: json['title'],
                posterPath: json['poster_path'],
                imdbRating: (json['imdb_rating'] as num?)?.toDouble() ?? 0.0,
                watched: json['watched'] ?? false,
                isFavorite: json['is_favorite'] ?? false,
                orderIndex: json['order_index'] ?? 0,
              ))
          .toList();

      franchises = List<Map<String, dynamic>>.from(franchiseData)
          .map<Franchise>((json) => Franchise(
                id: json['id'],
                name: json['name'],
                posterPath: json['poster_path'],
                movies: [],
                isPinned: json['is_pinned'] ?? false,
              ))
          .toList();

      folders = List<Map<String, dynamic>>.from(folderData)
          .map<Folder>((json) => Folder(
                id: json['id'],
                name: json['name'],
                isPinned: json['is_pinned'] ?? false,
                movies: [],
              ))
          .toList();

      folderItems = List<Map<String, dynamic>>.from(folderItemsData);
      franchiseItems = List<Map<String, dynamic>>.from(franchiseItemsData);

      series = seriesData;
    });
  }

  // ================= MOVIES =================

  int get movieTotal => movies.length;

  int get movieWatched => movies.where((m) => m.watched).length;

  int get movieUnwatched => movieTotal - movieWatched;

  // ================= FOLDERS =================

  int get folderTotal => folders.length;

  int get folderCompleted {
    int completed = 0;

    for (final folder in folders) {
      final items =
          folderItems.where((fi) => fi['folder_id'] == folder.id).toList();

      if (items.isEmpty) continue;

      final movieIds = items.map((e) => e['movie_id']).toSet();

      final folderMovies =
          movies.where((m) => movieIds.contains(m.docId)).toList();

      if (folderMovies.isNotEmpty && folderMovies.every((m) => m.watched)) {
        completed++;
      }
    }

    return completed;
  }

  int get folderPending => folderTotal - folderCompleted;

  // ================= FRANCHISE =================

  int get franchiseTotal => franchises.length;

  int get franchiseCompleted {
    int completed = 0;

    for (final franchise in franchises) {
      final items = franchiseItems
          .where((fi) => fi['franchise_id'] == franchise.id)
          .toList();

      if (items.isEmpty) continue;

      final movieIds = items.map((e) => e['movie_id']).toSet();

      final franchiseMovies =
          allMovies.where((m) => movieIds.contains(m['id'])).toList();

      if (franchiseMovies.isNotEmpty &&
          franchiseMovies.every((m) => m['watched'] == true)) {
        completed++;
      }
    }

    return completed;
  }

  int get franchisePending => franchiseTotal - franchiseCompleted;

  // ================= SERIES =================

  int get seriesTotal => series.length;

  int get seriesCompleted =>
      series.where((s) => s['is_completed'] == true).length;

  int get seriesPending => seriesTotal - seriesCompleted;

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section("Movies", [
              _stat("Total", movieTotal),
              _stat("Watched", movieWatched),
              _stat("Unwatched", movieUnwatched),
            ]),
            _section("Folders", [
              _stat("Total", folderTotal),
              _stat("Completed", folderCompleted),
              _stat("Pending", folderPending),
            ]),
            _section("Franchises", [
              _stat("Total", franchiseTotal),
              _stat("Completed", franchiseCompleted),
              _stat("Pending", franchisePending),
            ]),
            _section("Series", [
              _stat("Total", seriesTotal),
              _stat("Completed", seriesCompleted),
              _stat("Pending", seriesPending),
            ]),
          ],
        ),
      ),
    );
  }

  // ================= UI HELPERS =================

  Widget _section(String title, List<Widget> stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: stats,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _stat(String label, int value) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 44) / 2,
      height: 68,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF020617),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value.toString(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
