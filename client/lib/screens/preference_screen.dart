import 'package:flutter/material.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/song.dart';
import 'package:provider/provider.dart';
import '../providers/playlist_provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import 'package:spotify_sdk/spotify_sdk.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/api_client.dart';
import 'dart:convert';
import '../providers/fcm_token_provider.dart';
import '../providers/conversion_mode_provider.dart';
import '../services/secure_storage_service.dart';

/// ConversionModeButton
/// - 변환 모드 ON/OFF를 토글하는 버튼 위젯
class ConversionModeButton extends StatefulWidget {
  final bool initialModeOn;
  final ValueChanged<bool>? onChanged;
  final bool enabled;

  const ConversionModeButton({
    Key? key,
    this.initialModeOn = false,
    this.onChanged,
    this.enabled = true,
  }) : super(key: key);

  @override
  State<ConversionModeButton> createState() => _ConversionModeButtonState();
}

/// _ConversionModeButtonState
/// - 버튼 상태(ON/OFF)를 관리하고, 클릭 시 콜백 호출
class _ConversionModeButtonState extends State<ConversionModeButton> {
  late bool _isModeOn;

  @override
  void initState() {
    super.initState();
    _isModeOn = widget.initialModeOn;
  }

  void _toggleMode() {
    setState(() {
      _isModeOn = !_isModeOn;
    });
    widget.onChanged?.call(_isModeOn);
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: widget.enabled ? _toggleMode : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: _isModeOn ? Colors.blue : Colors.grey[400],
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      child: Text(
        _isModeOn ? 'Conversion Mode: On' : 'Conversion Mode: Off',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// PreferenceScreen
/// - 변환 모드 토글, 음성 변환 테스트, Spotify 연동 등 환경설정 기능을 제공하는 화면
class PreferenceScreen extends StatefulWidget {
  const PreferenceScreen({Key? key}) : super(key: key);

  @override
  State<PreferenceScreen> createState() => _PreferenceScreenState();
}

/// _PreferenceScreenState
/// - 변환 모드, 로딩/에러 상태, Spotify 연동, 음성 변환 요청 등 환경설정 관련 상태와 기능을 관리
class _PreferenceScreenState extends State<PreferenceScreen> {
  bool _conversionModeOn = false;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final currentSelectedSinger =
        Provider.of<ConversionModeProvider>(context).currentSelectedSinger;
    return Scaffold(
      appBar: AppBar(title: const Text('Preference')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (_isLoading) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
              ],
              if (_errorMessage != null) ...[
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
              ],
              // 변환 모드 토글 버튼
              ConversionModeButton(
                initialModeOn: _conversionModeOn,
                onChanged: _onConversionModeChanged,
                enabled: currentSelectedSinger != null && !_isLoading,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  /// 음성 변환 완료 시 플레이리스트에 곡 추가
  void _onVoiceConversionComplete(
    BuildContext context,
    File resultFile,
    String title,
    String artist,
  ) {
    Provider.of<PlaylistProvider>(
      context,
      listen: false,
    ).addSong(Song(title: title, artist: artist, audioUrl: resultFile.path));
  }

  /// 변환 모드 토글 시 서버에 상태 동기화 및 Spotify 상태 체크 타이머 관리
  void _onConversionModeChanged(bool isOn) async {
    setState(() {
      _conversionModeOn = isOn;
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      if (isOn) {
        try {
          // 1. access token 준비
          final accessToken = await secureStorage.read(key: 'accessToken');
          final backendIp = dotenv.env['BACKEND_IP'] ?? '127.0.0.1';
          final backendPort = dotenv.env['BACKEND_PORT'] ?? '5000';
          // 2. 서버에 conversion_mode_info로 변환 모드 ON 신호 전송
          final currentSelectedSinger =
              Provider.of<ConversionModeProvider>(
                context,
                listen: false,
              ).currentSelectedSinger;
          final response = await ApiClient().post(
            Uri.parse('http://$backendIp:$backendPort/conversion_mode_info'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'access_token': accessToken,
              'singer_name': currentSelectedSinger,
              'conversion_mode': 'on',
            }),
          );
          if (response.statusCode == 200) {
            setState(() {
              _errorMessage = null;
            });
          } else {
            final data = jsonDecode(response.body);
            setState(() {
              _errorMessage = data['error'] ?? '변환 모드 시작 실패';
            });
            return;
          }
        } catch (e) {
          setState(() {
            _errorMessage = '변환 모드 시작 실패: $e';
          });
          return;
        }
      } else {
        await setConversionMode(isOn);
      }
      if (!isOn) {
        await setConversionMode(isOn);
      }
    } catch (e) {
      if (e.toString().contains('401')) {
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        setState(() {
          _errorMessage = '변환 모드 변경 실패: $e';
        });
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}

/// 서버에 음성 변환 요청을 보내고 결과 파일을 반환하는 함수
Future<File> requestVoiceConversion(String singer, String song) async {
  final backendIp = dotenv.env['BACKEND_IP'] ?? '127.0.0.1';
  final backendPort = dotenv.env['BACKEND_PORT'] ?? '5000';
  final response = await ApiClient().post(
    Uri.parse('http://$backendIp:$backendPort/convert'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'singer': singer, 'song': song}),
  );
  final dir = await getTemporaryDirectory();
  final uuid = Uuid();
  final file = File('${dir.path}/$singer\_$song\_${uuid.v4()}.wav');
  await file.writeAsBytes(response.bodyBytes);
  return file;
}

/// 서버에 변환 모드 상태를 동기화하는 함수
Future<void> setConversionMode(bool on) async {
  final backendIp = dotenv.env['BACKEND_IP'] ?? '127.0.0.1';
  final backendPort = dotenv.env['BACKEND_PORT'] ?? '5000';
  final response = await ApiClient().post(
    Uri.parse('http://$backendIp:$backendPort/conversion_mode'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'on': on}),
  );
  debugPrint(response.body);
}

Future<void> sendConversionModeInfoToServer(
  BuildContext context, {
  String? playlistId,
}) async {
  final fcmToken = Provider.of<FcmTokenProvider>(context, listen: false).token;
  final currentSelectedSinger =
      Provider.of<ConversionModeProvider>(
        context,
        listen: false,
      ).currentSelectedSinger;
  final accessToken = await secureStorage.read(key: 'accessToken');
  print(
    'fcmToken: $fcmToken, singerName: $currentSelectedSinger, accessToken: $accessToken',
  );
  if (currentSelectedSinger == null || accessToken == null) {
    throw Exception('필수 정보 누락');
  }
  final backendIp = dotenv.env['BACKEND_IP'] ?? '127.0.0.1';
  final backendPort = dotenv.env['BACKEND_PORT'] ?? '5000';
  final response = await ApiClient().post(
    Uri.parse('http://$backendIp:$backendPort/conversion_mode_info'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'fcm_token': fcmToken,
      'singer_name': currentSelectedSinger,
      'spotify_access_token': accessToken,
      if (playlistId != null) 'playlist_id': playlistId,
    }),
  );
  if (response.statusCode != 200) {
    throw Exception('서버 전송 실패: \\${response.body}');
  }
}
