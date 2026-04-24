import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/movie.dart';
import '../core/supabase_client.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../core/supabase_client.dart';

class EditMovieScreen extends StatefulWidget {
  final Movie movie;

  const EditMovieScreen({super.key, required this.movie});

  @override
  State<EditMovieScreen> createState() => _EditMovieScreenState();
}

class _EditMovieScreenState extends State<EditMovieScreen> {
  final ImagePicker picker = ImagePicker();

  Future<void> pickImage() async {
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    final file = File(image.path);

    final fileName =
        "${DateTime.now().millisecondsSinceEpoch}_${widget.movie.docId}.jpg";

    await supabase.storage.from('posters').upload(
          'movies/$fileName',
          file,
        );

    final publicUrl =
        supabase.storage.from('posters').getPublicUrl('movies/$fileName');

    setState(() {
      posterController.text = publicUrl;
    });
  }

  late TextEditingController titleController;
  late TextEditingController ratingController;
  late TextEditingController posterController;

  bool watched = false;

  @override
  void initState() {
    super.initState();

    titleController = TextEditingController(text: widget.movie.title);
    ratingController =
        TextEditingController(text: widget.movie.imdbRating.toString());
    posterController =
        TextEditingController(text: widget.movie.posterPath ?? "");

    watched = widget.movie.watched;
  }

  Future<void> saveMovie() async {
    await supabase.from('movies').update({
      "title": titleController.text.trim(),
      "poster_path": posterController.text.trim(),
      "imdb_rating": double.tryParse(ratingController.text) ?? 0,
      "watched": watched,
      "lowercase_title": titleController.text.toLowerCase(),
    }).eq("id", widget.movie.docId!);

    if (!mounted) return;

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Movie"),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: saveMovie,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: "Movie Title"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ratingController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "IMDb Rating"),
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: posterController,
                  decoration: const InputDecoration(labelText: "Poster URL"),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: pickImage,
                  icon: const Icon(Icons.photo),
                  label: const Text("Choose Photo from Gallery"),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text("Watched"),
              value: watched,
              onChanged: (v) {
                setState(() {
                  watched = v;
                });
              },
            ),
            const SizedBox(height: 20),
            if (posterController.text.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  posterController.text.startsWith("http")
                      ? posterController.text
                      : "https://image.tmdb.org/t/p/w500${posterController.text}",
                  height: 220,
                  fit: BoxFit.cover,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
