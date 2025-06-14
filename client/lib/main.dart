import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/select_singer_screen.dart';
import 'screens/playlist_screen.dart';
import 'screens/preference_screen.dart';
import 'providers/playlist_provider.dart';
import 'providers/conversion_mode_provider.dart';
import 'services/spotify_auth_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:spotify_sdk/spotify_sdk.dart';

Future<void> main() async {
  try {
    await dotenv.load(fileName: ".env");
    print(dotenv.env);
  } catch (e) {
    print('dotenv load error: $e');
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlaylistProvider()),
        ChangeNotifierProvider(create: (_) => ConversionModeProvider()..init()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kirby App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _error;

  Future<void> _authenticate() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await authenticateWithSpotify();
      // 인증 후 강제로 음악 일시정지 (추가 안전장치)
      try {
        await SpotifySdk.pause();
      } catch (e) {
        // 음악이 재생 중이 아니면 무시
      }
      setState(() {
        _isAuthenticated = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print(
      '_isLoading: $_isLoading, _error: $_error, _isAuthenticated: $_isAuthenticated',
    );
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('인증 실패: $_error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _authenticate,
                child: const Text('Login with Spotify'),
              ),
            ],
          ),
        ),
      );
    }
    if (_isAuthenticated) {
      return const MainNavigation();
    }
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: _authenticate,
          child: const Text('Login with Spotify'),
        ),
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({Key? key}) : super(key: key);

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    SelectSingerScreen(),
    PlaylistScreen(),
    PreferenceScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'SelectSinger',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.playlist_play),
            label: 'Playlist',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.tune), label: 'Preference'),
        ],
      ),
    );
  }
}
