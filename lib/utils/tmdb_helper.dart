import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/movie.dart';

const String tmdbApiKey = '1a55fd98e9adcb397f4b188cdbc74172';
const String imageBaseUrl = 'https://image.tmdb.org/t/p/w500';

/// =======================
/// INTERNAL SAFE GET
/// =======================

Future<Map<String, dynamic>?> _safeGet(String url) async {
  try {
    final res =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) return null;

    return json.decode(res.body);
  } catch (_) {
    return null;
  }
}

/// ======================
///
///
///
Future<List<Movie>> searchMovies(String title, String year) async {
  String url = 'https://api.themoviedb.org/3/search/movie'
      '?api_key=$tmdbApiKey'
      '&query=${Uri.encodeComponent(title)}'
      '&include_adult=false';

  /// add year only if user entered it
  if (year.isNotEmpty) {
    url += '&primary_release_year=$year';
  }

  final uri = Uri.parse(url);

  final res = await http.get(uri);

  if (res.statusCode != 200) return [];

  final data = json.decode(res.body);

  if (data['results'] == null) return [];

  final List results = data['results'];

  /// sort by popularity
  results
      .sort((a, b) => (b['vote_count'] ?? 0).compareTo(a['vote_count'] ?? 0));

  return results.take(10).map<Movie>((m) {
    return Movie(
      title: m['title'] ?? '',
      posterPath: m['poster_path'],
      backdropPath: m['backdrop_path'],
      overview: m['overview'],
      imdbRating: (m['vote_average'] ?? 0).toDouble(),
    );
  }).toList();
}

/// =======================
/// FETCH SINGLE MOVIE
/// =======================

Future<Movie> fetchMovie(String input) async {
  final yearMatch = RegExp(r'(19|20)\d{2}').firstMatch(input);
  final year = yearMatch?.group(0);

  final cleanTitle =
      input.replaceAll(RegExp(r'(19|20)\d{2}'), '').trim().toLowerCase();

  final uri = Uri.parse(
    'https://api.themoviedb.org/3/search/movie'
    '?api_key=$tmdbApiKey'
    '&query=${Uri.encodeComponent(cleanTitle)}'
    '&include_adult=false',
  );

  final res = await http.get(uri);

  if (res.statusCode != 200) {
    return Movie(title: input);
  }

  final data = json.decode(res.body);

  if (data['results'] == null || data['results'].isEmpty) {
    return Movie(title: input);
  }

  final List results = data['results'];

  Map<String, dynamic>? bestMatch;

  /// STEP 1 — Exact title + year match
  if (year != null) {
    final exactMatches = results.where((m) {
      final title = (m['title'] ?? '').toString().toLowerCase();
      final release = (m['release_date'] ?? '').toString();
      return title == cleanTitle && release.startsWith(year);
    }).toList();

    if (exactMatches.isNotEmpty) {
      exactMatches.sort(
          (a, b) => (b['vote_count'] ?? 0).compareTo(a['vote_count'] ?? 0));
      bestMatch = exactMatches.first;
    }
  }

  /// STEP 2 — Title contains + year match
  if (bestMatch == null && year != null) {
    final yearMatches = results.where((m) {
      final title = (m['title'] ?? '').toString().toLowerCase();
      final release = (m['release_date'] ?? '').toString();
      return title.contains(cleanTitle) && release.startsWith(year);
    }).toList();

    if (yearMatches.isNotEmpty) {
      yearMatches.sort(
          (a, b) => (b['vote_count'] ?? 0).compareTo(a['vote_count'] ?? 0));
      bestMatch = yearMatches.first;
    }
  }

  /// STEP 3 — Exact title match (ignore year)
  if (bestMatch == null) {
    final titleMatches = results.where((m) {
      final title = (m['title'] ?? '').toString().toLowerCase();
      return title == cleanTitle;
    }).toList();

    if (titleMatches.isNotEmpty) {
      titleMatches.sort(
          (a, b) => (b['vote_count'] ?? 0).compareTo(a['vote_count'] ?? 0));
      bestMatch = titleMatches.first;
    }
  }

  /// STEP 4 — fallback to most popular
  bestMatch ??= results.reduce((a, b) {
    return (a['vote_count'] ?? 0) > (b['vote_count'] ?? 0) ? a : b;
  });

  return Movie(
    title: bestMatch!['title'] ?? input,
    posterPath: bestMatch['poster_path'],
    backdropPath: bestMatch['backdrop_path'],
    overview: bestMatch['overview'],
    imdbRating: (bestMatch['vote_average'] ?? 0).toDouble(),
  );
}

/// =======================
/// FETCH FRANCHISE MOVIES
/// =======================

Future<List<Movie>> fetchFranchiseMovies(String name) async {
  try {
    // FIRST try official TMDB collection
    final collectionMovies = await fetchCollectionMovies(name);

    if (collectionMovies.isNotEmpty) {
      return collectionMovies;
    }

    // fallback to search if no collection
    final data = await _safeGet(
      'https://api.themoviedb.org/3/search/movie'
      '?api_key=$tmdbApiKey'
      '&query=${Uri.encodeComponent(name)}'
      '&include_adult=false',
    );

    if (data == null || data['results'] == null) return [];

    final List results = data['results'];

    final filtered = results.where((m) {
      final title = (m['title'] ?? '').toString().toLowerCase();
      return title.contains(name.toLowerCase());
    }).toList();

    filtered.sort(
      (a, b) => (a['release_date'] ?? '').compareTo(b['release_date'] ?? ''),
    );

    return filtered.take(10).map<Movie>((m) {
      return Movie(
        title: m['title'] ?? name,
        posterPath: m['poster_path'],
        backdropPath: m['backdrop_path'],
        overview: m['overview'],
        imdbRating: (m['vote_average'] ?? 0).toDouble(),
      );
    }).toList();
  } catch (_) {
    return [];
  }
}

