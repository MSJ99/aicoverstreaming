import 'package:dio/dio.dart';

Future<void> uploadAudioFile(String filePath) async {
  Dio dio = Dio();
  dio.options.contentType = 'multipart/form-data';
  try {
    FormData formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: 'audio.wav'),
    });

    Response response = await dio.post(
      'http://<BACKEND_IP>:5000/convert',
      data: formData,
    );
    if (response.statusCode == 200) {
      // 필요한 처리 수행 (파일 저장 또는 재생 등))
    }
  } catch (e) {
    print("파일 업로드 실패: $e");
  }
}

// Conversion Mode 상태를 서버와 동기화하는 함수
Future<void> setConversionMode(bool isOn) async {
  Dio dio = Dio();
  try {
    await dio.post(
      'http://<BACKEND_IP>:5000/conversion_mode',
      data: {'on': isOn},
    );
  } catch (e) {
    print("Conversion Mode 동기화 실패: $e");
  }
}
