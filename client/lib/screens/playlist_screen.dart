import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/song.dart'; // Song 모델 import
import 'package:provider/provider.dart';
import '../providers/playlist_provider.dart';

/// Playlist 화면
/// - 음성 변환으로 생성된 곡 리스트
/// - 곡별 Player 기능(재생/일시정지)
class PlaylistScreen extends StatefulWidget {
  final Song? initialSong;
  const PlaylistScreen({Key? key, this.initialSong}) : super(key: key);

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  int? _playingIndex;

  void _onPlayPause(int index) async {
    final playlistProvider = Provider.of<PlaylistProvider>(
      context,
      listen: false,
    );
    final songs = playlistProvider.songs;
    final song = songs[index];
    debugPrint('재생 시도: \\${song.audioUrl}');
    if (_playingIndex == index) {
      await _audioPlayer.pause();
      setState(() {
        _playingIndex = null;
      });
    } else {
      await _audioPlayer.stop();
      await _audioPlayer.play(DeviceFileSource(song.audioUrl));
      setState(() {
        _playingIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Playlist')),
      body: Consumer<PlaylistProvider>(
        builder: (context, playlistProvider, child) {
          final songs = playlistProvider.songs;
          return ListView.separated(
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
          );
        },
      ),
    );
  }
}
