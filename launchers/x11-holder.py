#!/usr/bin/env python3
"""Hold X11 connection so socket stays alive for proot to connect.

XWayland removes the X11 socket when no clients are connected.
This script connects and holds the socket open until killed.
"""
import socket, sys, time, os, signal

sock_path = sys.argv[1]

s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.settimeout(5)
s.connect(sock_path)

# Minimal X11 connection setup (no auth)
s.send(b'l\x00\x0b\x00\x00\x00\x00\x00\x00\x00\x00\x00')
d = s.recv(8)

# Signal parent we're connected
with open(sock_path + '.holder', 'w') as f:
    f.write(str(os.getpid()))

# Ignore SIGINT/SIGTERM so parent can kill us cleanly
signal.signal(signal.SIGTERM, lambda *_: exit(0))
signal.signal(signal.SIGINT, lambda *_: exit(0))

# Hold until killed — periodic recv to detect disconnection
try:
    while True:
        time.sleep(30)
except (BrokenPipeError, OSError):
    pass
finally:
    s.close()
    try:
        os.unlink(sock_path + '.holder')
    except OSError:
        pass
