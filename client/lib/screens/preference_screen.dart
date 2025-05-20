import 'package:flutter/material.dart';
import '../services/conversion_service.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/song.dart';
import '../screens/playlist_screen.dart';
import 'package:provider/provider.dart';
import '../providers/playlist_provider.dart';

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
  String? selectedSinger;

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ConversionModeButton(
              initialModeOn: _conversionModeOn,
              onChanged: (isOn) async {
                setState(() {
                  _conversionModeOn = isOn;
                });
                await setConversionMode(isOn);
              },
              enabled: selectedSinger != null,
            ),
            const SizedBox(height: 32),
            if (_conversionModeOn)
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '현재 재생 중인 곡 정보',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(
                            Icons.music_note,
                            size: 32,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '제목:  ${currentSong['title']}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                Text(
                                  '아티스트: ${currentSong['artist']}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                Text(
                                  '앨범: ${currentSong['album']}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            else
              const Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    'Conversion Mode를 켜면\n스트리밍 앱의 현재 곡 정보를 받아옵니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
              ),
            ElevatedButton(
              onPressed: () async {
                if (selectedSinger == null) return;
                final resultFile = await requestVoiceConversion(
                  selectedSinger!,
                  currentSong['title']!,
                );
                // 여기서 곡을 추가하지 않고, 단순히 파일이 잘 받아졌는지만 확인
                print('변환 완료: ${resultFile.path}');
                // 필요하다면 안내 메시지, 파일 경로 확인 등만 수행
                _onVoiceConversionComplete(
                  context,
                  resultFile,
                  currentSong['title']!,
                  selectedSinger!,
                );
              },
              child: Text('Voice Conversion 테스트'),
            ),
          ],
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
}

Future<File> requestVoiceConversion(String singer, String song) async {
  final dio = Dio();
  final response = await dio.post(
    'http://<SERVER_IP>:5000/convert',
    data: {'singer': singer, 'song': song},
    options: Options(responseType: ResponseType.bytes),
  );
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$singer\_$song.wav');
  await file.writeAsBytes(response.data);
  return file;
}
