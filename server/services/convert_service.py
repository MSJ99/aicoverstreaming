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
    ssh = connect_ssh()
    try:
        # 1. 업로드
        remote_input = f"/data/msj9518/repos/vcstream/rvc/input/{os.path.basename(local_song_path)}"
        upload_file(ssh, local_song_path, remote_input)

        # 2. 보컬 분리
        remote_hidden_dir = "/data/msj9518/repos/vcstream/rvc/hidden"
        success, msg = separate_vocals_on_gpu_server(
            ssh, remote_input, remote_hidden_dir
        )
        if not success:
            raise RuntimeError(f"보컬 분리 실패: {msg}")

        # 3. Slurm 추론
        submit_job(
            ssh,
            run_sh_path=f"/data/msj9518/repos/vcstream/run/batch_infer.sh {singer_name}",
        )

        # 4. 결과 파일 다운로드
        output_filename = f"{os.path.splitext(os.path.basename(local_song_path))[0]}_{singer_name}.wav"
        remote_output = f"/data/msj9518/repos/vcstream/rvc/output/{output_filename}"
        local_output_dir = os.path.join("server", "output")
        os.makedirs(local_output_dir, exist_ok=True)
        local_output = os.path.join(local_output_dir, output_filename)
        wait_for_job_done(ssh, remote_output)
        download_file(ssh, remote_output, local_output)

        return local_output
    finally:
        close_ssh(ssh)
