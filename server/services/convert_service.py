import os
from services.ssh_service import (
    connect_ssh,
    upload_file,
    submit_job,
    wait_for_job_done,
    download_file,
    close_ssh,
)
from services.separate_service import separate_vocals_on_gpu_server


def convert_song(local_song_path, singer_name):
    """
    전체 음원 변환 파이프라인 실행 함수
    1. 입력 파일을 GPU 서버로 업로드
    2. 보컬 분리 실행
    3. Slurm Job 제출(추론)
    4. 보컬+반주 결합 (combine.py)
    5. 결과 파일 다운로드
    6. SSH 연결 종료
    :param local_song_path: 변환할 로컬 음원 파일 경로
    :param singer_name: 타겟 가수(모델) 이름
    :return: 변환된 로컬 결과 파일 경로
    """
    ssh = connect_ssh()
    try:
        # 1. 업로드
        remote_input = f"/data/msj9518/repos/vcstream/rvc/input/{os.path.basename(local_song_path)}"
        upload_file(ssh, local_song_path, remote_input)

        # 2. 보컬 분리
        remote_hidden_dir = "/data/msj9518/repos/vcstream/rvc/hidden"
        success, msg = separate_vocals_on_gpu_server(ssh)
        if not success:
            raise RuntimeError(f"보컬 분리 실패: {msg}")

        # 3. Slurm 추론
        command = f"cd /data/msj9518/repos/rvc-cli && source /data/msj9518/anaconda3/etc/profile.d/conda.sh && conda activate rvc && sbatch /data/msj9518/repos/vcstream/run/batch_infer.sh {singer_name}"
        result = submit_job(ssh, command)

        # 4. 결합 단계
        vocal_filename = f"{os.path.splitext(os.path.basename(local_song_path))[0]}_{singer_name}.wav"
        vocal_path = f"/data/msj9518/repos/vcstream/rvc/output/{vocal_filename}"
        inst_path = f"/data/msj9518/repos/vcstream/rvc/hidden/inst/{os.path.basename(local_song_path)}"
        combined_path = (
            f"/data/msj9518/repos/vcstream/rvc/combined/combined_{vocal_filename}"
        )
        success, msg = combine_vocal_and_instrumental(
            ssh, vocal_path, inst_path, combined_path
        )
        if not success:
            raise RuntimeError(f"보컬/반주 결합 실패: {msg}")

        # 5. 결과 파일 다운로드 (결합된 파일)
        local_output_dir = os.path.join("output")
        os.makedirs(local_output_dir, exist_ok=True)
        local_output = os.path.join(local_output_dir, f"combined_{vocal_filename}")
        wait_for_job_done(ssh, combined_path)
        download_file(ssh, combined_path, local_output)

        # 6. 디렉토리 정리 Slurm 작업 실행
        cleanup_cmd = (
            "cd /data/msj9518/repos/vcstream/run && "
            "source /data/msj9518/anaconda3/etc/profile.d/conda.sh && conda activate rvc && "
            f"sbatch /data/msj9518/repos/vcstream/run/cleanup.sh"
        )
        submit_job(ssh, cleanup_cmd)

        return local_output
    finally:
        close_ssh(ssh)


def combine_vocal_and_instrumental(ssh, vocal_path, inst_path, output_path):
    """
    변환된 보컬과 원곡 반주를 결합하는 함수 (combine.py 실행)
    :param ssh: paramiko SSHClient 객체
    :param vocal_path: 변환된 보컬 wav 파일 경로
    :param inst_path: 원곡 반주 wav 파일 경로
    :param output_path: 결합 결과 파일 경로
    :return: (성공 여부, 메시지)
    """
    try:
        command = (
            "cd /data/msj9518/repos/vcstream/run && "
            "source /data/msj9518/anaconda3/etc/profile.d/conda.sh && conda activate rvc && "
            "sbatch /data/msj9518/repos/vcstream/run/combine.sh"
        )
        out = submit_job(ssh, command)
        return True, out
    except Exception as e:
        return False, str(e)
