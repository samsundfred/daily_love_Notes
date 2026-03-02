import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  await NotificationService().init();
  runApp(const LoveApp());
}

const githubUrl =
    "https://raw.githubusercontent.com/samsundfred/daily_love_Notes/main/messages.json";

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
  List<String> messages = [
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

  String currentMessage = "";
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _loadLocalMessages().then((_) => _generateMessage());
    NotificationService().scheduleDailyNotification(messages);
  }

  Future<void> _loadLocalMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('messages');
    if (stored != null && stored.isNotEmpty) {
      messages = stored;
    }
  }

  void _generateMessage() {
    final random = Random();
    setState(() {
      if (messages.isNotEmpty) {
        currentMessage = messages[random.nextInt(messages.length)];
      } else {
        currentMessage = "I love you ❤️";
      }
    });
  }

  Future<void> _saveFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> favorites = prefs.getStringList('favorites') ?? [];
    if (!favorites.contains(currentMessage)) {
      favorites.add(currentMessage);
      await prefs.setStringList('favorites', favorites);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Saved to favorites ❤️")),
      );
    }
  }

  void _openFavorites() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FavoritesScreen()),
    );
  }

  Future<void> _updateMessages() async {
    setState(() => loading = true);
    final prefs = await SharedPreferences.getInstance();

    try {
      final response = await http
          .get(Uri.parse(githubUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<String> onlineMessages = [];
        if (decoded is List) {
          onlineMessages = decoded.map((e) => e.toString()).toList();
        }

        int added = 0;
        List<String> normalizedLocal =
        messages.map((m) => m.trim()).toList();

        for (var msg in onlineMessages) {
          String nMsg = msg.trim();
          if (!normalizedLocal.contains(nMsg)) {
            messages.add(msg);
            normalizedLocal.add(nMsg);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Daily Love Notes"),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite),
            onPressed: _openFavorites,
          )
        ],
      ),
      body: Center(
        child: loading
            ? const CircularProgressIndicator()
            : Padding(
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
            heroTag: "save",
            onPressed: _saveFavorite,
            child: const Icon(Icons.bookmark),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: "update",
            onPressed: _updateMessages,
            child: const Icon(Icons.cloud_download),
          ),
        ],
      ),
    );
  }
}

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<String> favorites = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      favorites = prefs.getStringList('favorites') ?? [];
    });
  }

  Future<void> _removeFavorite(String message) async {
    final prefs = await SharedPreferences.getInstance();
    favorites.remove(message);
    await prefs.setStringList('favorites', favorites);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Favorites")),
      body: favorites.isEmpty
          ? const Center(child: Text("No favorites yet 💔"))
          : ListView.builder(
        itemCount: favorites.length,
        itemBuilder: (context, index) {
          return ListTile(
            leading: const Icon(Icons.favorite),
            title: Text(favorites[index]),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _removeFavorite(favorites[index]),
            ),
          );
        },
      ),
    );
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  void scheduleDailyNotification(List<String> messages) async {
    if (messages.isEmpty) return;

    final random = Random();
    final message = messages[random.nextInt(messages.length)];

    await flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      'Daily Love Note 💌',
      message,
      _nextInstanceOfTime(9, 0), // 9:00 AM daily
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_love_notes_channel',
          'Daily Love Notes',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
      ),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled =
    tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}