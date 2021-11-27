#!/usr/bin/env bash
set -eo pipefail
sudo apt-get update
sudo apt install python3-pip -y
pip install -r requirements.txt
export PATH=$PATH:/home/ubuntu/.local/bin
cd ..
tmux new-session -d -s app 'uvicorn src.main:app --host=0.0.0.0'
