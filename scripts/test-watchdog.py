#!/usr/bin/env python3
"""Exercises the native supervisor using sacrificial child processes; no input hooks."""
import os
import signal
import subprocess
import sys
import time
from pathlib import Path

binary = str(Path(sys.argv[1]).resolve())
bad_parent = subprocess.run([binary, "--watchdog", "1"], timeout=3)
assert bad_parent.returncode == 2, "must reject unrelated parent IDs"
print("PASS unrelated parent rejected")

orderly = r'''
import os, subprocess, sys
p = subprocess.Popen([sys.argv[1], '--watchdog', str(os.getpid())], stdin=subprocess.PIPE)
p.stdin.write(b'0\n'); p.stdin.flush(); p.stdin.close()
assert p.wait(timeout=3) == 0
'''
assert subprocess.run([sys.executable, "-c", orderly, binary], timeout=5).returncode == 0
print("PASS pipe EOF exits without killing healthy parent")

delayed_shutdown = r'''
import os, signal, subprocess, sys, time
p = subprocess.Popen([sys.argv[1], '--watchdog', str(os.getpid())], stdin=subprocess.PIPE)
p.stdin.write(b'0\n'); p.stdin.flush()
time.sleep(0.15)
os.kill(p.pid, signal.SIGSTOP)
p.stdin.write(b'1\n'); p.stdin.flush(); p.stdin.close()
os.kill(p.pid, signal.SIGCONT)
assert p.wait(timeout=3) == 0
'''
assert subprocess.run([sys.executable, "-c", delayed_shutdown, binary], timeout=5).returncode == 0
print("PASS orderly shutdown wins over buffered expired deadline")

frozen = r'''
import os, subprocess, sys, time
p = subprocess.Popen([sys.argv[1], '--watchdog', str(os.getpid())], stdin=subprocess.PIPE)
p.stdin.write(sys.argv[2].encode() + b'\n'); p.stdin.flush()
time.sleep(15)
'''
for value, expected_max, label in [("0", 7, "missing heartbeat"), ("1", 3, "expired deadline")]:
    started = time.monotonic()
    parent = subprocess.Popen([sys.executable, "-c", frozen, binary, value])
    result = parent.wait(timeout=expected_max)
    assert result == -signal.SIGKILL, (label, result)
    assert time.monotonic() - started < expected_max
    print(f"PASS {label} terminates only its test owner")
print("All 5 supervisor tests passed. No keyboard or mouse hooks were installed.")
