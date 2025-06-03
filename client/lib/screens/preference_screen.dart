import 'package:flutter/material.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/song.dart';
import 'package:provider/provider.dart';
import '../providers/playlist_provider.dart';
import 'package:uuid/uuid.dart';
import '../services/get_backend_ip_service.dart';
import 'dart:async';
import 'package:spotify_sdk/spotify_sdk.dart';
import '../services/spotify_auth_service.dart';

/// ConversionModeButton 위젯
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

/// Preference 화면
/// - ConversionModeButton 클릭 시 Conversion Mode ON -> 스트리밍 앱의 현재 곡 정보 표시
class PreferenceScreen extends StatefulWidget {
  const PreferenceScreen({Key? key}) : super(key: key);

  @override
  State<PreferenceScreen> createState() => _PreferenceScreenState();
}

class _PreferenceScreenState extends State<PreferenceScreen> {
  bool _conversionModeOn = false;
  Timer? _playerCheckTimer;
  String? selectedSinger = 'rose'; // 임시로 '로제'로 지정

  // 예시: Conversion Mode가 ON일 때 표시할 곡 정보
  // 실제로는 스트리밍 앱 연동 필요
  final Map<String, String> currentSong = {
    'title': 'Ditto',
    'artist': 'NewJeans',
    'album': 'OMG',
  };

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
              ConversionModeButton(
                initialModeOn: _conversionModeOn,
                onChanged: _onConversionModeChanged,
                enabled: selectedSinger != null,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () async {
                  // song: antifreez, singer: rose로 고정
                  final fixedSinger = 'rose';
                  final fixedSong = 'antifreez';
                  final resultFile = await requestVoiceConversion(
                    fixedSinger,
                    fixedSong,
                  );
                  debugPrint('변환 완료: \\${resultFile.path}');
                  _onVoiceConversionComplete(
                    context,
                    resultFile,
                    fixedSong,
                    fixedSinger,
                  );
                },
                child: Text('테스트'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onVoiceConversionComplete(
    BuildContext context,
    File resultFile,
    String title,
    String artist,
  ) {
    // Provider를 통해 곡 추가
    Provider.of<PlaylistProvider>(context, listen: false).addSong(
      Song(
        title: title,
        artist: artist,
        audioUrl: resultFile.path, // Song 모델에 맞게 경로 전달
      ),
    );
  }

  void _onConversionModeChanged(bool isOn) async {
    setState(() {
      _conversionModeOn = isOn;
    });
    await setConversionMode(isOn);

    if (isOn) {
      _startPlayerCheck();
    } else {
      _stopPlayerCheck();
    }
  }

  void _startPlayerCheck() {
    _playerCheckTimer?.cancel();
    _playerCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final playerState = await SpotifySdk.getPlayerState();
        final track = playerState?.track;
        if (track != null) {
          debugPrint('현재 곡: ${track.name} / ${track.artist.name}');
          // Spotify Web API로 context 정보까지 가져와 kirby로 전달
          try {
            final accessToken = await SpotifySdk.getAccessToken(
              clientId: clientId,
              redirectUrl: redirectUri,
              scope: scope,
            );
            final dio = Dio();
            final webApiResponse = await dio.get(
              'https://api.spotify.com/v1/me/player',
              options: Options(
                headers: {'Authorization': 'Bearer $accessToken'},
              ),
            );
            final data = webApiResponse.data;
            final contextUri = data['context']?['uri'];
            final backendIp = await getBackendIp();
            await dio.post(
              'http://$backendIp:5000/your_endpoint', // TODO: 실제 엔드포인트로 변경 필요
              data: {
                'track_name': track.name,
                'artist': track.artist.name,
                'context_uri': contextUri,
              },
              options: Options(headers: {'Content-Type': 'application/json'}),
            );
          } catch (e) {
            debugPrint('곡 정보 전달 실패: $e');
          }
        }
      } catch (e) {
        debugPrint('Spotify 상태 확인 실패: $e');
      }
    });
  }

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

Future<File> requestVoiceConversion(String singer, String song) async {
  final dio = Dio();
  final backendIp = await getBackendIp();
  final response = await dio.post(
    'http://$backendIp:5000/convert',
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

Future<void> setConversionMode(bool on) async {
  final dio = Dio();
  final backendIp = await getBackendIp();
  final response = await dio.post(
    'http://$backendIp:5000/conversion_mode',
    data: {'on': on},
    options: Options(contentType: Headers.jsonContentType),
  );
  debugPrint(response.data); // {"on": true} 또는 {"on": false}
}
