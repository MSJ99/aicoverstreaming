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
  Timer? _playerCheckTimer;
  String? selectedSinger = 'rose'; // 임시로 '로제'로 지정
  String? _errorMessage;
  bool _isLoading = false;

  // 실제 Spotify에서 받아온 현재 곡 정보
  String? _currentTrackTitle;
  String? _currentTrackArtist;
  String? _currentTrackAlbum;

  @override
  Widget build(BuildContext context) {
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
                enabled: selectedSinger != null && !_isLoading,
              ),
              const SizedBox(height: 32),
              // 현재 Spotify 곡 정보 표시
              if (_conversionModeOn && _currentTrackTitle != null) ...[
                Text(
                  '현재 곡: $_currentTrackTitle',
                  style: const TextStyle(fontSize: 16),
                ),
                Text(
                  '아티스트: $_currentTrackArtist',
                  style: const TextStyle(fontSize: 14),
                ),
                if (_currentTrackAlbum != null)
                  Text(
                    '앨범: $_currentTrackAlbum',
                    style: const TextStyle(fontSize: 14),
                  ),
                const SizedBox(height: 24),
              ],
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
      await setConversionMode(isOn);
      if (isOn) {
        _startPlayerCheck();
      } else {
        _stopPlayerCheck();
        setState(() {
          _currentTrackTitle = null;
          _currentTrackArtist = null;
          _currentTrackAlbum = null;
        });
      }
    } catch (e) {
      if (e.toString().contains('401')) {
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        setState(() {
          _errorMessage = '변환 모드 변경 실패: $e';
        });
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Spotify 상태를 주기적으로 체크하여 현재 곡 정보를 받아와 화면에 표시
  void _startPlayerCheck() {
    _playerCheckTimer?.cancel();
    _playerCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final playerState = await SpotifySdk.getPlayerState();
        final track = playerState?.track;
        if (track != null) {
          setState(() {
            _currentTrackTitle = track.name;
            _currentTrackArtist = track.artist.name;
            _currentTrackAlbum = track.album.name;
          });
        } else {
          setState(() {
            _currentTrackTitle = null;
            _currentTrackArtist = null;
            _currentTrackAlbum = null;
          });
        }
      } catch (e) {
        setState(() {
          _currentTrackTitle = null;
          _currentTrackArtist = null;
          _currentTrackAlbum = null;
        });
        debugPrint('Spotify 상태 확인 실패: $e');
      }
    });
  }

  /// Spotify 상태 체크 타이머 중지
  void _stopPlayerCheck() {
    _playerCheckTimer?.cancel();
    _playerCheckTimer = null;
  }

  @override
  void dispose() {
    _playerCheckTimer?.cancel();
    super.dispose();
  }
}

/// 서버에 음성 변환 요청을 보내고 결과 파일을 반환하는 함수
Future<File> requestVoiceConversion(String singer, String song) async {
  final dio = Dio();
  final backendIp = dotenv.env['BACKEND_IP'] ?? '127.0.0.1';
  final backendPort = dotenv.env['BACKEND_PORT'] ?? '5000';
  final response = await dio.post(
    'http://$backendIp:$backendPort/convert',
    data: {'singer': singer, 'song': song},
    options: Options(
      responseType: ResponseType.bytes,
      headers: {'Content-Type': 'application/json'},
    ),
  );
  final dir = await getTemporaryDirectory();
  final uuid = Uuid();
  final file = File('${dir.path}/$singer\_$song\_${uuid.v4()}.wav');
  await file.writeAsBytes(response.data);
  return file;
}

/// 서버에 변환 모드 상태를 동기화하는 함수
Future<void> setConversionMode(bool on) async {
  final dio = Dio();
  final backendIp = dotenv.env['BACKEND_IP'] ?? '127.0.0.1';
  final backendPort = dotenv.env['BACKEND_PORT'] ?? '5000';
  final response = await dio.post(
    'http://$backendIp:$backendPort/conversion_mode',
    data: {'on': on},
    options: Options(contentType: Headers.jsonContentType),
  );
  debugPrint(response.data.toString());
}
