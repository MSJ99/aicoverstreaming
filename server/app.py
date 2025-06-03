from flask import Flask, request, send_file, jsonify
from werkzeug.utils import secure_filename
import os
from services.ssh_service import (
    connect_ssh,
    upload_file,
    submit_job,
    wait_for_job_done,
    download_file,
    close_ssh,
)
import uuid
from dotenv import load_dotenv
import logging
import socket
import sys
from services.convert_service import convert_song
from services.download_song_service import get_youtube_url
import requests
import json

load_dotenv()  # .env 파일 자동 로드
logging.basicConfig(level=logging.INFO, stream=sys.stdout, force=True)

app = Flask(__name__)
UPLOAD_SOURCE_FOLDER = "uploads/source"
UPLOAD_TARGET_FOLDER = "uploads/target"
os.makedirs(UPLOAD_SOURCE_FOLDER, exist_ok=True)
os.makedirs(UPLOAD_TARGET_FOLDER, exist_ok=True)
DOWNLOAD_FOLDER = "downloads"
os.makedirs(DOWNLOAD_FOLDER, exist_ok=True)

ssh_connection = None
conversion_mode = False
selected_singers = []

SINGERS_FILE = os.path.join("services", "selected_singer.json")


def load_selected_singers():
    if os.path.exists(SINGERS_FILE):
        with open(SINGERS_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    return []


def save_selected_singers(singers):
    with open(SINGERS_FILE, "w", encoding="utf-8") as f:
        json.dump(singers, f, ensure_ascii=False)


def add_singer(singer_name):
    singers = load_selected_singers()
    if not any(s["name"] == singer_name for s in singers):
        singers.append({"name": singer_name, "status": "training"})
        save_selected_singers(singers)


def update_singer_status_if_trained(singer_name):
    model_dir = f"/data/msj9518/repos/vcstream/rvc/models/{singer_name}"
    pth_path = os.path.join(model_dir, f"{singer_name}_best.pth")
    index_path = os.path.join(model_dir, f"{singer_name}.index")
    if os.path.exists(pth_path) and os.path.exists(index_path):
        singers = load_selected_singers()
        for s in singers:
            if s["name"] == singer_name and s["status"] != "done":
                s["status"] = "done"
        save_selected_singers(singers)


# ========================
# 음성 변환 요청 처리 엔드포인트
# ========================
@app.route("/convert", methods=["POST"])
def convert_voice():
    """
    클라이언트로부터 가수/곡 정보를 받아 전체 음성 변환 파이프라인을 실행하고 결과 파일을 반환
    1. 입력 음원 존재 확인
    2. 변환 파이프라인 실행 (convert_song)
    3. 결과 파일 반환
    """
    data = request.json
    singer = data.get("singer")
    song = data.get("song")
    if not singer or not song:
        return "가수와 곡 정보를 모두 입력해야 합니다.", 400

    # 1. (이미 구현됨) yt-dlp로 음원 다운로드 → local_song_path
    local_song_path = os.path.join("server", "input", "songs", f"{song}.wav")
    if not os.path.exists(local_song_path):
        return "음원이 존재하지 않습니다.", 404

    # 2. 전체 파이프라인 실행
    try:
        result_path = convert_song(local_song_path, singer)
    except Exception as e:
        return f"처리 중 오류 발생: {e}", 500

    # 3. 결과 파일 반환
    return send_file(result_path, as_attachment=True)


# ========================
# 선택된 가수 관리 엔드포인트 (조회/등록/삭제)
# ========================
@app.route("/selected_singers", methods=["GET", "POST", "DELETE"])
def handle_selected_singers():
    """
    선택된 가수 목록을 조회/등록/삭제하는 엔드포인트
    - GET: 전체 목록 반환
    - POST: 가수 추가 (학습 시작 시)
    - DELETE: 가수 삭제
    """
    if request.method == "POST":
        data = request.json
        singer = data.get("singer")
        if singer:
            add_singer(singer)
        return jsonify({"singers": load_selected_singers()})
    elif request.method == "DELETE":
        data = request.json
        singer = data.get("singer")
        singers = load_selected_singers()
        singers = [s for s in singers if s["name"] != singer]
        save_selected_singers(singers)
        return jsonify({"singers": singers})
    # GET
    return jsonify({"singers": load_selected_singers()})


# ========================
# 변환 모드 관리 엔드포인트
# ========================
@app.route("/conversion_mode", methods=["GET", "POST"])
def handle_conversion_mode():
    """
    변환 모드(ON/OFF) 상태를 관리하는 엔드포인트
    - POST: 상태 변경 및 SSH 연결 관리
    - GET: 현재 상태 반환
    """
    logging.info("[LOG] /conversion_mode endpoint called")
    global conversion_mode, ssh_connection
    data = request.json
    conversion_mode = data.get("on", False)
    if conversion_mode and ssh_connection is None:
        ssh_connection = connect_ssh()
        logging.info("[LOG] Conversion mode ON: SSH 연결 생성")
    elif not conversion_mode and ssh_connection is not None:
        close_ssh(ssh_connection)
        ssh_connection = None
        logging.info("[LOG] Conversion mode OFF: SSH 연결 해제")
    else:
        logging.info(
            f"[LOG] Conversion mode 상태 변경: on={conversion_mode}, ssh_connection={'있음' if ssh_connection else '없음'}"
        )
    return jsonify({"on": conversion_mode})


# ========================
# 오디오 파일 업로드 엔드포인트
# ========================
@app.route("/upload_audio", methods=["POST"])
def upload_audio():
    """
    오디오 파일을 업로드하고 GPU 서버 input 폴더에 업로드
    """
    logging.info("[LOG] /upload_audio endpoint called")
    file = request.files["file"]
    file_type = request.form["type"]  # "target" 또는 "source"
    name = request.form["name"]  # 가수이름 또는 곡이름
    filename = secure_filename(f"{name}.wav")
    if file_type == "target":
        local_input_path = os.path.join(UPLOAD_TARGET_FOLDER, filename)
    elif file_type == "source":
        local_input_path = os.path.join(UPLOAD_SOURCE_FOLDER, filename)
    else:
        return "type은 'target' 또는 'source'만 가능합니다.", 400
    file.save(local_input_path)

    # GPU 서버 input 폴더에 업로드
    remote_input_path = f"/data/msj9518/repos/seed-vc/input/{filename}"
    ssh = connect_ssh()
    upload_file(ssh, local_input_path, remote_input_path)
    close_ssh(ssh)
    logging.info("[LOG] 업로드 완료")
    return "업로드 완료"


# ========================
# 백엔드 IP 조회 엔드포인트
# ========================
@app.route("/get_backend_ip", methods=["GET"])
def get_backend_ip():
    """
    서버의 IP 주소를 반환 (클라이언트에서 서버 주소 자동 인식용)
    """
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("10.255.255.255", 1))
        ip = s.getsockname()[0]
    except Exception:
        ip = "127.0.0.1"
    finally:
        s.close()
    return jsonify({"ip": ip})


