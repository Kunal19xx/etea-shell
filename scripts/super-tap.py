#!/usr/bin/env python3
# Super tapped on its own opens ETEA's launcher, as it does on Hyprland. niri can't bind
# a bare modifier, so this listens to the input devices (the user has to be in the
# "input" group) and only ever looks for one thing: Super pressed and let go with no
# other key, click or scroll in between. Nothing is kept or sent anywhere else.
#   super-tap.py <shell path>

import ctypes
import os
import selectors
import signal
import subprocess
import sys
import time

import evdev
from evdev import ecodes

SHELL = sys.argv[1]
SUPER = {ecodes.KEY_LEFTMETA, ecodes.KEY_RIGHTMETA}
LONGEST = 0.6  # held longer than this, it was a hold, not a tap


def devices():
    found = {}
    for path in evdev.list_devices():
        try:
            device = evdev.InputDevice(path)
        except OSError:
            continue
        keys = device.capabilities().get(ecodes.EV_KEY, [])
        # Keyboards, and mice too, since a click with Super down isn't a tap
        if SUPER & set(keys) or ecodes.BTN_LEFT in keys:
            found[path] = device
        else:
            device.close()
    return found


def main():
    # Gone with the shell: the kernel ends us when it dies, and we check it's still there
    parent = os.getppid()
    try:
        ctypes.CDLL("libc.so.6", use_errno=True).prctl(1, signal.SIGTERM)  # PR_SET_PDEATHSIG
    except OSError:
        pass
    selector = selectors.DefaultSelector()
    watched = {}
    pressed_at = None
    spoiled = False
    last_scan = 0.0
    while True:
        if os.getppid() != parent:
            return
        # Devices plugged in later are picked up every few seconds
        if time.monotonic() - last_scan > 5:
            last_scan = time.monotonic()
            for path, device in devices().items():
                if path in watched:
                    device.close()
                    continue
                watched[path] = device
                selector.register(device, selectors.EVENT_READ)
        for key, _ in selector.select(timeout=5):
            device = key.fileobj
            try:
                events = list(device.read())
            except OSError:
                selector.unregister(device)
                watched.pop(device.path, None)
                continue
            for event in events:
                if event.type == ecodes.EV_KEY and event.value != 2:
                    if event.code in SUPER:
                        if event.value == 1:
                            pressed_at, spoiled = time.monotonic(), False
                        elif pressed_at is not None:
                            if not spoiled and time.monotonic() - pressed_at < LONGEST:
                                subprocess.Popen(["qs", "-p", SHELL, "ipc", "call", "launcher", "toggle"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                            pressed_at = None
                    elif event.value == 1 and pressed_at is not None:
                        spoiled = True
                elif event.type == ecodes.EV_REL and event.code in (ecodes.REL_WHEEL, ecodes.REL_HWHEEL) and pressed_at is not None:
                    spoiled = True


if __name__ == "__main__":
    if not os.access("/dev/input", os.R_OK) or not any(os.access(path, os.R_OK) for path in evdev.list_devices() or ["/nonexistent"]):
        print("super-tap: can't read the input devices; add yourself to the input group", file=sys.stderr)
        sys.exit(1)
    main()
