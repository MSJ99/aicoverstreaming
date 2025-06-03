import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:dio/dio.dart';
import '../services/secure_storage_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import '../services/spotify_auth_service.dart';

/// Spotify API와 연동하여 query에 맞는 가수 리스트를 검색하는 함수
Future<List<dynamic>> searchSinger(String query) async {
  final backendIp = dotenv.env['BACKEND_IP'] ?? '127.0.0.1';
  final backendPort = dotenv.env['BACKEND_PORT'] ?? '5000';
  var accessToken = await secureStorage.read(key: 'accessToken');
  if (accessToken == null || accessToken.isEmpty) {
    // accessToken이 없으면 인증 시도
    try {
      await authenticateWithSpotify();
      accessToken = await secureStorage.read(key: 'accessToken');
      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('Spotify 인증 후에도 accessToken이 없습니다.');
      }
    } catch (e) {
      throw Exception('Spotify 인증 실패: $e');
    }
  }
  Future<List<dynamic>> doSearch(String token) async {
    final response = await http.get(
      Uri.parse(
        'http://$backendIp:$backendPort/search_artist?query=$query&access_token=$token',
      ),
    );
    print('searchSinger query: $query');
    print('response.statusCode: \\${response.statusCode}');
    print('response.body: \\${response.body}');
    if (response.statusCode == 401) {
      throw Exception('토큰 만료');
    } else if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('검색 실패');
    }
  }

  try {
    return await doSearch(accessToken);
  } catch (e) {
    if (e.toString().contains('토큰 만료')) {
      try {
        await authenticateWithSpotify();
        accessToken = await secureStorage.read(key: 'accessToken');
        if (accessToken == null || accessToken.isEmpty) {
          throw Exception('Spotify 인증 후에도 accessToken이 없습니다.');
        }
        return await doSearch(accessToken);
      } catch (authError) {
        // 인증 실패 시 에러 메시지 반환
        throw Exception('Spotify 인증 실패: $authError');
      }
    } else {
      rethrow;
    }
  }
}

/// Youtube에서 대표곡 URL을 받아오는 함수 (서버 API 연동)
Future<String?> fetchYoutubeUrlForSinger(String title, String artist) async {
  final backendIp = dotenv.env['BACKEND_IP'] ?? '127.0.0.1';
  final backendPort = dotenv.env['BACKEND_PORT'] ?? '5000';
  final dio = Dio();
  final response = await dio.get(
    'http://$backendIp:$backendPort/youtube_url',
    queryParameters: {'title': title, 'artist': artist},
  );
  if (response.statusCode == 200 && response.data['url'] != null) {
    return response.data['url'];
  }
  return null;
}

/// 에셋 파일을 임시 디렉토리로 복사하는 함수
Future<File> copyAssetToTemp(String assetPath, String filename) async {
  final byteData = await rootBundle.load(assetPath);
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(byteData.buffer.asUint8List());
  return file;
}

/// SelectSingerScreen
/// - 가수 이름 검색, 선택, 삭제 및 선택된 가수 목록을 관리하는 화면
class SelectSingerScreen extends StatefulWidget {
  const SelectSingerScreen({Key? key}) : super(key: key);

  @override
  State<SelectSingerScreen> createState() => _SelectSingerScreenState();
}

