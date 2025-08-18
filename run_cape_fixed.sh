#!/bin/bash
cd /opt/CAPEv2
export PATH="$HOME/.local/bin:$PATH"
source $(poetry env info --path)/bin/activate
python3 cuckoo.py
