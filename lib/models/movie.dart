class Movie {
  String? docId;

  String title;

  String? posterPath;

  String? backdropPath;

  String? overview;

  String? year; // ⭐ NEW

  double imdbRating;

  bool watched;

  bool isFavorite;

  bool isPinned;

  int orderIndex;

  Movie({
    this.docId,
    required this.title,
    this.posterPath,
    this.backdropPath,
    this.overview,
    this.year, // ⭐ NEW
    this.imdbRating = 0.0,
    this.watched = false,
    this.isFavorite = false,
    this.isPinned = false,
    this.orderIndex = 0,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'posterPath': posterPath,
        'backdropPath': backdropPath,
        'overview': overview,
        'year': year, // ⭐ NEW
        'imdbRating': imdbRating,
        'watched': watched,
        'isFavorite': isFavorite,
        'isPinned': isPinned,
        'orderIndex': orderIndex,
      };

  factory Movie.fromJson(Map<String, dynamic> json, {String? docId}) => Movie(
        docId: docId,
        title: json['title'],
        posterPath: json['posterPath'],
        backdropPath: json['backdropPath'],
        overview: json['overview'],
        year: json['year'], // ⭐ NEW
        imdbRating: (json['imdbRating'] ?? 0).toDouble(),
        watched: json['watched'] ?? false,
        isFavorite: json['isFavorite'] ?? false,
        isPinned: json['isPinned'] ?? false,
        orderIndex: json['orderIndex'] ?? 0,
      );

  factory Movie.fromMap(Map<String, dynamic> map) => Movie(
        docId: map['id'],
        title: map['title'],
        posterPath: map['poster_path'],
        backdropPath: map['backdrop_path'],
        overview: map['overview'],
        year: map['year'], // ⭐ NEW
        imdbRating: (map['imdb_rating'] as num?)?.toDouble() ?? 0.0,
        watched: map['watched'] ?? false,
        isFavorite: map['is_favorite'] ?? false,
        isPinned: map['is_pinned'] ?? false,
        orderIndex: map['order_index'] ?? 0,
      );

  String? get bestImage => posterPath ?? backdropPath;

  static int sortByOrder(Movie a, Movie b) =>
      a.orderIndex.compareTo(b.orderIndex);

  static int sortPinnedThenOrder(Movie a, Movie b) {
    if (a.isFavorite && !b.isFavorite) return -1;
    if (!a.isFavorite && b.isFavorite) return 1;

    return a.orderIndex.compareTo(b.orderIndex);
  }
}
