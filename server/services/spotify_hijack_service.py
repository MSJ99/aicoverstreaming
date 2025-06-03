import os
import json
import requests
import yt_dlp
import logging


CLIENT_ID = "my_client_id"
CLIENT_SECRET = "my_client_secret"


def get_access_token():
    url = "https://accounts.spotify.com/api/token"
    headers = {"Content-Type": "application/x-www-form-urlencoded"}
    data = {
        "grant_type": "client_credentials",
        "client_id": CLIENT_ID,
        "client_secret": CLIENT_SECRET,
    }

    res = requests.post(url, headers=headers, data=data)
    if res.status_code == 200:
        access_token = res.json().get("access_token")
        logging.info(f"✅ Access Token: {access_token}")
        return access_token
    else:
        logging.error(f"❌ 실패: {res.status_code} {res.text}")
        return None


class SpotifyHijackingService:
    def __init__(self, playlist_id, output_dir="songoriginal"):
        self.playlist_id = playlist_id
        self.output_dir = output_dir
        self.token = get_access_token()
        if not os.path.exists(self.output_dir):
            os.makedirs(self.output_dir)

    def get_playlist_tracks(self, raw_path="playlist_raw.json"):
        url = f"https://api.spotify.com/v1/playlists/{self.playlist_id}"
        headers = {"Authorization": f"Bearer {self.token}"}
        res = requests.get(url, headers=headers)
        if res.status_code != 200:
            logging.error(f"❌ Spotify 요청 실패: {res.text}")
            return False
        data = res.json()
        with open(raw_path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        logging.info("📁 playlist_raw.json 저장 완료")
        return True

    def get_song_queries_from_json(self, json_path="playlist_raw.json"):
        with open(json_path, "r", encoding="utf-8") as f:
            data = json.load(f)
        result = []
        for item in data["tracks"]["items"]:
            track = item.get("track")
            if not track:
                continue
            title = track.get("name", "Unknown Title")
            artists = ", ".join([artist["name"] for artist in track.get("artists", [])])
            result.append((title, artists))
        return result

    def get_youtube_url(self, title, artist):
        query = f"{title} {artist} lyrics"
        ydl_opts = {
            "quiet": True,
            "skip_download": True,
            "extract_flat": "in_playlist",
            "default_search": "ytsearch1",
        }
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            try:
                info = ydl.extract_info(query, download=False)
                if "entries" in info and len(info["entries"]) > 0:
                    video = info["entries"][0]
                    url = video.get("url")
                    logging.info(f"🔗 {query} → {url}")
                    return url
                else:
                    logging.warning(f"❌ 검색 결과 없음: {query}")
                    return None
            except Exception as e:
                logging.error(f"❌ 유튜브 검색 실패: {query}\n{e}")
                return None

    def download_audio_as_wav(self, url, title, artist):
        safe_title = f"{title} - {artist}".replace("/", "_").replace("\\", "_")
        output_path = os.path.join(self.output_dir, f"{safe_title}.wav")
        ydl_opts = {
            "format": "bestaudio/best",
            "outtmpl": output_path,
            "quiet": False,
            "postprocessors": [
                {
                    "key": "FFmpegExtractAudio",
                    "preferredcodec": "wav",
                    "preferredquality": "192",
                }
            ],
        }
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            try:
                logging.info(f"🎧 다운로드 중: {title} - {artist}")
                ydl.download([url])
                logging.info(f"✅ 저장 완료: {output_path}")
            except Exception as e:
                logging.error(f"❌ 다운로드 실패: {title} - {artist}\n{e}")

    def hijack_playlist(self):
        # 전체 프로세스 실행
        if not self.get_playlist_tracks():
            return
        song_list = self.get_song_queries_from_json()
        youtube_links = []
        for title, artist in song_list:
            url = self.get_youtube_url(title, artist)
            youtube_links.append((title, artist, url))
        # 링크 저장
        with open("youtube_links.txt", "w", encoding="utf-8") as f:
            for title, artist, url in youtube_links:
                f.write(f"{title} - {artist} ||| {url if url else ''}\n")
        # 다운로드
        for title, artist, url in youtube_links:
            if url:
                self.download_audio_as_wav(url, title, artist)


def get_playlist_tracks_with_token(playlist_id, access_token):
    url = f"https://api.spotify.com/v1/playlists/{playlist_id}/tracks"
    headers = {"Authorization": f"Bearer {access_token}"}
    tracks = []
    next_url = url
    while next_url:
        res = requests.get(next_url, headers=headers)
        if res.status_code != 200:
            logging.error(f"❌ Spotify 요청 실패: {res.text}")
            break
        data = res.json()
        for item in data["items"]:
            track = item.get("track")
            if not track:
                continue
            title = track.get("name", "Unknown Title")
            artists = ", ".join([artist["name"] for artist in track.get("artists", [])])
            tracks.append({"title": title, "artists": artists})
        next_url = data.get("next")
    return tracks


# 사용 예시
if __name__ == "__main__":
    playlist_id = "3sSHG8i68MZ3cteVQIFkzB"  # 원하는 플레이리스트 ID로 변경
    service = SpotifyHijackingService(playlist_id)
    service.hijack_playlist()
