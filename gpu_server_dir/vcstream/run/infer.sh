#!/usr/bin/bash

#SBATCH -J VC_infer
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-gpu=8
#SBATCH --mem-per-gpu=29G
#SBATCH -p batch_ugrad
#SBATCH -t 1-0
#SBATCH -o logs/slurm-infer-%A.out

python /data/msj9518/repos/rvc-cli/rvc_cli.py infer \
--input_path "/data/msj9518/repos/vcstream/rvc/hidden/yerinbaek_antifreeze_3steps.wav" \
--output_path "/data/msj9518/repos/vcstream/rvc/output/yerinbaek_antifreeze_3steps_output.wav" \
--pth_path "/data/msj9518/repos/vcstream/rvc/models/rose/rose_best.pth" \
--index_path "/data/msj9518/repos/vcstream/rvc/models/rose/rose.index"
