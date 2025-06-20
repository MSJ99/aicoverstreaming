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
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:developer';
import 'providers/fcm_token_provider.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  log('백그라운드 메시지: \\${message.messageId}', name: 'FCM');
}

Future<void> main() async {
  try {
    await dotenv.load(fileName: ".env");
    log(dotenv.env.toString(), name: 'FCM');
  } catch (e) {
    log('dotenv load error: $e', name: 'FCM', level: 1000);
  }
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlaylistProvider()),
        ChangeNotifierProvider(create: (_) => ConversionModeProvider()..init()),
        ChangeNotifierProvider(create: (_) => FcmTokenProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _fcmToken;
  String _message = '알림 없음';

  @override
  void initState() {
    super.initState();
    _initFCM();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // FCM 토큰이 있으면 Provider에 저장
    if (_fcmToken != null) {
      final provider = Provider.of<FcmTokenProvider>(context, listen: false);
      provider.setToken(_fcmToken!);
    }
  }

  Future<void> _initFCM() async {
    await FirebaseMessaging.instance.requestPermission();
    String? token = await FirebaseMessaging.instance.getToken();
    log('FCM 토큰: $token', name: 'FCM');
    setState(() {
      _fcmToken = token;
    });
    // Provider 저장은 didChangeDependencies에서!
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kirby App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: AuthGate(),
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