/// _SelectSingerScreenState
/// - 검색 결과, 선택된 가수 목록, 로딩/에러 상태를 관리하며, 가수 검색/선택/삭제 기능을 구현
class _SelectSingerScreenState extends State<SelectSingerScreen> {
  List<dynamic> searchResults = [];
  List<dynamic> selectedSingers = [];
  String query = '';
  bool isLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    fetchSelectedSingers().then((singers) {
      if (!mounted) return;
      setState(() {
        selectedSingers = singers;
      });
    });
    // 5분마다 상태 갱신
    final backendIp = dotenv.env['BACKEND_IP'] ?? '127.0.0.1';
    final backendPort = dotenv.env['BACKEND_PORT'] ?? '5000';
    Timer.periodic(Duration(minutes: 5), (timer) async {
      await Dio().post('http://$backendIp:$backendPort/update_singer_status');
      final singers = await fetchSelectedSingers();
      if (!mounted) return;
      setState(() {
        selectedSingers = singers;
      });
    });
  }

  /// 검색창 입력 시 호출되는 함수
  /// - 서버에 검색 요청 후 결과를 searchResults에 반영
  void onSearchChanged(String value) {
    setState(() {
      query = value;
    });
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() {
        isLoading = true;
      });
      try {
        final results = await searchSinger(value);
        if (!mounted) return;
        setState(() {
          searchResults = results;
        });
      } catch (e) {
        // 에러 처리
      } finally {
        if (!mounted) return;
        setState(() {
          isLoading = false;
        });
      }
    });
  }

  /// 가수 선택 시 호출되는 함수
  /// - 서버에 선택 요청 후 선택된 가수 목록을 동기화
  void onSingerSelected(dynamic singer) async {
    try {
      // singer가 Map일 때만 id 접근
      final singerId = singer is Map ? singer['id'] : singer;
      await selectSinger(singerId);
      final singers = await fetchSelectedSingers();
      setState(() {
        selectedSingers = singers;
      });
    } catch (e) {
      // 에러 처리
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('가수 선택'),
        actions: [
          IconButton(
            icon: Icon(Icons.list),
            onPressed: () {
              showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: Text('선택된 가수 목록'),
                      content: SizedBox(
                        width: double.maxFinite,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: selectedSingers.length,
                          itemBuilder: (context, idx) {
                            final singer = selectedSingers[idx];
                            final isTraining = singer['status'] == 'training';
                            return ListTile(
                              title: Text(
                                isTraining
                                    ? '${singer['name']} (학습 중...)'
                                    : singer['name'],
                              ),
                              enabled: !isTraining,
                              trailing: IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed:
                                    isTraining
                                        ? null
                                        : () async {
                                          try {
                                            await deleteSinger(singer['id']);
                                            final singers =
                                                await fetchSelectedSingers();
                                            setState(() {
                                              selectedSingers = singers;
                                            });
                                          } catch (e) {
                                            // 에러 처리
                                          }
                                        },
                              ),
                              onTap:
                                  isTraining
                                      ? null
                                      : () => onSingerSelected(singer),
                            );
                          },
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text('닫기'),
                        ),
                      ],
                    ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 검색창
          TextField(
            onChanged: onSearchChanged,
            onSubmitted: onSearchChanged,
            decoration: InputDecoration(
              hintText: '가수 검색',
              suffixIcon: isLoading ? CircularProgressIndicator() : null,
            ),
          ),
          // 연관검색어(검색 결과) 리스트
          Expanded(
            child:
                searchResults.isEmpty && query.isNotEmpty && !isLoading
                    ? Center(child: Text('검색 결과가 없습니다'))
                    : ListView.builder(
                      itemCount: searchResults.length,
                      itemBuilder: (context, idx) {
                        final singer = searchResults[idx];
                        return ListTile(
                          title: Text(singer['name']),
                          onTap: () => onSingerSelected(singer),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

/// 서버와 선택된 가수 목록을 동기화하는 함수
Future<List<String>> syncSelectedSingerWithServer(String singer) async {
  final backendIp = dotenv.env['BACKEND_IP'] ?? '127.0.0.1';
  final backendPort = dotenv.env['BACKEND_PORT'] ?? '5000';
  final dio = Dio();
  final response = await dio.post(
    'http://$backendIp:$backendPort/selected_singers',
    data: {'singer': singer},
    options: Options(contentType: Headers.jsonContentType),
  );
  return List<String>.from(response.data);
}

/// 서버에서 등록된 가수 목록을 불러오는 함수
Future<List<String>> fetchRegisteredSingersFromServer() async {
  final backendIp = dotenv.env['BACKEND_IP'] ?? '127.0.0.1';
  final backendPort = dotenv.env['BACKEND_PORT'] ?? '5000';
  final dio = Dio();
  final response = await dio.get(
    'http://$backendIp:$backendPort/selected_singers',
  );
  return List<String>.from(response.data);
}

/// 가수 선택(등록) 요청 함수
Future<void> selectSinger(String singerId) async {
  final backendIp = dotenv.env['BACKEND_IP'] ?? '127.0.0.1';
  final backendPort = dotenv.env['BACKEND_PORT'] ?? '5000';
  final accessToken = await secureStorage.read(key: 'accessToken');
  final response = await http.post(
    Uri.parse('http://$backendIp:$backendPort/selected_singers'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    },
    body: jsonEncode({'singer_id': singerId}),
  );

  if (response.statusCode == 401) {
    throw Exception('토큰 만료');
  } else if (response.statusCode != 200) {
    throw Exception('가수 등록 실패');
  }
}

/// 서버에서 선택된 가수 목록을 불러오는 함수
Future<List<dynamic>> fetchSelectedSingers() async {
  final backendIp = dotenv.env['BACKEND_IP'] ?? '127.0.0.1';
  final backendPort = dotenv.env['BACKEND_PORT'] ?? '5000';
  final accessToken = await secureStorage.read(key: 'accessToken');
  final response = await http.get(
    Uri.parse('http://$backendIp:$backendPort/selected_singers'),
    headers: {'Authorization': 'Bearer $accessToken'},
  );

  if (response.statusCode == 401) {
    throw Exception('토큰 만료');
  } else if (response.statusCode == 200) {
    final decoded = jsonDecode(response.body);
    final singers = decoded['singers'];
    print('서버에서 받아온 singers: $singers');
    if (singers == null) {
      return [];
    } else if (singers is List) {
      return List<dynamic>.from(singers);
    } else if (singers is String) {
      // 단일 String일 때 리스트로 변환
      return [singers];
    } else {
      throw Exception('알 수 없는 singers 타입: ${singers.runtimeType}');
    }
  } else {
    throw Exception('가수 목록 불러오기 실패');
  }
}

/// 선택된 가수 삭제 요청 함수
Future<void> deleteSinger(String singerId) async {
  final backendIp = dotenv.env['BACKEND_IP'] ?? '127.0.0.1';
  final backendPort = dotenv.env['BACKEND_PORT'] ?? '5000';
  final accessToken = await secureStorage.read(key: 'accessToken');
  final response = await http.delete(
    Uri.parse('http://$backendIp:$backendPort/selected_singers'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    },
    body: jsonEncode({'singer': singerId}),
  );
  if (response.statusCode == 401) {
    throw Exception('토큰 만료');
  } else if (response.statusCode != 200) {
    throw Exception('가수 삭제 실패');
  }
}
