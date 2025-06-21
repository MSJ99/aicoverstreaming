#!/usr/bin/bash

#SBATCH -J VC_combine
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-gpu=8
#SBATCH --mem-per-gpu=29G
#SBATCH -p batch_ugrad
#SBATCH -w aurora-g1
#SBATCH -t 1-0

SINGER_NAME="$1"

python combine.py "$SINGER_NAME"