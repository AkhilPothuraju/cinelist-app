import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:movie_watchlist/core/supabase_client.dart';

const String tmdbApiKey = "1a55fd98e9adcb397f4b188cdbc74172";
const String imageBaseUrl = "https://image.tmdb.org/t/p/w500";

class SeriesService {
  final SupabaseClient _client = supabase;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception("User not logged in");
    }
    return user.id;
  }

  // ================= FETCH SERIES =================

  Future<List<Map<String, dynamic>>> fetchSeries() async {
    final res = await _client
        .from('series')
        .select()
        .eq('user_id', _userId)
        .order('order_index');

    return List<Map<String, dynamic>>.from(res);
  }

  // ================= CREATE SERIES =================

  Future<void> createSeries({required String title}) async {
    final search = await fetchSeriesFromTMDB(title);
    if (search == null) return;

    final tmdbId = search['id'];

    final detailRes = await http.get(
      Uri.parse("https://api.themoviedb.org/3/tv/$tmdbId?api_key=$tmdbApiKey"),
    );

    if (detailRes.statusCode != 200) return;

    final data = jsonDecode(detailRes.body);

    final name = data['name'];
    final rating = (data['vote_average'] ?? 0).toDouble();
    final overview = data['overview'];

    String? poster;
    if (data['poster_path'] != null) {
      poster = "$imageBaseUrl${data['poster_path']}";
    }

    /// 🚫 prevent duplicate series
    final existing = await _client
        .from('series')
        .select('id')
        .eq('user_id', _userId)
        .eq('name', name);

    if (existing.isNotEmpty) return;

    final current =
        await _client.from('series').select('id').eq('user_id', _userId);

    final orderIndex = current.length;

    final inserted = await _client
        .from('series')
        .insert({
          'user_id': _userId,
          'name': name,
          'poster_url': poster,
          'rating': rating,
          'overview': overview,
          'total_seasons': data['number_of_seasons'] ?? 0,
          'total_episodes': data['number_of_episodes'] ?? 0,
          'watched_episodes': 0,
          'progress': 0,
          'is_pinned': false,
          'is_completed': false,
          'order_index': orderIndex,
        })
        .select()
        .single();

    final seriesId = inserted['id'];

    final seasons = List<Map<String, dynamic>>.from(data['seasons'] ?? []);
    seasons.removeWhere((s) => s['season_number'] == 0);

    /// ⚡ INSERT SEASONS IN BATCH
    final seasonRows = seasons.map((s) {
      final num = s['season_number'];
      return {
        'series_id': seriesId,
        'season_number': num,
        'name': s['name'] ?? "Season $num",
      };
    }).toList();

    final insertedSeasons =
        await _client.from('seasons').insert(seasonRows).select();

    /// ⚡ FETCH EPISODES IN PARALLEL
    final episodeLists = await Future.wait(
      insertedSeasons.map((season) {
        return fetchEpisodesFromTMDB(tmdbId, season['season_number']);
      }),
    );

    final allEpisodes = <Map<String, dynamic>>[];

    for (int i = 0; i < insertedSeasons.length; i++) {
      final seasonId = insertedSeasons[i]['id'];
      final eps = episodeLists[i];

      for (final ep in eps) {
        allEpisodes.add({
          'season_id': seasonId,
          'episode_number': ep['episode_number'],
          'name': ep['name'] ?? "Episode ${ep['episode_number']}",
          'is_watched': false,
        });
      }
    }

    /// ⚡ BATCH INSERT EPISODES
    if (allEpisodes.isNotEmpty) {
      await _client.from('episodes').insert(allEpisodes);
    }

    print("Series inserted: $name");
  }

  // ================= DELETE SERIES =================

  Future<void> deleteSeries(String id) async {
    await _client.from('series').delete().eq('id', id);
  }

  // ================= FETCH SEASONS =================

  Future<List<Map<String, dynamic>>> fetchSeasons(String seriesId) async {
    final res = await _client
        .from('seasons')
        .select()
        .eq('series_id', seriesId)
        .order('season_number');

    return List<Map<String, dynamic>>.from(res);
  }

  // ================= FETCH EPISODES =================

  Future<List<Map<String, dynamic>>> fetchEpisodes(String seasonId) async {
    final res = await _client
        .from('episodes')
        .select()
        .eq('season_id', seasonId)
        .order('episode_number');

    return List<Map<String, dynamic>>.from(res);
  }

  // ================= TOGGLE EPISODE =================

  Future<void> toggleEpisodeWatched(
      String episodeId, bool value, String seriesId) async {
    await _client
        .from('episodes')
        .update({'is_watched': value}).eq('id', episodeId);

    // get all seasons for this series
    final seasons =
        await _client.from('seasons').select('id').eq('series_id', seriesId);

    int total = 0;
    int watched = 0;

    for (final season in seasons) {
      final eps = await _client
          .from('episodes')
          .select('is_watched')
          .eq('season_id', season['id']);

      total += eps.length;
      watched += eps.where((e) => e['is_watched'] == true).length;
    }

    double progress = total == 0 ? 0 : watched / total;
    bool completed = watched == total && total > 0;

    await _client.from('series').update({
      'watched_episodes': watched,
      'progress': progress,
      'is_completed': completed,
    }).eq('id', seriesId);
  }

  // ================= PIN SERIES =================

  Future<void> togglePin(String id, bool value) async {
    await _client.from('series').update({'is_pinned': value}).eq('id', id);
  }

  // ================= UPDATE ORDER =================

  Future<void> updateSeriesOrder(List<Map<String, dynamic>> list) async {
    for (int i = 0; i < list.length; i++) {
      await _client
          .from('series')
          .update({'order_index': i}).eq('id', list[i]['id']);
    }
  }
}

// ================= TMDB SEARCH =================

Future<Map<String, dynamic>?> fetchSeriesFromTMDB(String title) async {
  final res = await http.get(
    Uri.parse(
        "https://api.themoviedb.org/3/search/tv?api_key=$tmdbApiKey&query=${Uri.encodeComponent(title)}"),
  );

  if (res.statusCode != 200) return null;

  final data = jsonDecode(res.body);

  if (data['results'] == null || data['results'].isEmpty) return null;

  return data['results'][0];
}

// ================= TMDB EPISODES =================

Future<List<Map<String, dynamic>>> fetchEpisodesFromTMDB(
    int id, int season) async {
  final res = await http.get(
    Uri.parse(
        "https://api.themoviedb.org/3/tv/$id/season/$season?api_key=$tmdbApiKey"),
  );

  if (res.statusCode != 200) return [];

  final data = jsonDecode(res.body);

  return List<Map<String, dynamic>>.from(data['episodes'] ?? []);
}
