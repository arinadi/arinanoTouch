#!/usr/bin/env python3
"""
x11-holder.py — Menjaga X11 Unix socket tetap hidup selama proot startup.
Saat termux-x11 di-restart, socket bisa hilang sebelum proot connect.
Holder ini membuka socket sebagai client dan hold file marker.
"""
import sys
import os
import socket
import time

sock_path = sys.argv[1] if len(sys.argv) > 1 else '/data/data/com.termux/files/usr/tmp/.X11-unix/X0'
marker_path = sock_path + '.holder'

# Write marker
with open(marker_path, 'w') as f:
    f.write(str(os.getpid()))

# Connect and hold
try:
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(30)
    s.connect(sock_path)
    # Keep alive until stdin closes (or termux-x11 restart kills us)
    try:
        sys.stdin.read()
    except (EOFError, KeyboardInterrupt):
        pass
    s.close()
except Exception as e:
    print(f"holder: {e}", file=sys.stderr)
finally:
    try:
        os.unlink(marker_path)
    except FileNotFoundError:
        pass
