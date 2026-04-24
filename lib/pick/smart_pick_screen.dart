import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:movie_watchlist/core/supabase_client.dart';
import '../services/folder_service.dart';
import '../services/series_service.dart';
import '../models/movie.dart';
import '../models/folder.dart';
import '../models/franchise.dart';

enum SmartPickSource {
  movies,
  folders,
  franchise,
  series,
}

class SmartPickScreen extends StatefulWidget {
  final List<Movie>? movies;
  final List<Franchise>? franchises;
  final SmartPickSource source;

  const SmartPickScreen({
    super.key,
    this.movies,
    this.franchises,
    required this.source,
  });

  @override
  State<SmartPickScreen> createState() => _SmartPickScreenState();
}

class _SmartPickScreenState extends State<SmartPickScreen> {
  final _random = Random();
  final SeriesService _seriesService = SeriesService();

  List<Folder> folders = [];

  Movie? pickedMovie;
  Franchise? pickedFranchise;
  Map<String, dynamic>? pickedSeries;

  String? pickedFolderName;
  String? fetchedPoster;

  static const _apiKey = '1a55fd98e9adcb397f4b188cdbc74172';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    if (widget.source == SmartPickSource.folders ||
        widget.source == SmartPickSource.movies) {
      folders = await FolderService().fetchFolders();
    }
  }

  // ================= TMDB FALLBACK =================

  Future<void> _fetchPosterByTitle(String title) async {
    final res = await http.get(
      Uri.parse(
        'https://api.themoviedb.org/3/search/multi'
        '?api_key=$_apiKey&query=${Uri.encodeComponent(title)}',
      ),
    );

    final data = json.decode(res.body);
    if (!mounted) return;

    if (data['results'] == null || data['results'].isEmpty) return;

    final r = data['results'][0];

    setState(() {
      fetchedPoster = r['poster_path'] ?? r['backdrop_path'];
    });
  }

  // ================= MAIN PICK =================

  Future<void> _pick() async {
    fetchedPoster = null;
    pickedFolderName = null;

    switch (widget.source) {
      case SmartPickSource.movies:
        await _pickFromMovies();
        break;
      case SmartPickSource.folders:
        _pickFromFolders();
        break;
      case SmartPickSource.franchise:
        _pickFromFranchise();
        break;
      case SmartPickSource.series:
        await _pickFromSeries();
        break;
    }
  }

  // 🎬 MOVIES TAB

  Future<void> _pickFromMovies() async {
    // If movie list is passed (like from FolderDetailScreen)
    if (widget.movies != null && widget.movies!.isNotEmpty) {
      final unwatched = widget.movies!.where((m) => !m.watched).toList();
      if (unwatched.isEmpty) return;

      final movie = unwatched[_random.nextInt(unwatched.length)];

      setState(() {
        pickedMovie = movie;
        pickedSeries = null;
        pickedFranchise = null;
        pickedFolderName = null;
      });

      if (movie.posterPath == null || movie.posterPath!.isEmpty) {
        await _fetchPosterByTitle(movie.title);
      }

      return;
    }

    // fallback → normal movies smart pick
    final userId = supabase.auth.currentUser!.id;

    final data = await supabase.from('movies').select('''
      *,
      franchise_items(movie_id)
    ''').eq('user_id', userId).eq('watched', false);

    final validMovies = <Map<String, dynamic>>[];

    for (final row in data) {
      validMovies.add(row);
    }

    if (validMovies.isEmpty) return;

    final movieData = validMovies[_random.nextInt(validMovies.length)];
    final movie = Movie.fromMap(movieData);

    setState(() {
      pickedMovie = movie;
      pickedSeries = null;
      pickedFranchise = null;
      pickedFolderName = null;
    });

    if (movie.posterPath == null || movie.posterPath!.isEmpty) {
      await _fetchPosterByTitle(movie.title);
    }
  }

  // 📂 FOLDERS TAB

  void _pickFromFolders() {
    final validFolders =
        folders.where((f) => f.movies.any((m) => !m.watched)).toList();

    if (validFolders.isEmpty) return;

    final folder = validFolders[_random.nextInt(validFolders.length)];
    final movies = folder.movies.where((m) => !m.watched).toList();

    final movie = movies[_random.nextInt(movies.length)];

    setState(() {
      pickedFolderName = folder.name;
      pickedMovie = movie;
      pickedFranchise = null;
      pickedSeries = null;
    });

    if (movie.posterPath == null) {
      _fetchPosterByTitle(movie.title);
    }
  }

  // ⭐ FRANCHISE TAB

  Future<void> _pickFromFranchise() async {
    final userId = supabase.auth.currentUser!.id;

    final data = await supabase.from('franchise_items').select('''
    movie_id,
    franchises(name),
    movies(*)
  ''');

    final validMovies = <Map<String, dynamic>>[];

    for (final row in data) {
      final movie = row['movies'];

      if (movie == null) continue;

      if (movie['watched'] == false) {
        validMovies.add({
          ...movie,
          'franchise_name': row['franchises']['name'],
        });
      }
    }

    if (validMovies.isEmpty) return;

    final picked = validMovies[_random.nextInt(validMovies.length)];

    setState(() {
      pickedMovie = Movie(
        docId: picked['id'],
        title: picked['title'],
        posterPath: picked['poster_path'],
        imdbRating: (picked['imdb_rating'] as num?)?.toDouble() ?? 0.0,
        watched: picked['watched'] ?? false,
        isFavorite: picked['is_favorite'] ?? false,
        orderIndex: picked['order_index'] ?? 0,
      );

      pickedFranchise = Franchise(
        id: '',
        name: picked['franchise_name'],
        posterPath: null,
        movies: [],
        isPinned: false,
      );

      pickedSeries = null;
      pickedFolderName = null;
    });
  }

  // 📺 SERIES TAB (SUPABASE VERSION)

  Future<void> _pickFromSeries() async {
    final allSeries = await _seriesService.fetchSeries();

    if (allSeries.isEmpty) return;

    final validSeries = <Map<String, dynamic>>[];

    for (final s in allSeries) {
      final seasons = await _seriesService.fetchSeasons(s['id']);

      for (final season in seasons) {
        final episodes = await _seriesService.fetchEpisodes(season['id']);

        if (episodes.any((e) => e['is_watched'] == false)) {
          validSeries.add(s);
          break;
        }
      }
    }

    if (validSeries.isEmpty) return;

    final picked = validSeries[_random.nextInt(validSeries.length)];

    setState(() {
      pickedSeries = picked;
      pickedMovie = null;
      pickedFranchise = null;
      pickedFolderName = null;
    });
  }
  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    final posterPath =
        pickedMovie?.posterPath ?? pickedSeries?['poster_url'] ?? fetchedPoster;

    String title = '';
    String subtitle = '';

    if (pickedMovie != null) {
      title = pickedMovie!.title;

      if (pickedFolderName != null) {
        subtitle = 'From folder: $pickedFolderName';
      } else if (pickedFranchise != null) {
        subtitle = 'Franchise: ${pickedFranchise!.name}';
      }
    } else if (pickedSeries != null) {
      title = pickedSeries!['name'];
      subtitle = 'Web Series';
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Smart Pick")),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (posterPath != null)
            CachedNetworkImage(
              imageUrl: posterPath.toString().startsWith('http')
                  ? posterPath
                  : 'https://image.tmdb.org/t/p/w780$posterPath',
              fit: BoxFit.cover,
            )
          else
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF020617), Color(0xFF0F172A)],
                ),
              ),
            ),
          Container(color: Colors.black.withOpacity(0.75)),
          Center(
            child: pickedMovie == null && pickedSeries == null
                ? ElevatedButton.icon(
                    icon: const Icon(Icons.casino),
                    label: const Text("Pick for me"),
                    onPressed: _pick,
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text("Re-roll"),
                        onPressed: _pick,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
