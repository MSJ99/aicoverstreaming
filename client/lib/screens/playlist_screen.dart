import 'package:flutter/material.dart';

/// 곡 정보를 담는 데이터 클래스
class Song {
  final String title;
  final String artist;
  final String audioUrl; // 실제 프로젝트에서는 네트워크/로컬 경로

  Song({required this.title, required this.artist, required this.audioUrl});
}

/// Playlist 화면
/// - 음성 변환으로 생성된 곡 리스트
/// - 곡별 Player 기능(재생/일시정지)
class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({Key? key}) : super(key: key);

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  // 예시 데이터: 실제 데이터로 교체 필요
  final List<Song> songs = [
    Song(title: '좋은날', artist: '아이유', audioUrl: 'assets/audio/good_day.mp3'),
    Song(
      title: 'Dynamite',
      artist: 'BTS',
      audioUrl: 'assets/audio/dynamite.mp3',
    ),
    Song(
      title: 'Pink Venom',
      artist: 'BLACKPINK',
      audioUrl: 'assets/audio/pink_venom.mp3',
    ),
  ];

  int? _playingIndex;

  // 실제 오디오 플레이어 연동 시, audioplayers 패키지 등 사용 권장
  void _onPlayPause(int index) {
    setState(() {
      if (_playingIndex == index) {
        _playingIndex = null; // 일시정지
      } else {
        _playingIndex = index; // 재생
      }
    });
    // TODO: 오디오 플레이/일시정지 로직 연동
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Playlist')),
      body: ListView.separated(
        itemCount: songs.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final song = songs[index];
          final isPlaying = _playingIndex == index;
          return ListTile(
            leading: IconButton(
              icon: Icon(
                isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
                color: isPlaying ? Colors.green : Colors.blueGrey,
                size: 36,
              ),
              onPressed: () => _onPlayPause(index),
              tooltip: isPlaying ? '일시정지' : '재생',
            ),
            title: Text(
              song.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(song.artist),
            trailing: const Icon(Icons.more_vert),
            onTap: () => _onPlayPause(index),
          );
        },
      ),
    );
  }
}
