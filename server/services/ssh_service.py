import os
import paramiko
import time
import logging

logging.basicConfig(level=logging.INFO)


def connect_ssh():
    host = os.environ.get("SSH_HOST")
    username = os.environ.get("SSH_USER")
    password = os.environ.get("SSH_PASSWORD")
    port = int(os.environ.get("SSH_PORT", 22))

    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(host, port=port, username=username, password=password)
    return ssh


def upload_file(ssh, local_path, remote_path):
    sftp = ssh.open_sftp()
    sftp.put(local_path, remote_path)
    sftp.close()


def submit_job(ssh, run_sh_path="run.sh"):
    command = "cd /data/msj9518/repos/seed-vc && " f"sbatch {run_sh_path}"
    logging.info(f"[LOG] SSH에서 Slurm 작업 제출: {command}")
    stdin, stdout, stderr = ssh.exec_command(command)
    job_submission_output = stdout.read().decode().strip()
    error_output = stderr.read().decode().strip()
    logging.info(f"[LOG] Slurm 제출 결과: {job_submission_output}")
    # 'sbatch: AURORA: Job submitted' 메시지는 에러가 아니므로 무시
    if error_output and "AURORA: Job submitted" not in error_output:
        logging.error(f"[ERROR] Slurm 제출 에러: {error_output}")
    elif error_output:
        logging.info(f"[LOG] Slurm 안내 메시지: {error_output}")
    return job_submission_output


# GPU 서버에서 작업이 끝날 때까지 대기하는 기능 ••• 방식 개선?
# check_interval: 작업이 완료되었는지 확인하는 주기
def wait_for_job_done(ssh, output_path, check_interval=5):
    job_done = False
    while not job_done:
        stdin, stdout, stderr = ssh.exec_command(
            f"test -f {output_path} && echo 'done'"
        )
        if stdout.read().decode().strip() == "done":
            job_done = True
        else:
            time.sleep(check_interval)


def download_file(
    ssh, remote_path, local_path, remote_input_path="none", remote_output_path="none"
):
    print(f"[LOG] 다운로드 시도: {remote_path} → {local_path}")
    sftp = ssh.open_sftp()
    sftp.get(remote_path, local_path)
    if remote_input_path != "none":
        sftp.remove(remote_input_path)
    if remote_output_path != "none":
        sftp.remove(remote_output_path)
    sftp.close()
    print(f"[LOG] 다운로드 완료: {local_path}")


def close_ssh(ssh):
    ssh.close()
