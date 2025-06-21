import os
import sys
import logging

# UVR 라이브러리 경로 등록
sys.path.append("/data/msj9518/repos/rvc-cli")
from uvr.separator import Separator

# 입력 및 출력 디렉토리 설정
input_dir = "/data/msj9518/repos/vcstream/rvc/input"
output_root = "/data/msj9518/repos/vcstream/rvc/hidden"
vocal_dir = os.path.join(output_root, "vocal")
inst_dir = os.path.join(output_root, "inst")

# 출력 디렉토리 생성
os.makedirs(vocal_dir, exist_ok=True)
os.makedirs(inst_dir, exist_ok=True)

# 모델 설정
model_dir = "/data/yesje1/repos/ultimatevocalremovergui/models/MDX_Net_Models"
model_filename = "Kim_Vocal_2.onnx"


# 입력 디렉토리 내 모든 .wav 파일 순회
for file in os.listdir(input_dir):
    if file.lower().endswith(".wav"):
        audio_path = os.path.join(input_dir, file)
        base_name = os.path.splitext(file)[0]
        print(f"\n🔊 분리 중: {file}")

        # ✅ 곡마다 Separator 새로 생성
        separator = Separator(
            log_level=logging.INFO,
            model_file_dir=model_dir,
            output_dir=output_root,
            output_format="WAV",
            normalization_threshold=0.9,
            output_single_stem=None,
            invert_using_spec=False,
            sample_rate=44100,
            mdx_params={  # ✅ MDX 모델이므로 여기에 설정
                "hop_length": 1024,
                "segment_size": 256,
                "overlap": 0.25,
                "batch_size": 1,
                "enable_denoise": False
            },
        )

        # 모델 로드 (등록되지 않은 사용자 모델일 경우 허용)
        separator.load_model(model_filename=model_filename)


        # 분리 수행
        output_paths = separator.separate(audio_path)

        for path in output_paths:
            full_path = os.path.join(output_root, path) if not os.path.isabs(path) else path
            filename = os.path.basename(full_path)

            if "Vocals" in filename:
                new_filename = f"{base_name}_vocal.wav"
                new_path = os.path.join(vocal_dir, new_filename)
                os.rename(full_path, new_path)
                print(f"✅ 보컬 저장됨: {new_path}")
            elif "Instrumental" in filename:
                new_filename = f"{base_name}_inst.wav"
                new_path = os.path.join(inst_dir, new_filename)
                os.rename(full_path, new_path)
                print(f"✅ 반주 저장됨: {new_path}")
