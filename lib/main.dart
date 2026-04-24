import 'auth/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:flutter/material.dart';
import 'package:movie_watchlist/core/supabase_client.dart';
import 'services/series_service.dart';
import 'movies/movies_screen.dart';
import 'pick/smart_pick_screen.dart';
import 'series/series_screen.dart';
import 'folders/folders_screen.dart';
import 'franchise/franchise_screen.dart';
import 'stats/stats_screen.dart';
import 'services/franchise_service.dart';
import 'auth/reset_password_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'public/public_watchlist_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'public/random_pick_screen.dart';
import 'package:app_links/app_links.dart';

final GlobalKey<ScaffoldMessengerState> rootMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://eeuerrrdwrgmdeyfkmjq.supabase.co',
    anonKey: 'sb_publishable_yHNJ-O-I0wetmk6b4Dg72A_JcQ6Y9vk',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  runApp(const CineListApp());
}

class CineListApp extends StatelessWidget {
  const CineListApp({super.key});

  @override
  Widget build(BuildContext context) {
    final uri = Uri.base;

    // 🔥 HANDLE RESET PASSWORD LINK
    final hasAccessToken = uri.fragment.contains('access_token');

    if (hasAccessToken) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0F172A),
          useMaterial3: true,
        ),
        home: const ResetPasswordScreen(),
      );
    }

    Widget startPage = const AuthGate();

    // Public watchlist logic
    if (uri.pathSegments.isNotEmpty && uri.pathSegments[0] == 'u') {
      final username = uri.pathSegments.length > 1 ? uri.pathSegments[1] : '';

      if (uri.pathSegments.length > 2 && uri.pathSegments[2] == 'pick') {
        startPage = RandomPickScreen(username: username);
      } else {
        startPage = PublicWatchlistScreen(username: username);
      }
    }

    return MaterialApp(
      scaffoldMessengerKey: rootMessengerKey,
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        useMaterial3: true,
      ),
      home: startPage,
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<AuthState> _authSub;

  @override
  void initState() {
    super.initState();

    // 🔥 Listen for deep links (ANDROID FIX)
    AppLinks().uriLinkStream.listen((Uri uri) {
      if (uri.fragment.contains('access_token')) {
        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ResetPasswordScreen(),
          ),
        );
      }
    });

    // Existing auth listener
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;

      if (event == AuthChangeEvent.passwordRecovery) {
        Future.microtask(() {
          if (!mounted) return;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ResetPasswordScreen(),
            ),
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _authSub.cancel(); // ✅ prevent memory leak
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final currentSession =
            snapshot.hasData ? snapshot.data!.session : session;

        // 🔥 IMPORTANT FIX
        final isRecovery =
            snapshot.data?.event == AuthChangeEvent.passwordRecovery;

        if (isRecovery) {
          return const ResetPasswordScreen();
        }

        if (currentSession != null) {
          return const WatchlistScreen();
        }

        return const LoginScreen();
      },
    );
  }
}

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  final GlobalKey foldersKey = GlobalKey();
  int filter = 0;
  int folderFilterMode = 0;

  int otherFilterMode = 0;
  int otherSortMode = 0;

  bool showPinnedOnly = false;
  bool sortByRating = false;

  int tab = 0;

  final searchController = TextEditingController();

  String searchQuery = '';
  bool searching = false;

  Widget? _buildFAB() {
    switch (tab) {
      case 1:
        return FloatingActionButton(
          onPressed: () async {
            final bool added = await FoldersScreen.openAddFolder(context);

            if (added) {
              if (foldersKey.currentState != null) {
                (foldersKey.currentState as dynamic).fetchFolders();
              }
            }
          },
          child: const Icon(Icons.create_new_folder),
        );

      case 2:
        return FloatingActionButton(
          onPressed: () async {
            final controller = TextEditingController();

            await showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text("Add Franchise"),
                content: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: "Harry Potter, LOTR",
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final name = controller.text.trim();
                      if (name.isEmpty) return;

                      Navigator.pop(context);

                      final service = FranchiseService();

                      // run in background
                      await service.createFranchise(name: name);

                      if (!mounted) return;

                      setState(() {});
                    },
                    child: const Text("Add"),
                  ),
                ],
              ),
            );
          },
          child: const Icon(Icons.add),
        );

      case 3:
        return FloatingActionButton(
          onPressed: () async {
            final controller = TextEditingController();
            final service = SeriesService();

            await showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text("Add Series"),
                content: TextField(
                  controller: controller,
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
                      final name = controller.text.trim();
                      if (name.isEmpty) return;

                      Navigator.pop(context); // close dialog first

                      // run series creation in background
                      service.createSeries(title: name);

// immediately refresh UI
                      setState(() {
                        tab = 3;
                      });
                    },
                    child: const Text("Add"),
                  ),
                ],
              ),
            );
          },
          child: const Icon(Icons.add),
        );

      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final firstLetter = (user?.email != null && user!.email!.isNotEmpty)
        ? user.email![0].toUpperCase()
        : 'U';

    return Scaffold(
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.amber,
        unselectedItemColor: Colors.grey,
        currentIndex: tab,
        onTap: (i) {
          FocusScope.of(context).unfocus();
          setState(() => tab = i);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.movie), label: 'Movies'),
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Folders'),
          BottomNavigationBarItem(
              icon: Icon(Icons.auto_awesome), label: 'Franchise'),
          BottomNavigationBarItem(icon: Icon(Icons.tv), label: 'Series'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Stats'),
        ],
      ),
      floatingActionButton: _buildFAB(),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            floating: true,
            snap: true,
            elevation: 0,
            leading: GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("Account"),
                    content: const Text("Do you want to logout?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel"),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);

                          await supabase.auth.signOut();

                          if (!mounted) return;

                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => LoginScreen()),
                            (route) => false,
                          );
                        },
                        child: const Text("Logout"),
                      ),
                    ],
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.amber,
                  child: Text(
                    firstLetter,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            title: searching
                ? SizedBox(
                    height: 36,
                    child: TextField(
                      controller: searchController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Search',
                        border: InputBorder.none,
                      ),
                      onChanged: (v) => setState(() => searchQuery = v),
                    ),
                  )
                : const Text('CineList'),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: "Share Watchlist",
                onPressed: () async {
                  final user = supabase.auth.currentUser;
                  if (user == null) return;

                  final username = user.email!.split('@')[0];
                  final link = "https://cinelist-six.vercel.app/u/$username";
                  final text = "Check out my CineList watchlist 🎬\n$link";

                  if (kIsWeb) {
                    await Clipboard.setData(ClipboardData(text: link));

                    if (!mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Watchlist link copied to clipboard"),
                      ),
                    );
                  } else {
                    Share.share(text);
                  }
                },
              ),

              /// MOVIES TAB ICONS
              if (tab == 0) ...[
                IconButton(
                  icon: Icon(
                    filter == 0
                        ? Icons.visibility
                        : filter == 1
                            ? Icons.visibility_outlined
                            : Icons.visibility_off,
                    color: Colors.amber,
                  ),
                  onPressed: () {
                    setState(() {
                      filter = (filter + 1) % 3;
                    });
                  },
                ),
                IconButton(
                  tooltip: "Folder Filter",
                  icon: Icon(
                    folderFilterMode == 0
                        ? Icons.folder
                        : folderFilterMode == 1
                            ? Icons.folder_open
                            : Icons.folder_off,
                    color: Colors.amber,
                  ),
                  onPressed: () {
                    setState(() {
                      folderFilterMode = (folderFilterMode + 1) % 3;
                    });
                  },
                ),
                IconButton(
                  icon: Icon(searching ? Icons.close : Icons.search),
                  onPressed: () {
                    setState(() {
                      searching = !searching;
                      searchController.clear();
                      searchQuery = '';
                    });
                  },
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: (sortByRating || showPinnedOnly)
                        ? Colors.amber
                        : Colors.white,
                  ),
                  onSelected: (value) {
                    if (value == 'pin') {
                      setState(() => showPinnedOnly = !showPinnedOnly);
                    }

                    if (value == 'rating') {
                      setState(() => sortByRating = !sortByRating);
                    }

                    if (value == 'smart') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SmartPickScreen(
                            source: SmartPickSource.movies,
                          ),
                        ),
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    CheckedPopupMenuItem(
                      value: 'rating',
                      checked: sortByRating,
                      child: const Text('Sort by IMDb'),
                    ),
                    CheckedPopupMenuItem(
                      value: 'pin',
                      checked: showPinnedOnly,
                      child: const Text('Pinned Only'),
                    ),
                    const PopupMenuItem(
                      value: 'smart',
                      child: Text('Smart Pick'),
                    ),
                  ],
                ),
              ],

              /// FOLDERS TAB ICONS
              if (tab == 1) ...[
                IconButton(
                  icon: Icon(
                    otherFilterMode == 0
                        ? Icons.visibility
                        : otherFilterMode == 1
                            ? Icons.visibility_outlined
                            : Icons.visibility_off,
                    color: Colors.amber,
                  ),
                  onPressed: () {
                    setState(() {
                      otherFilterMode = (otherFilterMode + 1) % 3;
                    });
                  },
                ),
                IconButton(
                  icon: Icon(
                    showPinnedOnly ? Icons.push_pin : Icons.push_pin_outlined,
                    color: showPinnedOnly ? Colors.amber : Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      showPinnedOnly = !showPinnedOnly;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.sort),
                  onPressed: () {
                    setState(() {
                      otherSortMode = otherSortMode == 2 ? 1 : 2;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.casino),
                  tooltip: "Smart Pick",
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SmartPickScreen(
                          source: SmartPickSource.folders,
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: Icon(searching ? Icons.close : Icons.search),
                  onPressed: () {
                    setState(() {
                      searching = !searching;
                    });
                  },
                ),
              ],

              /// ⭐ FRANCHISE TAB ICONS
              if (tab == 2) ...[
                IconButton(
                  icon: Icon(
                    otherFilterMode == 0
                        ? Icons.visibility
                        : otherFilterMode == 1
                            ? Icons.visibility_outlined
                            : Icons.visibility_off,
                    color: Colors.amber,
                  ),
                  onPressed: () {
                    setState(() {
                      otherFilterMode = (otherFilterMode + 1) % 3;
                    });
                  },
                ),
                IconButton(
                  icon: Icon(
                    showPinnedOnly ? Icons.push_pin : Icons.push_pin_outlined,
                    color: showPinnedOnly ? Colors.amber : Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      showPinnedOnly = !showPinnedOnly;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.sort),
                  onPressed: () {
                    setState(() {
                      otherSortMode = (otherSortMode + 1) % 3;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.casino),
                  tooltip: "Smart Pick",
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SmartPickScreen(
                          source: SmartPickSource.franchise,
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: Icon(searching ? Icons.close : Icons.search),
                  onPressed: () {
                    setState(() {
                      searching = !searching;
                    });
                  },
                ),
              ],

              /// SERIES TAB ICONS
              if (tab == 3) ...[
                IconButton(
                  icon: Icon(
                    SeriesScreen.eyeMode == 0
                        ? Icons.visibility
                        : SeriesScreen.eyeMode == 1
                            ? Icons.visibility_outlined
                            : Icons.visibility_off,
                    color: Colors.amber,
                  ),
                  onPressed: () {
                    setState(() {
                      SeriesScreen.eyeMode = (SeriesScreen.eyeMode + 1) % 3;
                    });
                  },
                ),
                IconButton(
                  icon: Icon(
                    SeriesScreen.showPinnedOnly
                        ? Icons.push_pin
                        : Icons.push_pin_outlined,
                    color: SeriesScreen.showPinnedOnly
                        ? Colors.amber
                        : Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      SeriesScreen.showPinnedOnly =
                          !SeriesScreen.showPinnedOnly;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.casino),
                  tooltip: "Smart Pick",
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SmartPickScreen(
                          source: SmartPickSource.series,
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: Icon(searching ? Icons.close : Icons.search),
                  onPressed: () {
                    setState(() {
                      searching = !searching;
                      searchController.clear();
                      searchQuery = '';
                    });
                  },
                ),
              ],
            ],
          ),
        ],
        body: Builder(
          builder: (_) {
            switch (tab) {
              case 0:
                return MoviesScreen(
                  key: ValueKey(
                      "$filter-$folderFilterMode-$showPinnedOnly-$sortByRating-$searchQuery"),
                  filter: filter,
                  folderFilterMode: folderFilterMode,
                  showPinnedOnly: showPinnedOnly,
                  sortByRating: sortByRating,
                  searchQuery: searchQuery,
                );

              case 1:
                return FoldersScreen(
                  key: foldersKey,
                  searchQuery: searchQuery,
                  filterMode: otherFilterMode,
                  sortMode: otherSortMode,
                  showPinnedOnly: showPinnedOnly,
                );

              case 2:
                return FranchiseScreen(
                  searchQuery: searchQuery,
                  filterMode: otherFilterMode,
                  sortMode: otherSortMode,
                  showPinnedOnly: showPinnedOnly,
                );

              case 3:
                return SeriesScreen(
                  key: ValueKey(tab),
                  searchQuery: searchQuery,
                );

              default:
                return const StatsScreen();
            }
          },
        ),
      ),
    );
  }
}
