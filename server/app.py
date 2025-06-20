from flask import Flask, request, send_file, jsonify, current_app
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
from services.download_song_service import get_youtube_url, download_audio_as_wav
import requests
import json
from services.spotify_hijack_service import (
    get_playlist_tracks_with_token,
    SpotifyHijackingService,
    download_playlist_to_gpu_via_ssh,
)
import paramiko
from datetime import datetime
import threading
import time

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

# Conversion Mode 상태 및 polling 관리용 전역 변수
conversion_mode_state = {
    "active": False,
    "access_token": None,
    "singer_name": None,
    "polling_thread": None,
}


@app.route("/conversion_mode_info", methods=["POST"])
def conversion_mode_info():
    data = request.json
    access_token = data.get("access_token")
    singer_name = data.get("singer_name")
    mode = data.get("conversion_mode")
    if mode == "on":
        conversion_mode_state["active"] = True
        conversion_mode_state["access_token"] = access_token
        conversion_mode_state["singer_name"] = singer_name
        # polling thread 시작
        if (
            not conversion_mode_state["polling_thread"]
            or not conversion_mode_state["polling_thread"].is_alive()
        ):
            t = threading.Thread(target=playlist_polling_worker, daemon=True)
            conversion_mode_state["polling_thread"] = t
            t.start()
        return jsonify({"status": "conversion mode on, polling started"})
    else:
        conversion_mode_state["active"] = False
        return jsonify({"status": "conversion mode off"})


@app.route("/conversion_mode_off", methods=["POST"])
def conversion_mode_off():
    user_id = "user1"
    return jsonify({"status": "off"})


