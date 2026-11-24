#!/usr/bin/python3
"""Headless smoke test for the GTK3 window.

Runs under Xvfb (`xvfb-run -a python3 test/gui-smoke.py`), points the GUI at a
locally built as-client, starts playback against a running as-cmd, waits for
the throughput counter, and writes a screenshot for visual inspection.

Exit code 0 = window shows a live stream.
"""

import importlib.util
import os
import sys
import time

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
from gi.repository import Gdk, GLib, Gtk  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
GUI = os.path.join(HERE, "..", "gui", "audio-share-gui")
CLIENT = os.path.join(HERE, "..", "as-client")
SHOT = os.environ.get("SHOT", "/tmp/audio-share-gui.png")
HOST = os.environ.get("AS_HOST", "127.0.0.1")
PORT = os.environ.get("AS_PORT", "65530")
WAIT = float(os.environ.get("WAIT", "7"))


def pump(seconds):
    end = time.time() + seconds
    while time.time() < end:
        while Gtk.events_pending():
            Gtk.main_iteration_do(False)
        time.sleep(0.02)


def main():
    if not os.access(CLIENT, os.X_OK):
        print("missing %s (run `make` first)" % CLIENT)
        return 2
    os.environ["AUDIO_SHARE_CLIENT_BIN"] = CLIENT
    os.environ["XDG_CONFIG_HOME"] = "/tmp/as-gui-smoke-cfg"

    from importlib.machinery import SourceFileLoader

    loader = SourceFileLoader("asgui", GUI)
    spec = importlib.util.spec_from_loader("asgui", loader)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)

    win = mod.Window()
    win.host_entry.set_text(HOST)
    win.port_spin.set_value(int(PORT))
    win.show_all()
    pump(0.5)
    win.on_action(win.action_btn)          # 开始播放
    pump(WAIT)

    status = win.status.get_text()
    rate = win.rate_label.get_text()
    print("status : %s" % status)
    print("rate   : %s" % rate)
    print("button : %s" % win.action_btn.get_label())
    print("alive  : %s" % (win.proc is not None))

    pump(0.4)   # let the last label repaint before grabbing the frame
    gwin = win.get_window()
    if gwin is not None:
        w, h = gwin.get_width(), gwin.get_height()
        pb = Gdk.pixbuf_get_from_window(gwin, 0, 0, w, h)
        if pb is not None:
            pb.savev(SHOT, "png", [], [])
            print("shot   : %s (%dx%d)" % (SHOT, w, h))

    win.stop_client()
    pump(1.0)
    print("stopped: %s" % win.status.get_text())

    ok = ("已连接" in status) and ("KB/s" in rate or "MB/s" in rate)
    print("RESULT :", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
