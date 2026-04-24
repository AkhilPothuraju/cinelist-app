import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:movie_watchlist/core/supabase_client.dart';
import '../models/franchise.dart';
import '../models/movie.dart';
import '../utils/tmdb_helper.dart';

class FranchiseService {
  final SupabaseClient _client = supabase;

  String? get _userId => _client.auth.currentUser?.id;

  // ================= FETCH =================

  Future<List<Franchise>> fetchFranchises() async {
    try {
      final userId = _userId;
      if (userId == null) return [];

      final franchises = await _client
          .from('franchises')
          .select()
          .eq('user_id', userId)
          .order('is_pinned', ascending: false)
          .order('name', ascending: true);

      if (franchises.isEmpty) return [];

      final ids = franchises.map((f) => f['id']).toList();

      final items = await _client
          .from('franchise_items')
          .select('franchise_id, movie:movies(*)')
          .inFilter('franchise_id', ids);

      Map<dynamic, List<Movie>> map = {};

      for (final item in items) {
        final fid = item['franchise_id'];
        final movie = item['movie'];

        if (movie == null) continue;

        map.putIfAbsent(fid, () => []);
        map[fid]!.add(Movie.fromMap(movie));
      }

      return franchises.map<Franchise>((f) {
        return Franchise.fromJson(
          f,
          movies: map[f['id']] ?? [],
        );
      }).toList();
    } catch (e) {
      print("Fetch franchises error: $e");
      return [];
    }
  }

  // ================= CREATE =================

  Future<void> createFranchise({
    required String name,
  }) async {
    try {
      final userId = _userId;
      if (userId == null) return;

      // prevent duplicates
      final existing = await _client
          .from('franchises')
          .select('id')
          .eq('user_id', userId)
          .eq('name', name);

      if (existing.isNotEmpty) return;

      List<Movie> results = await fetchCollectionMovies(name);
      if (results.isEmpty) {
        results = await searchMovies(name, "");
      }

      if (results.isEmpty) return;

      final poster = results.first.posterPath;

      final inserted = await _client
          .from('franchises')
          .insert({
            'name': name,
            'poster_path': poster,
            'user_id': userId,
            'is_pinned': false,
          })
          .select()
          .single();

      final franchiseId = inserted['id'];

      // ⚡ batch insert movies
      final movieRows = results.map((m) {
        return {
          'title': m.title,
          'poster_path': m.posterPath,
          'imdb_rating': m.imdbRating,
          'user_id': userId,
          'watched': false,
          'is_favorite': false,
          'lowercase_title': m.title.toLowerCase(),
        };
      }).toList();

      final insertedMovies =
          await _client.from('movies').insert(movieRows).select();

      final franchiseItems = insertedMovies.map((m) {
        return {
          'franchise_id': franchiseId,
          'movie_id': m['id'],
        };
      }).toList();

      await _client.from('franchise_items').insert(franchiseItems);
    } catch (e) {
      print("Franchise creation error: $e");
    }
  }
  // ================= FETCH FRANCHISE MOVIES =================

  Future<List<Movie>> fetchFranchiseMovies(String franchiseId) async {
    print("QUERYING FRANCHISE: $franchiseId");

    final items = await supabase
        .from('franchise_items')
        .select('movie_id')
        .eq('franchise_id', franchiseId);

    print("ITEMS FOUND: ${items.length}");

    if (items.isEmpty) return [];

    final movieIds = items.map((e) => e['movie_id']).toList();

    final movies =
        await supabase.from('movies').select().inFilter('id', movieIds);

    print("MOVIES FOUND: ${movies.length}");

    return movies.map<Movie>((m) => Movie.fromMap(m)).toList();
  }

  // ================= DELETE =================

  Future<void> deleteFranchise(String franchiseId) async {
    try {
      await _client
          .from('franchise_items')
          .delete()
          .eq('franchise_id', franchiseId);

      await _client.from('franchises').delete().eq('id', franchiseId);
    } catch (e) {
      print("Delete franchise error: $e");
    }
  }

  // ================= ADD MOVIE =================

  Future<void> addMovieToFranchise({
    required String franchiseId,
    required String movieId,
  }) async {
    try {
      final existing = await _client
          .from('franchise_items')
          .select('id')
          .eq('franchise_id', franchiseId)
          .eq('movie_id', movieId);

      if (existing.isEmpty) {
        await _client.from('franchise_items').insert({
          'franchise_id': franchiseId,
          'movie_id': movieId,
        });
      }
    } catch (e) {
      print("Add movie error: $e");
    }
  }

  // ================= REMOVE MOVIE =================

  Future<void> removeMovieFromFranchise({
    required String franchiseId,
    required String movieId,
  }) async {
    try {
      await _client
          .from('franchise_items')
          .delete()
          .eq('franchise_id', franchiseId)
          .eq('movie_id', movieId);
    } catch (e) {
      print("Remove movie error: $e");
    }
  }

  // ================= FETCH ALL FRANCHISE MOVIES =================

  Future<List<Movie>> fetchAllFranchiseMovies() async {
    try {
      final userId = _userId;
      if (userId == null) return [];

      final response = await _client
          .from('franchise_items')
          .select('movie:movies(*)')
          .eq('movies.user_id', userId);

      List<Movie> movies = [];

      for (final item in response) {
        final movie = item['movie'];

        if (movie != null) {
          try {
            movies.add(Movie.fromMap(movie));
          } catch (_) {}
        }
      }

      return movies;
    } catch (e) {
      print("Fetch franchise movies error: $e");
      return [];
    }
  }

  // ================= PIN =================

  Future<void> togglePin(String franchiseId, bool value) async {
    try {
      await _client
          .from('franchises')
          .update({'is_pinned': value}).eq('id', franchiseId);
    } catch (e) {
      print("Pin error: $e");
    }
  }
}
