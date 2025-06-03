import 'package:dio/dio.dart';
import 'dart:developer' as logging;
import 'get_backend_ip_service.dart';

Future<void> uploadAudioFile(String filePath) async {
  Dio dio = Dio();
  dio.options.contentType = 'multipart/form-data';
  try {
    final backendIp = await getBackendIp();
    final url = 'http://$backendIp:5000/convert';
    FormData formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: 'audio.wav'),
    });

    Response response = await dio.post(url, data: formData);
    if (response.statusCode == 200) {
      // 필요한 처리 수행 (파일 저장 또는 재생 등)
    }
  } catch (e) {
    logging.log("파일 업로드 실패: $e");
  }
}

// Conversion Mode 상태를 서버와 동기화하는 함수
Future<void> setConversionMode(bool isOn) async {
  Dio dio = Dio();
  try {
    final backendIp = await getBackendIp();
    final conversionModeUrl = 'http://$backendIp:5000/conversion_mode';
    await dio.post(conversionModeUrl, data: {'on': isOn});
  } catch (e) {
    logging.log("Conversion Mode 동기화 실패: $e");
  }
}