@app.route("/current_track_info", methods=["POST"])
def receive_current_track_info():
    data = request.json
    access_token = data.get("access_token")
    context_uri = data.get("context_uri")
    # ... (기존 track_name, artist 등 필요시 추가)
    # context_uri에서 playlist_id 추출
    if context_uri and context_uri.startswith("spotify:playlist:"):
        playlist_id = context_uri.split(":")[-1]
        from services.spotify_hijack_service import get_playlist_tracks_with_token

        # Spotify API 호출 시 401 처리
        try:
            tracks = get_playlist_tracks_with_token(playlist_id, access_token)
        except Exception as e:
            if (
                hasattr(e, "response")
                and getattr(e.response, "status_code", None) == 401
            ):
                return jsonify({"error": "access_token expired"}), 401
            return jsonify({"error": str(e)}), 500
        return jsonify({"tracks": tracks})
    return jsonify({"error": "invalid context_uri"}), 400


@app.route("/youtube_url", methods=["GET"])
def youtube_url():
    title = request.args.get("title")
    artist = request.args.get("artist")
    if not title or not artist:
        return jsonify({"error": "title and artist required"}), 400
    try:
        url = get_youtube_url(title, artist)
    except Exception as e:
        # yt-dlp 등에서 401이 발생할 경우 처리 (실제 구현에 맞게 수정)
        if hasattr(e, "response") and getattr(e.response, "status_code", None) == 401:
            return jsonify({"error": "access_token expired"}), 401
        return jsonify({"error": str(e)}), 500
    if not url:
        return jsonify({"error": "not found"}), 404
    return jsonify({"url": url})


@app.route("/search_artist", methods=["GET"])
def search_artist():
    query = request.args.get("query")
    access_token = request.args.get("access_token")
    if not query or not access_token:
        return jsonify({"error": "query and access_token required"}), 400

    url = "https://api.spotify.com/v1/search"
    headers = {"Authorization": f"Bearer {access_token}"}
    params = {"q": query, "type": "artist", "limit": 10}
    res = requests.get(url, headers=headers, params=params)
    if res.status_code == 401:
        return jsonify({"error": "access_token expired"}), 401
    if res.status_code != 200:
        return jsonify({"error": "Spotify API error"}), 500

    artists = [
        {
            "id": item["id"],
            "name": item["name"],
            "image": item["images"][0]["url"] if item["images"] else None,
            "genres": item.get("genres", []),
        }
        for item in res.json()["artists"]["items"]
    ]
    return jsonify(artists)


@app.route("/update_singer_status", methods=["POST"])
def update_all_singer_status():
    """
    모든 가수의 학습 상태를 확인하고, 학습이 끝난 가수의 status를 'done'으로 변경
    """
    singers = load_selected_singers()
    changed = False
    for s in singers:
        if s["status"] != "done":
            model_dir = f"/data/msj9518/repos/vcstream/rvc/models/{s['name']}"
            pth_path = os.path.join(model_dir, f"{s['name']}_best.pth")
            index_path = os.path.join(model_dir, f"{s['name']}.index")
            if os.path.exists(pth_path) and os.path.exists(index_path):
                s["status"] = "done"
                changed = True
    if changed:
        save_selected_singers(singers)
    return jsonify({"singers": singers})


if __name__ == "__main__":
    logging.info("[LOG] Server started")
    app.run(host="0.0.0.0", port=5000, debug=True)
