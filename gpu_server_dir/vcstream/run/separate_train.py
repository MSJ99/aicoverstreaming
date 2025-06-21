import os
import sys
import logging

sys.path.append("/data/msj9518/repos/rvc-cli")
from uvr.separator import Separator

singer_name = sys.argv[1]
input_dir = f"/data/msj9518/repos/vcstream/rvc/train_input/{singer_name}"
output_dir = f"/data/msj9518/repos/vcstream/rvc/datasets/{singer_name}"

os.makedirs(output_dir, exist_ok=True)

model_dir = "/data/yesje1/repos/ultimatevocalremovergui/models/MDX_Net_Models"
model_filename = "Kim_Vocal_2.onnx"

for file in os.listdir(input_dir):
    if file.lower().endswith(".wav"):
        audio_path = os.path.join(input_dir, file)
        base_name = os.path.splitext(file)[0]
        print(f"\n🔊 분리 중: {file}")

        separator = Separator(
            log_level=logging.INFO,
            model_file_dir=model_dir,
            output_dir=output_dir,
            output_format="WAV",
            normalization_threshold=0.9,
            output_single_stem=None,
            invert_using_spec=False,
            sample_rate=44100,
            mdx_params={
                "hop_length": 1024,
                "segment_size": 256,
                "overlap": 0.25,
                "batch_size": 1,
                "enable_denoise": False
            },
        )

        separator.load_model(model_filename=model_filename)
        output_paths = separator.separate(audio_path)

        for path in output_paths:
            full_path = os.path.join(output_dir, path) if not os.path.isabs(path) else path
            filename = os.path.basename(full_path)
            if "Vocals" in filename:
                new_filename = f"{base_name}.wav"
                new_path = os.path.join(output_dir, new_filename)
                os.rename(full_path, new_path)
                print(f"✅ 보컬 저장됨: {new_path}")
            # inst 파일은 무시