#!/usr/bin/env bash
set -eo pipefail
sudo apt update
sudo apt install python3-pip -y
export PATH=$PATH:/home/ubuntu/.local/bin
pip install -r requirements.txt
cd ..
tmux new-session -d -s app 'uvicorn src.main:app --host=0.0.0.0'
