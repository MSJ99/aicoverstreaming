import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
// TODO: 실제 API 연동 시 아래 패키지 사용
// import 'package:http/http.dart' as http;
// import 'dart:convert';

/// 곡/가수 검색을 위한 더미 함수 (실제 구현 시 API 연동 필요)
Future<List<String>> fetchSingerSuggestions(String query) async {
  // TODO: Spotify API 등과 연동하여 query에 맞는 가수 리스트 반환
  // 예시: return await spotifyApi.searchArtists(query);
  // 임시 더미 데이터
  await Future.delayed(Duration(milliseconds: 300));
  return [
    '아이유',
    '방탄소년단',
    '블랙핑크',
    '임영웅',
    '뉴진스',
    '세븐틴',
    '르세라핌',
  ].where((s) => s.contains(query)).toList();
}

/// Youtube에서 대표곡 URL을 받아오는 더미 함수 (실제 구현 시 API 연동 필요)
Future<String> fetchYoutubeUrlForSinger(String singer) async {
  // TODO: Youtube API 등과 연동하여 singer의 대표곡 URL 반환
  // 예시: return await youtubeApi.getTopSongUrl(singer);
  // 임시 더미 URL
  await Future.delayed(Duration(milliseconds: 300));
  return 'https://www.youtube.com/watch?v=dummy';
}

Future<List<String>> getTargetSingerNames() async {
  final dir = await getApplicationDocumentsDirectory();
  final files = dir.listSync();
  return files
      .where((f) => f is File && f.path.endsWith('.wav'))
      .map((f) => f.uri.pathSegments.last.replaceAll('.wav', ''))
      .toList();
}

Future<File> copyAssetToTemp(String assetPath, String filename) async {
  final byteData = await rootBundle.load(assetPath);
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(byteData.buffer.asUint8List());
  return file;
}

/// SelectSinger 화면
/// - 가수 이름 검색
/// - 기존에 선택한 가수 리스트 다이얼로그
class SelectSingerScreen extends StatefulWidget {
  const SelectSingerScreen({Key? key}) : super(key: key);

  @override
  State<SelectSingerScreen> createState() => _SelectSingerScreenState();
}

class _SelectSingerScreenState extends State<SelectSingerScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showSingerList = false;

  // 예시 데이터 (TODO: 반응형으로)
  final List<String> allSingers = [
    '아이유',
    '방탄소년단',
    '블랙핑크',
    '임영웅',
    '뉴진스',
    '세븐틴',
    '르세라핌',
  ];
  List<String> filteredSingers = [];
  List<String> selectedSingers = [];

  @override
  void initState() {
    super.initState();
    filteredSingers = List.from(allSingers);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() async {
    final query = _searchController.text;
    if (query.isEmpty) {
      setState(() {
        filteredSingers = List.from(allSingers);
      });
    } else {
      // 실제 구현 시 fetchSingerSuggestions(query)로 대체
      final suggestions = await fetchSingerSuggestions(query);
      setState(() {
        filteredSingers = suggestions;
      });
    }
  }

  void _onSingerTap(String singer) async {
    // assets에서 임시폴더로 복사
    final file = await copyAssetToTemp(
      'assets/audio/$singer.wav',
      '$singer.wav',
    );
    print('${file.path}로 복사 완료');
    // 이후 로직(예: selectedSinger 지정 등)
    setState(() {
      if (!selectedSingers.contains(singer)) {
        selectedSingers.add(singer);
      }
    });
  }

  void _showSelectedSingersDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('선택 기록'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children:
                    selectedSingers
                        .map(
                          (singer) => ListTile(
                            title: Text(singer),
                            onTap: () {
                              Navigator.pop(context);
                              _onSingerTap(singer);
                            },
                          ),
                        )
                        .toList(),
              ),
            ),
            actions: [
              TextButton(
                child: const Text('닫기'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
    );
  }

  void _showTargetSingerListDialog() async {
    final singerNames = await getTargetSingerNames();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('보유한 Target Voice(가수) 목록'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children:
                    singerNames
                        .map(
                          (name) => ListTile(
                            title: Text(name),
                            onTap: () {
                              setState(() {
                                selectedSingers.add(name);
                              });
                              Navigator.pop(context);
                            },
                          ),
                        )
                        .toList(),
              ),
            ),
            actions: [
              TextButton(
                child: Text('닫기'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('가수 선택'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            tooltip: '기존에 선택한 가수 보기',
            onPressed: _showSelectedSingersDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: '가수 이름 검색',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
