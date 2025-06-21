import os
import sys
from pydub import AudioSegment

if len(sys.argv) < 2:
    print("[ERROR] Usage: python combine.py <singer_name>")
    exit(1)

singer_name = sys.argv[1]

inst_dir = "/data/msj9518/repos/vcstream/rvc/hidden/inst"
vocal_dir = "/data/msj9518/repos/vcstream/rvc/output"
output_dir = "/data/msj9518/repos/vcstream/rvc/combined"
os.makedirs(output_dir, exist_ok=True)

inst_files = [f for f in os.listdir(inst_dir) if f.endswith("_inst.wav")]
inst_prefixes = {f.replace("_inst.wav", "") for f in inst_files}

vocal_files = [f for f in os.listdir(vocal_dir) if f.endswith("_vocal_output.wav")]
vocal_prefixes = {f.replace("_vocal_output.wav", "") for f in vocal_files}

common_prefixes = inst_prefixes & vocal_prefixes

for prefix in common_prefixes:
    inst_path = os.path.join(inst_dir, f"{prefix}_inst.wav")
    vocal_path = os.path.join(vocal_dir, f"{prefix}_vocal_output.wav")
    out_path = os.path.join(output_dir, f"{singer_name}_{prefix}.wav")

    try:
        inst = AudioSegment.from_wav(inst_path)
    except Exception as e:
        print(f"[ERROR] Failed to load inst file: {inst_path} - {e}")
        continue
    try:
        vocal = AudioSegment.from_wav(vocal_path)
    except Exception as e:
        print(f"[ERROR] Failed to load vocal file: {vocal_path} - {e}")
        continue
    try:
        combined = inst.overlay(vocal)
        combined.export(out_path, format="wav")
        print(f"[INFO] Successfully combined: {out_path}")
    except Exception as e:
        print(f"[ERROR] Failed to combine/export: {out_path} - {e}")
    