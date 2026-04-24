import 'movie.dart';

class Folder {
  /// 🔥 Supabase UUID
  String? id;

  String name;
  final List<Movie> movies;

  bool isPinned;

  /// 🖼 Custom cover image (local only)
  String? customCoverPath;

  Folder({
    this.id,
    required this.name,
    required this.movies,
    this.isPinned = false,
    this.customCoverPath,
  });

  // ✅ SharedPrefs / legacy support
  Map<String, dynamic> toJson() => {
        'name': name,
        'movies': movies.map((e) => e.toJson()).toList(),
        'isPinned': isPinned,
        'customCoverPath': customCoverPath,
      };

  factory Folder.fromJson(Map<String, dynamic> json) => Folder(
        name: json['name'],
        movies: (json['movies'] as List).map((e) => Movie.fromJson(e)).toList(),
        isPinned: json['isPinned'] ?? false,
        customCoverPath: json['customCoverPath'],
      );

  /// 🔥 NEW — Supabase loader
  factory Folder.fromMap(
    Map<String, dynamic> map,
    List<Movie> movies,
  ) =>
      Folder(
        id: map['id'],
        name: map['name'],
        movies: movies,
        isPinned: map['is_pinned'] ?? false,
      );

  /// 🎬 Default cover logic
  String? get autoCover {
    if (customCoverPath != null) return customCoverPath;
    if (movies.isNotEmpty) {
      return movies.first.posterPath;
    }
    return null;
  }
}
