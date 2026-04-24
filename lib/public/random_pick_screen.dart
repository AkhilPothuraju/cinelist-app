import 'dart:math';
import 'package:flutter/material.dart';
import 'package:movie_watchlist/core/supabase_client.dart';

class RandomPickScreen extends StatefulWidget {
  final String username;

  const RandomPickScreen({super.key, required this.username});

  @override
  State<RandomPickScreen> createState() => _RandomPickScreenState();
}

class _RandomPickScreenState extends State<RandomPickScreen> {
  Map? pickedMovie;
  bool loading = true;

  Future<void> pickMovie() async {
    setState(() {
      loading = true;
    });

    final profile = await supabase
        .from('profiles')
        .select('id')
        .eq('username', widget.username)
        .single();

    final userId = profile['id'];

    final movies = await supabase.from('movies').select().eq('user_id', userId);

    if (movies.isEmpty) {
      setState(() {
        loading = false;
      });
      return;
    }

    final random = Random();
    pickedMovie = movies[random.nextInt(movies.length)];

    setState(() {
      loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    pickMovie();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Pick from ${widget.username}'s Watchlist"),
      ),
      body: Center(
        child: loading
            ? const CircularProgressIndicator()
            : pickedMovie == null
                ? const Text("No movies found")
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (pickedMovie!['poster_path'] != null)
                        Image.network(
                          "https://image.tmdb.org/t/p/w500${pickedMovie!['poster_path']}",
                          height: 300,
                        ),
                      const SizedBox(height: 20),
                      Text(
                        pickedMovie!['title'],
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: pickMovie,
                        child: const Text("Pick Another"),
                      )
                    ],
                  ),
      ),
    );
  }
}
