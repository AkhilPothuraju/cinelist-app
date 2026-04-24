import 'package:flutter/material.dart';
import '../services/franchise_service.dart';
import '../models/franchise.dart';
import 'franchise_detail_screen.dart';

class FranchiseScreen extends StatefulWidget {
  final String searchQuery;
  final int filterMode;
  final int sortMode;
  final bool showPinnedOnly;

  const FranchiseScreen({
    super.key,
    required this.searchQuery,
    required this.filterMode,
    required this.sortMode,
    required this.showPinnedOnly,
  });

  @override
  State<FranchiseScreen> createState() => _FranchiseScreenState();
}

class _FranchiseScreenState extends State<FranchiseScreen> {
  final FranchiseService _service = FranchiseService();

  List<Franchise> _franchises = [];
  bool loading = true;

  bool selectionMode = false;
  Set<String> selectedFranchises = {};

  @override
  void initState() {
    super.initState();
    _loadFranchises();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFranchises();
    });
  }

  @override
  void didUpdateWidget(covariant FranchiseScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.searchQuery != widget.searchQuery ||
        oldWidget.filterMode != widget.filterMode ||
        oldWidget.sortMode != widget.sortMode ||
        oldWidget.showPinnedOnly != widget.showPinnedOnly) {
      _loadFranchises();
    }
  }
// ================= CREATE FRANCHISE =================

  void _showCreateFranchiseDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Create Franchise"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: "Franchise name",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              child: const Text("Create"),
              onPressed: () {
                final name = controller.text.trim();
                if (name.isEmpty) return;

                // close dialog first
                Navigator.of(dialogContext).pop();

                // run insert AFTER dialog closes
                Future.microtask(() async {
                  try {
                    await _service.createFranchise(name: name);
                    await _loadFranchises();

                    if (!mounted) return;
                  } catch (e) {
                    if (!mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Franchise error: $e")),
                    );
                  }
                });
              },
            ),
          ],
        );
      },
    );
  }

// ================= LOAD =================

  Future<void> _loadFranchises() async {
    try {
      final data = await _service.fetchFranchises();

      if (!mounted) return;

      setState(() {
        _franchises = data;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _franchises = [];
        loading = false;
      });
    }
  }

// ================= DELETE =================

  Future<void> _deleteSelected() async {
    if (selectedFranchises.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Franchise"),
        content: Text(
          "Delete ${selectedFranchises.length} selected franchise(s)?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final deleted = _franchises
        .where((f) => selectedFranchises.contains(f.id ?? ""))
        .toList();

    setState(() {
      _franchises.removeWhere(
        (f) => selectedFranchises.contains(f.id ?? ""),
      );
      selectionMode = false;
      selectedFranchises.clear();
    });

    for (final f in deleted) {
      if (f.id != null) {
        await _service.deleteFranchise(f.id!);
      }
    }
  }

// ================= PIN =================

  Future<void> _togglePin(Franchise f) async {
    await _service.togglePin(f.id ?? "", !f.isPinned);
    await _loadFranchises();
  }

// ================= PROGRESS =================

  double _progress(Franchise f) {
    final movies = f.movies ?? [];
    if (movies.isEmpty) return 0;

    final watched = movies.where((m) => m.watched).length;
    return watched / movies.length;
  }

// ================= BUILD =================

  @override
  Widget build(BuildContext context) {
    List<Franchise> visible = List.from(_franchises);

    if (widget.searchQuery.isNotEmpty) {
      final query = widget.searchQuery.toLowerCase();
      visible = visible.where((f) {
        final name = (f.name ?? "").toLowerCase();
        return name.contains(query);
      }).toList();
    }

    if (widget.showPinnedOnly) {
      visible = visible.where((f) => f.isPinned).toList();
    }

    if (widget.filterMode == 1) {
      visible = visible.where((f) => f.isCompleted).toList();
    } else if (widget.filterMode == 2) {
      visible = visible.where((f) => !f.isCompleted).toList();
    }

    visible.sort((a, b) {
      // pinned always first
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;

      if (widget.sortMode == 1) {
        return _progress(b).compareTo(_progress(a));
      }

      if (widget.sortMode == 2) {
        return _progress(a).compareTo(_progress(b));
      }

      return (a.name ?? "").compareTo(b.name ?? "");
    });

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateFranchiseDialog,
        child: const Icon(Icons.add),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (selectionMode)
                  Container(
                    color: const Color(0xFF020617),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setState(() {
                              selectionMode = false;
                              selectedFranchises.clear();
                            });
                          },
                        ),
                        Text("${selectedFranchises.length} selected"),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: _deleteSelected,
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: visible.isEmpty
                      ? const Center(
                          child: Text(
                            "No franchises yet",
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: visible.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.7,
                          ),
                          itemBuilder: (_, i) {
                            final f = visible[i];
                            final selected =
                                selectedFranchises.contains(f.id ?? "");

                            return GestureDetector(
                              onLongPress: () {
                                setState(() {
                                  selectionMode = true;
                                  selectedFranchises.add(f.id ?? "");
                                });
                              },
                              onTap: () async {
                                if (selectionMode) {
                                  setState(() {
                                    if (selected) {
                                      selectedFranchises.remove(f.id ?? "");
                                    } else {
                                      selectedFranchises.add(f.id ?? "");
                                    }
                                  });
                                  return;
                                }

                                final changed = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FranchiseDetailScreen(
                                      franchise: f,
                                      movies: f.movies ?? [],
                                    ),
                                  ),
                                );

                                if (!mounted) return;

                                if (changed == true) {
                                  await _loadFranchises();
                                }
                              },
                              onDoubleTap: () => _togglePin(f),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    (f.posterPath != null &&
                                            f.posterPath!.isNotEmpty)
                                        ? Image.network(
                                            "https://image.tmdb.org/t/p/w500${f.posterPath}",
                                            fit: BoxFit.cover,
                                          )
                                        : Container(
                                            color: Colors.white12,
                                            child: const Center(
                                              child: Icon(
                                                Icons.movie,
                                                color: Colors.white30,
                                                size: 40,
                                              ),
                                            ),
                                          ),
                                    if (selected)
                                      Container(
                                        color: Colors.red.withOpacity(0.45),
                                        child: const Center(
                                          child: Icon(
                                            Icons.check_circle,
                                            color: Colors.white,
                                            size: 40,
                                          ),
                                        ),
                                      ),
                                    if (f.isPinned)
                                      const Positioned(
                                        top: 10,
                                        left: 10,
                                        child: Icon(
                                          Icons.push_pin,
                                          color: Colors.amber,
                                        ),
                                      ),
                                    if (f.isCompleted)
                                      const Positioned(
                                        top: 10,
                                        right: 10,
                                        child: Icon(
                                          Icons.check_circle,
                                          color: Colors.greenAccent,
                                          size: 26,
                                        ),
                                      ),
                                    Positioned(
                                      bottom: 10,
                                      left: 10,
                                      right: 10,
                                      child: Text(
                                        f.name ?? "Franchise",
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
