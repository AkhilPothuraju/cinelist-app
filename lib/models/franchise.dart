import 'movie.dart';

class Franchise {
  final String id; // UUID now
  final String name;
  final String? posterPath;
  final bool isPinned;

  // Movies are loaded separately via relation query
  final List<Movie> movies;

  Franchise({
    required this.id,
    required this.name,
    required this.posterPath,
    required this.movies,
    this.isPinned = false,
  });

  // -------------------------
  // Computed Properties
  // -------------------------

  int get watchedCount => movies.where((m) => m.watched).length;

  bool get isCompleted => movies.isNotEmpty && movies.every((m) => m.watched);

  double get progress {
    if (movies.isEmpty) return 0;
    return watchedCount / movies.length;
  }

  // -------------------------
  // Supabase JSON Parsing
  // -------------------------

  factory Franchise.fromJson(
    Map<String, dynamic> json, {
    List<Movie> movies = const [],
  }) {
    return Franchise(
      id: json['id'],
      name: json['name'],
      posterPath: json['poster_path'], // snake_case for DB
      isPinned: json['is_pinned'] ?? false,
      movies: movies,
    );
  }

  Map<String, dynamic> toInsertJson(String userId) {
    return {
      'name': name,
      'poster_path': posterPath,
      'is_pinned': isPinned,
      'user_id': userId,
    };
  }
}
