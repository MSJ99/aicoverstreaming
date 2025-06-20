import os
import yt_dlp
import logging

SONGS_DIR = os.path.join("input", "songs")
os.makedirs(SONGS_DIR, exist_ok=True)


def get_youtube_url(artist):
    """
    아티스트로 유튜브에서 검색해 첫 번째 영상의 URL을 반환
    :param title: 곡 제목
    :param artist: 아티스트명
    :return: 유튜브 영상 URL 또는 None
    """
    query = f"{artist} lyrics"
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


def download_audio_as_wav(url, title, artist, output_dir=SONGS_DIR):
    """
    주어진 유튜브 URL에서 오디오를 WAV 파일로 다운로드
    :param url: 유튜브 동영상 URL
    :param title: 곡 제목
    :param artist: 아티스트명
    :param output_dir: 저장할 디렉토리 (기본값: input/songs)
    :return: 저장된 파일 경로
    """
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
    safe_title = f"{title} - {artist}".replace("/", "_").replace("\\", "_")
    output_path = os.path.join(output_dir, f"{safe_title}.wav")
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
            return output_path
        except Exception as e:
            logging.error(f"❌ 다운로드 실패: {title} - {artist}\n{e}")
            return None