/// =======================
/// SAFE VERSION
/// =======================

Future<List<Movie>> fetchFranchiseMoviesSafe(String name) async {
  final data = await _safeGet(
    'https://api.themoviedb.org/3/search/movie'
    '?api_key=$tmdbApiKey'
    '&query=${Uri.encodeComponent(name)}'
    '&include_adult=false',
  );

  if (data == null || data['results'] == null) return [];

  final List results = data['results'];

  final filtered = results.where((m) {
    final title = (m['title'] ?? '').toString().toLowerCase();
    return title.contains(name.toLowerCase());
  }).toList();

  filtered.sort((a, b) {
    final d1 = a['release_date'] ?? '';
    final d2 = b['release_date'] ?? '';
    return d1.compareTo(d2);
  });

  return filtered.take(10).map<Movie>((m) {
    return Movie(
      title: m['title'],
      posterPath: m['poster_path'],
      backdropPath: m['backdrop_path'],
      overview: m['overview'],
      imdbRating: (m['vote_average'] ?? 0).toDouble(),
    );
  }).toList();
}

Future<List<Movie>> fetchMoviesFromCollection(String name) async {
  try {
    // 1️⃣ search first movie
    final search = await http.get(
      Uri.parse(
        "https://api.themoviedb.org/3/search/movie?api_key=$tmdbApiKey&query=${Uri.encodeComponent(name)}",
      ),
    );

    if (search.statusCode != 200) return [];

    final data = json.decode(search.body);

    if (data['results'] == null || data['results'].isEmpty) return [];

    final firstMovie = data['results'][0];
    final movieId = firstMovie['id'];

    // 2️⃣ fetch movie details to get collection id
    final movieDetails = await http.get(
      Uri.parse(
        "https://api.themoviedb.org/3/movie/$movieId?api_key=$tmdbApiKey",
      ),
    );

    if (movieDetails.statusCode != 200) return [];

    final movieData = json.decode(movieDetails.body);
    final collection = movieData['belongs_to_collection'];

    if (collection == null) return [];

    final collectionId = collection['id'];

    // 3️⃣ fetch collection movies
    final collectionRes = await http.get(
      Uri.parse(
        "https://api.themoviedb.org/3/collection/$collectionId?api_key=$tmdbApiKey",
      ),
    );

    if (collectionRes.statusCode != 200) return [];

    final collectionData = json.decode(collectionRes.body);
    final parts = collectionData['parts'] as List;

    // 4️⃣ sort by release date
    parts.sort(
      (a, b) => (a['release_date'] ?? '').compareTo(b['release_date'] ?? ''),
    );

    // 5️⃣ filter invalid movies and convert to Movie model
    return parts.where((m) => m['title'] != null).map<Movie>((m) {
      return Movie(
        title: m['title'] ?? '',
        posterPath: m['poster_path'],
        backdropPath: m['backdrop_path'],
        overview: m['overview'],
        imdbRating: (m['vote_average'] ?? 0).toDouble(),
      );
    }).toList();
  } catch (e) {
    return [];
  }
}

/// =======================
/// FETCH COLLECTION MOVIES
/// =======================

Future<List<Movie>> fetchCollectionMovies(String name) async {
  try {
    final search = await http.get(
      Uri.parse(
        "https://api.themoviedb.org/3/search/collection?api_key=$tmdbApiKey&query=${Uri.encodeComponent(name)}",
      ),
    );

    if (search.statusCode != 200) return [];

    final data = json.decode(search.body);

    if (data['results'] == null || data['results'].isEmpty) return [];

    final List results = data['results'];

    Map<String, dynamic>? best;
    final target = name.toLowerCase();

    for (final r in results) {
      final title = (r['name'] ?? '').toString().toLowerCase();

      // skip fake collections
      if (title.contains("making") ||
          title.contains("behind") ||
          title.contains("documentary") ||
          title.contains("featurette")) {
        continue;
      }

      // exact match first
      if (title == "$target collection") {
        best = r;
        break;
      }

      if (title.startsWith(target)) {
        best ??= r;
      }
    }

    best ??= results.first;

    final collectionId = best!['id'];

    final collection = await http.get(
      Uri.parse(
        "https://api.themoviedb.org/3/collection/$collectionId?api_key=$tmdbApiKey",
      ),
    );

    if (collection.statusCode != 200) return [];

    final collectionData = json.decode(collection.body);

    final parts = collectionData['parts'] as List;

    parts.sort(
      (a, b) => (a['release_date'] ?? '').compareTo(b['release_date'] ?? ''),
    );

    return parts.map<Movie>((m) {
      String? year;

      if (m['release_date'] != null &&
          m['release_date'].toString().isNotEmpty) {
        year = m['release_date'].toString().substring(0, 4);
      }

      return Movie(
        title: m['title'] ?? '',
        posterPath: m['poster_path'],
        backdropPath: m['backdrop_path'],
        overview: m['overview'],
        imdbRating: (m['vote_average'] ?? 0).toDouble(),
        year: year,
      );
    }).toList();
  } catch (e) {
    return [];
  }
}

/// =======================
/// FETCH FRANCHISE POSTER
/// =======================

Future<String?> fetchFranchisePoster(String name) async {
  final data = await _safeGet(
    'https://api.themoviedb.org/3/search/collection'
    '?api_key=$tmdbApiKey'
    '&query=${Uri.encodeComponent(name)}',
  );

  if (data == null) return null;

  final results = data['results'];

  if (results == null || results.isEmpty) return null;

  return results[0]['poster_path'];
}
