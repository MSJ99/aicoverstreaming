import os
import paramiko
import time
import logging
import re

logging.basicConfig(level=logging.INFO)


def connect_ssh():
    """
    SSH 연결을 생성하여 반환
    환경변수에서 접속 정보(호스트, 유저, 비밀번호, 포트) 사용
    """
    host = os.environ.get("SSH_HOST")
    username = os.environ.get("SSH_USER")
    password = os.environ.get("SSH_PASSWORD")
    port = int(os.environ.get("SSH_PORT", 22))

    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(host, port=port, username=username, password=password)
    return ssh


def upload_file(ssh, local_path, remote_path):
    """
    로컬 파일을 SSH를 통해 원격 서버로 업로드
    """
    sftp = ssh.open_sftp()
    sftp.put(local_path, remote_path)
    sftp.close()


def submit_job(ssh, command):
    """
    Slurm 작업을 제출하는 명령을 SSH로 실행
    :param command: 실행할 전체 명령어 (예: 'cd ... && sbatch ...')
    :return: Slurm 제출 결과 메시지와 job id
    """
    logging.info(f"[LOG] SSH에서 Slurm 작업 제출: {command}")
    stdin, stdout, stderr = ssh.exec_command(command)
    job_submission_output = stdout.read().decode().strip()
    error_output = stderr.read().decode().strip()
    logging.info(f"[LOG] Slurm 제출 결과: {job_submission_output}")
    if error_output and "AURORA: Job submitted" not in error_output:
        logging.error(f"[ERROR] Slurm 제출 에러: {error_output}")
    elif error_output:
        logging.info(f"[LOG] Slurm 안내 메시지: {error_output}")
    # Slurm job id 추출
    match = re.search(r"Submitted batch job (\d+)", job_submission_output)
    job_id = match.group(1) if match else None
    return job_id


def wait_for_job_done(ssh, output_path, check_interval=5):
    """
    Slurm 작업이 완료될 때까지(결과 파일이 생성될 때까지) 대기
    :param output_path: 결과 파일 경로
    :param check_interval: 확인 주기(초)
    """
    job_done = False
    while not job_done:
        print(f"[wait_for_job_done] 파일 존재 확인 시도: {output_path}")
        stdin, stdout, stderr = ssh.exec_command(
            f"test -f {output_path} && echo 'done'"
        )
        result = stdout.read().decode().strip()
        if result == "done":
            print(f"[wait_for_job_done] 파일 생성됨: {output_path}")
            job_done = True
        else:
            print(
                f"[wait_for_job_done] 파일 없음, {check_interval}초 후 재시도: {output_path}"
            )
            time.sleep(check_interval)


def download_file(
    ssh, remote_path, local_path, remote_input_path="none", remote_output_path="none"
):
    """
    원격 서버에서 파일을 다운로드하고, 필요시 원격 파일 삭제
    """
    logging.info(f"[LOG] 다운로드 시도: {remote_path} → {local_path}")
    sftp = ssh.open_sftp()
    sftp.get(remote_path, local_path)
    if remote_input_path != "none":
        sftp.remove(remote_input_path)
    if remote_output_path != "none":
        sftp.remove(remote_output_path)
    sftp.close()
    logging.info(f"[LOG] 다운로드 완료: {local_path}")


def close_ssh(ssh):
    """
    SSH 연결 종료
    """
    ssh.close()
