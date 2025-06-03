import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/song.dart';
import 'package:provider/provider.dart';
import '../providers/playlist_provider.dart';

/// PlaylistScreen
/// - 음성 변환으로 생성된 곡 리스트를 보여주고, 곡별로 재생/일시정지/삭제 기능을 제공하는 화면
class PlaylistScreen extends StatefulWidget {
  final Song? initialSong;
  const PlaylistScreen({Key? key, this.initialSong}) : super(key: key);

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

/// _PlaylistScreenState
/// - 곡 재생 상태, 에러/로딩 상태를 관리하며, 곡별 재생/일시정지/삭제 기능을 구현
class _PlaylistScreenState extends State<PlaylistScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  int? _playingIndex;
  String? _errorMessage;
  bool _isLoading = false;

  /// 곡 재생/일시정지 핸들러
  /// - 이미 재생 중인 곡을 누르면 일시정지, 다른 곡을 누르면 해당 곡 재생
  /// - 재생 중 에러 발생 시 에러 메시지 표시
  void _onPlayPause(int index) async {
    final playlistProvider = Provider.of<PlaylistProvider>(
      context,
      listen: false,
    );
    final songs = playlistProvider.songs;
    final song = songs[index];
    debugPrint('재생 시도: \\${song.audioUrl}');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
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
    } catch (e) {
      setState(() {
        _errorMessage = '재생 실패: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
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
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_errorMessage != null) {
            return Center(
              child: Text(_errorMessage!, style: TextStyle(color: Colors.red)),
            );
          }
          if (songs.isEmpty) {
            return const Center(child: Text('플레이리스트가 비어 있습니다.'));
          }
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
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        Provider.of<PlaylistProvider>(
                          context,
                          listen: false,
                        ).removeSong(song);
                      },
                    ),
                    const Icon(Icons.more_vert),
                  ],
                ),
                onTap: () => _onPlayPause(index),
              );
            },
          );
        },
      ),
    );
  }
}
