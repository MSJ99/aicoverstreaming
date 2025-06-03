import 'package:spotify_sdk/spotify_sdk.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final FlutterSecureStorage secureStorage = FlutterSecureStorage();

const String clientId = '1a2bb437d6c041ed8f4f860189c45a7a';
const String redirectUri = 'com.kirby.client://callback';
const String scope =
    'user-read-private,playlist-read-private,playlist-read-collaborative,user-read-playback-state,user-read-currently-playing';

Future<void> authenticateWithSpotify() async {
  final result = await SpotifySdk.connectToSpotifyRemote(
    clientId: clientId,
    redirectUrl: redirectUri,
  );
  if (!result) {
    throw Exception('Spotify 앱 연결 실패');
  }
  // 토큰이 필요하다면 아래처럼 사용
  final accessToken = await SpotifySdk.getAccessToken(
    clientId: clientId,
    redirectUrl: redirectUri,
    scope: scope,
  );
  // 필요하다면 accessToken을 저장
  // 예: await secureStorage.write(key: 'access_token', value: accessToken);
}
