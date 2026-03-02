import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.local);
  await NotificationService.initialize();
  runApp(const LoveApp());
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _notifications.initialize(initSettings);

    // 🔔 Request permission for Android 13+
    await _notifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> scheduleDailyNotifications(List<String> messages) async {
    await _notifications.cancelAll();

    final prefs = await SharedPreferences.getInstance();

    List<String> remaining =
        prefs.getStringList('remaining_rotation') ?? List.from(messages);

    if (remaining.isEmpty) {
      remaining = List.from(messages);
    }

    remaining.shuffle();

    final morningMessage = remaining.removeLast();
    final nightMessage =
    remaining.isNotEmpty ? remaining.removeLast() : morningMessage;

    await prefs.setStringList('remaining_rotation', remaining);

    await _scheduleAt(9, 0, morningMessage, 0);
    await _scheduleAt(21, 0, nightMessage, 1);
  }

  static Future<void> _scheduleAt(
      int hour, int minute, String message, int id) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
    tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'daily_love_channel',
      'Daily Love Notes',
      channelDescription: 'Daily love quotes',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    await _notifications.zonedSchedule(
      id,
      'Daily Love Note ❤️',
      message,
      scheduled,
      const NotificationDetails(android: androidDetails),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}

class LoveApp extends StatelessWidget {
  const LoveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daily Love Notes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.pink,
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<String> bakedInMessages = [
    "I love the way your mind works.",
    "You make my life softer just by being in it.",
    "You don’t have to be perfect to be incredible.",
    "I feel lucky to love you.",
    "You are more than enough.",
    "You make ordinary days feel special.",
    "I admire your strength.",
    "You inspire me more than you know.",
    "Being yours feels like home.",
    "You are deeply appreciated."
  ];

  List<String> messages = [];
  List<String> favorites = [];
  String currentMessage = "";
  bool loading = true;

  final githubUrl =
      'https://raw.githubusercontent.com/samsundfred/daily_love_Notes/main/messages.json';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();

    favorites = prefs.getStringList('favorites') ?? [];
    messages = prefs.getStringList('messages') ?? [];

    if (messages.isEmpty) {
      messages = List.from(bakedInMessages);
      await prefs.setStringList('messages', messages);
    }

    _generateMessage();
    setState(() => loading = false);

    Future.delayed(const Duration(milliseconds: 500), () async {
      try {
        await NotificationService.scheduleDailyNotifications(messages);
      } catch (_) {}
    });
  }

  void _generateMessage() {
    final random = Random();
    setState(() {
      currentMessage = messages[random.nextInt(messages.length)];
    });
  }

  Future<void> _updateMessages() async {
    setState(() => loading = true);
    final prefs = await SharedPreferences.getInstance();

    try {
      final response = await http
          .get(Uri.parse(githubUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> online = jsonDecode(response.body);
        int added = 0;

        for (var msg in online) {
          if (!messages.contains(msg.toString())) {
            messages.add(msg.toString());
            added++;
          }
        }

        if (added > 0) {
          await prefs.setStringList('messages', messages);
          await prefs.remove('remaining_rotation');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Added $added new messages ❤️")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Server error: ${response.statusCode}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Connection failed: $e")),
      );
    }

    setState(() => loading = false);
  }

  Future<void> _toggleFavorite(String message) async {
    final prefs = await SharedPreferences.getInstance();

    if (favorites.contains(message)) {
      favorites.remove(message);
    } else {
      favorites.add(message);
    }

    await prefs.setStringList('favorites', favorites);
    setState(() {});
  }

  void _openFavorites() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FavoritesScreen(
          favorites: favorites,
          onToggle: _toggleFavorite,
        ),
      ),
    ).then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Daily Love Notes"),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite),
            onPressed: _openFavorites,
          ),
          IconButton(
            icon: const Icon(Icons.system_update),
            onPressed: _updateMessages,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Card(
              key: ValueKey(currentMessage),
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  currentMessage,
                  style: const TextStyle(fontSize: 20),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "new",
            onPressed: _generateMessage,
            child: const Icon(Icons.refresh),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: "fav",
            onPressed: () => _toggleFavorite(currentMessage),
            child: Icon(
              favorites.contains(currentMessage)
                  ? Icons.favorite
                  : Icons.favorite_border,
            ),
          ),
        ],
      ),
    );
  }
}

class FavoritesScreen extends StatefulWidget {
  final List<String> favorites;
  final Function(String) onToggle;

  const FavoritesScreen({
    super.key,
    required this.favorites,
    required this.onToggle,
  });

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Favorites")),
      body: widget.favorites.isEmpty
          ? const Center(child: Text("No favorites yet 💔"))
          : ListView.builder(
        itemCount: widget.favorites.length,
        itemBuilder: (context, index) {
          final msg = widget.favorites[index];
          return ListTile(
            leading: const Icon(Icons.favorite, color: Colors.red),
            title: Text(msg),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                widget.onToggle(msg);
                setState(() {});
              },
            ),
          );
        },
      ),
    );
  }
}