def load_selected_singers():
    if os.path.exists(SINGERS_FILE):
        try:
            with open(SINGERS_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except FileNotFoundError:
            logging.error(f"{SINGERS_FILE} 파일이 없습니다.")
            return "파일 없음", 404
        except Exception as e:
            logging.error(f"파일 처리 중 오류: {e}")
            return "서버 오류", 500
    return []


def save_selected_singers(singers):
    with open(SINGERS_FILE, "w", encoding="utf-8") as f:
        json.dump(singers, f, ensure_ascii=False)


def add_singer(singer_name):
    singers = load_selected_singers()
    if not any(s.get("name") == singer_name for s in singers):
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


def check_remote_file_exists(ssh, path):
    stdin, stdout, stderr = ssh.exec_command(
        f"test -f '{path}' && echo exists || echo not_exists"
    )
    result = stdout.read().decode().strip()
    return result == "exists"


def wait_for_track_file(combined_dir, title, artists, check_interval=30):
    while True:
        for fname in os.listdir(combined_dir):
            if fname.endswith(".wav") and title in fname and artists in fname:
                print(f"[wait_for_track_file] 찾은 파일: {fname}")
                return os.path.join(combined_dir, fname)
        print(
            f"[wait_for_track_file] {title} 및 {artists}가 포함된 .wav 파일이 없음, {check_interval}초 후 재시도"
        )
        time.sleep(check_interval)


# ========================
# 음성 변환 요청 처리 엔드포인트
# ========================
@app.route("/convert", methods=["POST"])
def convert():
    data = request.json
    singer_name = data.get("singer_name")
    playlist_id = data.get("playlist_id")
    access_token = data.get("access_token")
    if not singer_name or not playlist_id or not access_token:
        return (
            jsonify({"error": "singer_name, playlist_id, access_token are required"}),
            400,
        )

    try:
        # 1. 플레이리스트 곡들을 GPU 서버에 다운로드
        download_playlist_to_gpu_via_ssh(playlist_id, access_token)

        # 2. 이후 Slurm 파이프라인 실행 (separate.sh, batch_infer.sh, combine.sh, cleanup.sh)
        ssh = connect_ssh()
        # 보컬 분리 (입력: input/*.wav, 출력: hidden/inst/*.wav(반주), hidden/*.wav(보컬))
        separate_cmd = (
            "cd /data/msj9518/repos/rvc-cli && "
            "source /data/msj9518/anaconda3/etc/profile.d/conda.sh && conda activate rvc && "
            "sbatch /data/msj9518/repos/vcstream/run/separate.sh"
        )
        separate_jobid = submit_job(ssh, separate_cmd)
        # 추론 (입력: hidden/*.wav(보컬), 출력: output/IU_곡제목.wav)
        batch_infer_cmd = (
            "cd /data/msj9518/repos/rvc-cli && "
            "source /data/msj9518/anaconda3/etc/profile.d/conda.sh && conda activate rvc && "
            f"sbatch --dependency=afterok:{separate_jobid} /data/msj9518/repos/vcstream/run/batch_infer.sh '{singer_name}'"
        )
        batch_jobid = submit_job(ssh, batch_infer_cmd)
        # 결합 (입력: hidden/inst/*.wav, output/*.wav, 출력: combined/)
        combine_cmd = (
            "cd /data/msj9518/repos/vcstream/run && "
            "source /data/msj9518/anaconda3/etc/profile.d/conda.sh && conda activate rvc && "
            f"sbatch --dependency=afterok:{batch_jobid} /data/msj9518/repos/vcstream/run/combine.sh '{singer_name}'"
        )
        combine_jobid = submit_job(ssh, combine_cmd)
        # 정리
        cleanup_cmd = (
            "cd /data/msj9518/repos/vcstream/run && "
            "source /data/msj9518/anaconda3/etc/profile.d/conda.sh && conda activate rvc && "
            f"sbatch --dependency=afterok:{combine_jobid} /data/msj9518/repos/vcstream/run/cleanup.sh"
        )
        submit_job(ssh, cleanup_cmd)
        close_ssh(ssh)

        return jsonify({"status": "conversion completed"})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


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
        singer_name = data.get("singer_name")
        if singer_name:
            add_singer(singer_name)
            try:
                ssh = connect_ssh()
                # 1. train_input/가수이름 디렉토리 생성 및 yt-dlp로 음원 다운로드
                train_input_dir = (
                    f"/data/msj9518/repos/vcstream/rvc/train_input/{singer_name}"
                )
                # 디렉토리 없을 때만 생성
                stdin, stdout, stderr = ssh.exec_command(
                    f"[ -d '{train_input_dir}' ] && echo 'exists' || echo 'not_exists'"
                )
                if stdout.read().decode().strip() == "not_exists":
                    ssh.exec_command(f"mkdir -p '{train_input_dir}'")
                url = get_youtube_url(singer_name)
                if url:
                    safe_title = f"{singer_name}".replace("/", "_").replace("\\", "_")
                    yt_dlp_cmd = (
                        f"cd '{train_input_dir}' && "
                        "source /data/msj9518/anaconda3/etc/profile.d/conda.sh && conda activate rvc && "
                        f"yt-dlp -x --audio-format wav '{url}' -o '{safe_title}.%(ext)s'"
                    )
                    stdin, stdout, stderr = ssh.exec_command(yt_dlp_cmd)
                    out = stdout.read().decode()
                    err = stderr.read().decode()
                    if out:
                        logging.info(f"[yt-dlp STDOUT] {out}")
                    if err:
                        logging.error(f"[yt-dlp STDERR] {err}")
                # 2. datasets/가수이름 디렉토리 생성
                datasets_dir = (
                    f"/data/msj9518/repos/vcstream/rvc/datasets/{singer_name}"
                )
                stdin, stdout, stderr = ssh.exec_command(
                    f"[ -d '{datasets_dir}' ] && echo 'exists' || echo 'not_exists'"
                )
                if stdout.read().decode().strip() == "not_exists":
                    ssh.exec_command(f"mkdir -p '{datasets_dir}'")
                # 3. 보컬 분리 (separate_train.sh)
                separate_cmd = (
                    f"cd /data/msj9518/repos/rvc-cli && "
                    f"source /data/msj9518/anaconda3/etc/profile.d/conda.sh && conda activate rvc && "
                    f"sbatch /data/msj9518/repos/vcstream/run/separate_train.sh '{singer_name}'"
                )
                separate_jobid = submit_job(ssh, separate_cmd)
                # 4. 학습 (train_atoz.sh, 보컬 분리 작업이 끝난 후 실행)
                train_cmd = (
                    f"cd /data/msj9518/repos/rvc-cli && "
                    f"source /data/msj9518/anaconda3/etc/profile.d/conda.sh && conda activate rvc && "
                    f"sbatch --dependency=afterok:{separate_jobid} /data/msj9518/repos/vcstream/run/train_atoz.sh '{singer_name}'"
                )
                submit_job(ssh, train_cmd)
                close_ssh(ssh)
            except Exception as e:
                logging.error(f"학습 파이프라인 실행 실패: {e}")
                return jsonify({"error": str(e)}), 500
        return jsonify({"singers": load_selected_singers()})
    elif request.method == "DELETE":
        data = request.json
        singer_name = data.get("singer_name")
        singers = load_selected_singers()
        singers = [s for s in singers if s.get("name") != singer_name]
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
    global conversion_mode, ssh_connection, conversion_mode_state
    if request.method == "POST":
        data = request.json
        # 단일 사용자면 'default' 키 사용, 여러 사용자면 user_id 등으로 구분
        user_id = data.get("user_id", "default")
        conversion_mode_state[user_id] = {
            "singer_name": data.get("singer_name"),
            "spotify_access_token": data.get("spotify_access_token"),
            "fcm_token": data.get("fcm_token"),
            "on": data.get("on", False),
            "started_at": datetime.utcnow().isoformat() + "Z",
        }
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
        return jsonify(
            {"on": conversion_mode, "conversion_mode_state": conversion_mode_state}
        )
    # GET: 현재 상태 반환
    return jsonify(
        {"on": conversion_mode, "conversion_mode_state": conversion_mode_state}
    )


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
    ssh = connect_ssh()
    for s in singers:
        if s["status"] != "done":
            model_dir = f"/data/msj9518/repos/vcstream/rvc/models/{s['name']}"
            pth_path = os.path.join(model_dir, f"{s['name']}_best.pth")
            index_path = os.path.join(model_dir, f"{s['name']}.index")
            pth_exists = check_remote_file_exists(ssh, pth_path)
            index_exists = check_remote_file_exists(ssh, index_path)
            if pth_exists and index_exists:
                s["status"] = "done"
                changed = True
    if changed:
        save_selected_singers(singers)
    close_ssh(ssh)
    return jsonify({"singers": singers})


def sync_outputs_internal(
    remote_output_dir="/data/msj9518/repos/vcstream/rvc/combined",
):
    ssh = connect_ssh()
    local_output_dir = "output"
    os.makedirs(local_output_dir, exist_ok=True)
    stdin, stdout, stderr = ssh.exec_command(
        f"find {remote_output_dir} -maxdepth 1 -name '*.wav'"
    )
    files = [line.strip() for line in stdout.readlines() if line.strip()]
    for remote_file in files:
        # 파일명에서 공백을 _로 변환
        base_name = os.path.basename(remote_file).replace(" ", "_")
        local_file = os.path.join(local_output_dir, base_name)
        try:
            download_file(ssh, remote_file, local_file)
        except FileNotFoundError:
            print(f"[LOG] 파일 없음(무시): {remote_file}")
        except Exception as e:
            print(f"[LOG] 다운로드 중 오류(무시): {remote_file}, {e}")
    close_ssh(ssh)


@app.route("/sync_outputs", methods=["POST"])
def sync_outputs():
    sync_outputs_internal()
    return jsonify({"status": "synced"})


@app.route("/output_files", methods=["GET"])
def output_files():
    output_dir = "output"
    files = [f for f in os.listdir(output_dir) if f.endswith(".wav")]
    return jsonify({"files": files})


@app.route("/download_output/<filename>", methods=["GET"])
def download_output(filename):
    output_dir = "output"
    file_path = os.path.join(output_dir, filename)
    if not os.path.exists(file_path):
        return "파일이 존재하지 않습니다.", 404
    return send_file(file_path, as_attachment=True)


@app.route("/current_spotify_context", methods=["POST"])
def current_spotify_context():
    data = request.json
    access_token = data.get("access_token")
    if not access_token:
        return jsonify({"error": "access_token required"}), 400

    headers = {"Authorization": f"Bearer {access_token}"}
    resp = requests.get("https://api.spotify.com/v1/me/player", headers=headers)
    if resp.status_code != 200:
        return (
            jsonify({"error": "Spotify API error", "detail": resp.text}),
            resp.status_code,
        )

    player = resp.json()
    context = player.get("context")
    if context and context.get("uri", "").startswith("spotify:playlist:"):
        playlist_uri = context["uri"]  # 예: spotify:playlist:xxxx
        playlist_id = playlist_uri.split(":")[-1]
        return jsonify({"playlist_id": playlist_id, "playlist_uri": playlist_uri})
    else:
        return jsonify({"error": "No playlist context found", "context": context}), 404


def convert_playlist_internal(playlist_id, access_token, singer_name):
    if not playlist_id or not access_token or not singer_name:
        return {"error": "playlist_id, access_token, singer_name are required"}, 400
    try:
        # 1. 플레이리스트 곡들을 GPU 서버에 다운로드
        download_playlist_to_gpu_via_ssh(playlist_id, access_token)

        # 2. 이후 Slurm 파이프라인 실행 (separate.sh, batch_infer.sh, combine.sh, cleanup.sh)
        ssh = connect_ssh()
        # 보컬 분리
        separate_cmd = (
            "cd /data/msj9518/repos/rvc-cli && "
            "source /data/msj9518/anaconda3/etc/profile.d/conda.sh && conda activate rvc && "
            "sbatch /data/msj9518/repos/vcstream/run/separate.sh"
        )
        separate_jobid = submit_job(ssh, separate_cmd)

        # 2. batch_infer (보컬 분리 후)
        batch_infer_cmd = (
            "cd /data/msj9518/repos/rvc-cli && "
            "source /data/msj9518/anaconda3/etc/profile.d/conda.sh && conda activate rvc && "
            f"sbatch --dependency=afterok:{separate_jobid} /data/msj9518/repos/vcstream/run/batch_infer.sh '{singer_name}'"
        )
        batch_jobid = submit_job(ssh, batch_infer_cmd)

        # 3. combine (batch_infer 후)
        combine_cmd = (
            "cd /data/msj9518/repos/vcstream/run && "
            "source /data/msj9518/anaconda3/etc/profile.d/conda.sh && conda activate rvc && "
            f"sbatch --dependency=afterok:{batch_jobid} /data/msj9518/repos/vcstream/run/combine.sh '{singer_name}'"
        )
        combine_jobid = submit_job(ssh, combine_cmd)

        # 4. combine 작업이 끝난 후 결과 파일 확인/다운로드
        combined_dir = "/data/msj9518/repos/vcstream/rvc/combined"
        time.sleep(240)
        close_ssh(ssh)

        # 5. 결과물 동기화 (다운로드)
        sync_outputs_internal(
            remote_output_dir="/data/msj9518/repos/vcstream/rvc/combined"
        )

        # 6. clean (combine 작업 이후)
        ssh = connect_ssh()
        cleanup_cmd = (
            "cd /data/msj9518/repos/vcstream/run && "
            "source /data/msj9518/anaconda3/etc/profile.d/conda.sh && conda activate rvc && "
            f"sbatch --dependency=afterok:{combine_jobid} /data/msj9518/repos/vcstream/run/cleanup.sh"
        )
        submit_job(ssh, cleanup_cmd)
        close_ssh(ssh)
        return {"status": "playlist conversion started"}, 200
    except Exception as e:
        return {"error": str(e)}, 500


@app.route("/convert_playlist", methods=["POST"])
def convert_playlist():
    data = request.json
    playlist_id = data.get("playlist_id")
    access_token = data.get("access_token")
    singer_name = data.get("singer_name")
    result, status = convert_playlist_internal(playlist_id, access_token, singer_name)
    return jsonify(result), status


def playlist_polling_worker():
    with app.app_context():
        while conversion_mode_state["active"]:
            access_token = conversion_mode_state["access_token"]
            singer_name = conversion_mode_state["singer_name"]
            if not access_token or not singer_name:
                time.sleep(2)
                continue
            headers = {"Authorization": f"Bearer {access_token}"}
            resp = requests.get("https://api.spotify.com/v1/me/player", headers=headers)
            if resp.status_code == 200:
                player = resp.json()
                context = player.get("context")
                if context and context.get("uri", "").startswith("spotify:playlist:"):
                    playlist_id = context["uri"].split(":")[-1]
                    # 변환 파이프라인 함수 직접 호출
                    try:
                        print(
                            f"[LOG] Detected playlist_id: {playlist_id}, starting conversion..."
                        )
                        result, status = convert_playlist_internal(
                            playlist_id, access_token, singer_name
                        )
                        print(
                            f"[LOG] convert_playlist_internal result: {result}, status: {status}"
                        )
                    except Exception as e:
                        print(f"[ERROR] Exception in polling thread: {e}")
                    conversion_mode_state["active"] = False
                    break
            time.sleep(3)


if __name__ == "__main__":
    logging.info("[LOG] Server started")
    app.run(host="0.0.0.0", port=5000, debug=False, use_reloader=False)
