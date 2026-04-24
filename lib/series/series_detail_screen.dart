import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:movie_watchlist/core/supabase_client.dart';
import '../services/series_service.dart';
import '../utils/confirm_delete_dialog.dart';

class SeriesDetailScreen extends StatefulWidget {
  final Map<String, dynamic> series;

  const SeriesDetailScreen({
    super.key,
    required this.series,
  });

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  final SeriesService _service = SeriesService();

  Map<String, dynamic>? series;
  List<Map<String, dynamic>> seasons = [];
  Map<String, List<Map<String, dynamic>>> episodesBySeason = {};

  bool loading = true;

  String get seriesId => widget.series['id'];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  // ================= LOAD DATA =================

  Future<void> _loadAll() async {
    try {
      final seriesData =
          await supabase.from('series').select().eq('id', seriesId).single();

      final seasonList = await _service.fetchSeasons(seriesId);

      // FIX: sort seasons
      seasonList
          .sort((a, b) => a['season_number'].compareTo(b['season_number']));

      final Map<String, List<Map<String, dynamic>>> episodeMap = {};

      for (final s in seasonList) {
        final eps = await _service.fetchEpisodes(s['id']);

        // FIX: sort episodes
        eps.sort((a, b) => a['episode_number'].compareTo(b['episode_number']));

        episodeMap[s['id']] = eps;
      }

      if (!mounted) return;

      setState(() {
        series = seriesData;
        seasons = seasonList;
        episodesBySeason = episodeMap;
        loading = false;
      });
    } catch (e) {
      debugPrint("Series detail error: $e");
    }
  }

  // ================= EPISODE TOGGLE =================

  Future<void> _toggleEpisode(String episodeId, bool currentValue) async {
    final newValue = !currentValue;

    setState(() {
      for (final season in episodesBySeason.values) {
        for (final ep in season) {
          if (ep['id'] == episodeId) {
            ep['is_watched'] = newValue;
          }
        }
      }
    });

    await _service.toggleEpisodeWatched(
      episodeId,
      newValue,
      seriesId,
    );
  }

  // ================= SEASON TOGGLE =================

  Future<void> _toggleSeason(String seasonId, bool value) async {
    final eps = episodesBySeason[seasonId] ?? [];

    // ⭐ instant UI update
    setState(() {
      for (final ep in eps) {
        ep['is_watched'] = value;
      }
    });

    // ⭐ update DB in parallel (fast)
    await Future.wait(
      eps.map((ep) {
        return _service.toggleEpisodeWatched(
          ep['id'],
          value,
          seriesId,
        );
      }),
    );
  }
  // ================= DELETE SERIES =================

  Future<void> _deleteSeries() async {
    await _service.deleteSeries(seriesId);

    if (mounted) {}
  }

  // ================= BUILD =================

  @override
  Widget build(BuildContext context) {
    if (loading || series == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    int total = 0;
    int watched = 0;

    for (final eps in episodesBySeason.values) {
      total += eps.length;
      watched += eps.where((e) => e['is_watched'] == true).length;
    }

    final progress = total == 0 ? 0.0 : watched / total;
    final isCompleted = total > 0 && watched == total;

    return Scaffold(
      appBar: AppBar(
        title: Text(series!['name'] ?? ""),
        actions: [
          if (isCompleted)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.check_circle, color: Colors.amber),
            ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () async {
              final confirm = await confirmDelete(
                context,
                title: "Delete Series",
                message: 'Delete "${series!['name']}"?',
              );

              if (confirm) {
                await _deleteSeries();
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= HEADER =================

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (series!['poster_url'] != null &&
                    series!['poster_url'] != "")
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: series!['poster_url'],
                      width: 130,
                      height: 190,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        series!['name'] ?? "",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (series!['rating'] != null)
                        Row(
                          children: [
                            const Icon(Icons.star,
                                color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              (series!['rating'] as num).toStringAsFixed(2),
                              style: const TextStyle(
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      if (series!['overview'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            series!['overview'],
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "$watched / $total episodes watched",
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),

            // ================= SEASONS =================

            ...seasons.map((season) {
              final eps = episodesBySeason[season['id']] ?? [];

              final allWatched =
                  eps.isNotEmpty && eps.every((e) => e['is_watched'] == true);

              final noneWatched =
                  eps.isNotEmpty && eps.every((e) => e['is_watched'] != true);

              bool? seasonChecked = allWatched
                  ? true
                  : noneWatched
                      ? false
                      : null;

              return Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Season ${season['season_number']}",
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Checkbox(
                          tristate: true,
                          value: seasonChecked,
                          onChanged: (val) async {
                            // toggle correctly even when partially checked
                            bool newValue = !(seasonChecked ?? false);

                            await _toggleSeason(season['id'], newValue);

                            setState(() {});
                          },
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: eps.map((ep) {
                        final watched = ep['is_watched'] == true;

                        return GestureDetector(
                          onTap: () => _toggleEpisode(ep['id'], watched),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color:
                                  watched ? Colors.greenAccent : Colors.white12,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "${ep['episode_number']}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: watched ? Colors.black : Colors.white,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
