import 'package:dio/dio.dart';
import 'dart:developer' as logging;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';

/// 오디오 파일을 서버로 업로드하는 함수
Future<void> uploadAudioFile(String filePath) async {
  Dio dio = Dio();
  dio.options.contentType = 'multipart/form-data';
  final backendIp = dotenv.env['BACKEND_IP'] ?? '127.0.0.1';
  final backendPort = dotenv.env['BACKEND_PORT'] ?? '5000';
  try {
    final url = 'http://$backendIp:$backendPort/convert';
    FormData formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: 'audio.wav'),
    });

    Response response = await dio.post(url, data: formData);
    if (response.statusCode == 401) {
      throw Exception('401: 인증이 필요합니다.');
    }
    if (response.statusCode != 200) {
      throw Exception('파일 업로드 실패: \\${response.statusCode}');
    }
    // 성공 시 필요한 처리 수행 (파일 저장 또는 재생 등)
  } catch (e) {
    logging.log("파일 업로드 실패: $e");
    rethrow;
  }
}

/// 서버에 변환 모드 상태를 동기화하는 함수
Future<void> setConversionMode(bool isOn) async {
  Dio dio = Dio();
  final backendIp = dotenv.env['BACKEND_IP'] ?? '127.0.0.1';
  final backendPort = dotenv.env['BACKEND_PORT'] ?? '5000';
  try {
    final conversionModeUrl = 'http://$backendIp:$backendPort/conversion_mode';
    final response = await dio.post(conversionModeUrl, data: {'on': isOn});
    if (response.statusCode == 401) {
      throw Exception('401: 인증이 필요합니다.');
    }
    if (response.statusCode != 200) {
      throw Exception('변환 모드 동기화 실패: \\${response.statusCode}');
    }
  } catch (e) {
    logging.log("Conversion Mode 동기화 실패: $e");
    rethrow;
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
  final file = File('${dir.path}/$singer $song ${uuid.v4()}.wav');
  await file.writeAsBytes(response.data);
  return file;
}
