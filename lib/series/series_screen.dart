import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:movie_watchlist/core/supabase_client.dart';
import '../services/series_service.dart';
import 'series_detail_screen.dart';
import '../utils/confirm_delete_dialog.dart';

const String tmdbApiKey = "1a55fd98e9adcb397f4b188cdbc74172";

class SeriesScreen extends StatefulWidget {
  final String searchQuery;

  const SeriesScreen({super.key, required this.searchQuery});

  static void openAddSeries(BuildContext context) {
    final state = context.findAncestorStateOfType<_SeriesScreenState>();
    state?._addSeries();
  }

  static int eyeMode = 0;
  static bool showPinnedOnly = false;

  @override
  State<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<SeriesScreen> {
  final SeriesService _service = SeriesService();

  List<Map<String, dynamic>> _seriesList = [];
  bool _loading = true;

  List<Map<String, dynamic>> _pendingDeletes = [];
  Timer? _deleteTimer;

  // ================= LOAD SERIES =================
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadSeries();
  }

  @override
  void initState() {
    super.initState();
    _loadSeries();
  }

  Future<void> _loadSeries() async {
    final data = await _service.fetchSeries();

    if (!mounted) return;

    setState(() {
      _seriesList = List<Map<String, dynamic>>.from(data);
      _loading = false;
    });
  }

  // ================= DELETE WITH UNDO =================

  // ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    List<Map<String, dynamic>> list = List.from(_seriesList);

// ⭐ PINNED FIRST
    list.sort((a, b) {
      final ap = a['is_pinned'] == true ? 1 : 0;
      final bp = b['is_pinned'] == true ? 1 : 0;
      return bp.compareTo(ap);
    });

    if (widget.searchQuery.isNotEmpty) {
      list = list
          .where((s) => s['name']
              .toLowerCase()
              .contains(widget.searchQuery.toLowerCase()))
          .toList();
    }

    if (SeriesScreen.showPinnedOnly) {
      list = list.where((s) => s['is_pinned'] == true).toList();
    }

    if (SeriesScreen.eyeMode == 1) {
      list = list.where((s) => s['is_completed'] == true).toList();
    } else if (SeriesScreen.eyeMode == 2) {
      list = list.where((s) => s['is_completed'] != true).toList();
    }

    if (list.isEmpty) {
      return Scaffold(
        body: const Center(
          child: Text(
            "No series added yet",
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return Scaffold(
      body: ReorderableListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: list.length,
        onReorder: (oldIndex, newIndex) async {
          if (newIndex > oldIndex) newIndex--;

          final moved = list.removeAt(oldIndex);
          list.insert(newIndex, moved);

          setState(() {
            _seriesList = list;
          });

          await _service.updateSeriesOrder(_seriesList);
        },
        itemBuilder: (_, i) {
          final s = list[i];

          return GestureDetector(
            key: ValueKey(s['id']),

            // ⭐ DOUBLE TAP PIN
            onDoubleTap: () async {
              final pinned = !(s['is_pinned'] ?? false);

              setState(() {
                s['is_pinned'] = pinned;
              });

              await _service.togglePin(s['id'], pinned);

              await _loadSeries();
            },

            child: Dismissible(
              key: ValueKey("dismiss_${s['id']}"),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                color: Colors.red,
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              confirmDismiss: (direction) async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("Delete Series"),
                    content: Text('Delete "${s['name']}" from CineList?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text("Cancel"),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text("Delete"),
                      ),
                    ],
                  ),
                );

                return confirm ?? false;
              },
              onDismissed: (_) async {
                setState(() {
                  _seriesList.removeWhere((e) => e['id'] == s['id']);
                });

                await _service.deleteSeries(s['id']);
              },
              child: Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SeriesDetailScreen(series: s),
                      ),
                    );

                    await _loadSeries();
                  },
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: s['poster_url'] != null
                        ? CachedNetworkImage(
                            imageUrl: s['poster_url'],
                            width: 50,
                            height: 75,
                            fit: BoxFit.cover,
                          )
                        : const Icon(Icons.tv),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          s['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),

                      // ⭐ COMPLETED BADGE
                      if (s['is_completed'] == true)
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Icon(
                            Icons.check_circle,
                            size: 18,
                            color: Colors.greenAccent,
                          ),
                        ),

                      // ⭐ PIN ICON
                      if (s['is_pinned'] == true)
                        const Icon(
                          Icons.push_pin,
                          size: 18,
                          color: Colors.amber,
                        ),
                    ],
                  ),
                  subtitle: Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        "${(s['rating'] ?? 0).toDouble().toStringAsFixed(2)} / 10",
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.drag_handle),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ================= ADD SERIES =================

  void _addSeries() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Add Series"),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: "Breaking Bad, GOT...",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = controller.text.trim();
                if (title.isEmpty) return;

                Navigator.pop(context);

                setState(() {
                  _loading = true;
                });

                await _service.createSeries(title: title);

                await _loadSeries();
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }
}
