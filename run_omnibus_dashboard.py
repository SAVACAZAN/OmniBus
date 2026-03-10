#!/usr/bin/env python3
"""
OmniBus Dashboard Launcher
==========================
Runs all 3 feeders + dashboard in one command.
User only sees the dashboard, feeders run in background.
Press Ctrl+C to stop everything.
"""

import subprocess
import signal
import sys
import time
import os

# Process handles
processes = []

def cleanup(signum=None, frame=None):
    """Kill all child processes on exit"""
    print("\n⏹  Shutting down OmniBus feeders...")
    for p in processes:
        try:
            p.terminate()
        except:
            pass

    # Wait for graceful shutdown
    time.sleep(0.5)
    for p in processes:
        try:
            p.kill()
        except:
            pass

    print("✓ All feeders stopped.")
    sys.exit(0)

def main():
    """Launch all components"""
    signal.signal(signal.SIGINT, cleanup)
    signal.signal(signal.SIGTERM, cleanup)

    print("╔════════════════════════════════════════╗")
    print("║   OmniBus Real-Time Metrics Dashboard  ║")
    print("╚════════════════════════════════════════╝\n")

    print("🚀 Starting feeders...")

    try:
        # Start Kraken feeder
        p1 = subprocess.Popen(
            [sys.executable, "/home/kiss/OmniBus/kraken_feeder.py", "--file", "--interval", "500"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
        processes.append(p1)
        print("  ✓ Kraken feeder started")
        time.sleep(0.5)

        # Start Coinbase feeder
        p2 = subprocess.Popen(
            [sys.executable, "/home/kiss/OmniBus/coinbase_feeder.py", "--interval", "500"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
        processes.append(p2)
        print("  ✓ Coinbase feeder started")
        time.sleep(0.5)

        # Start LCX Exchange feeder
        p3 = subprocess.Popen(
            [sys.executable, "/home/kiss/OmniBus/lcx_feeder.py", "--interval", "500"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
        processes.append(p3)
        print("  ✓ LCX Exchange feeder started")
        time.sleep(1)

        print("\n📊 Starting dashboard...\n")

        # Start dashboard in foreground (user sees this)
        p4 = subprocess.Popen(
            [sys.executable, "/home/kiss/OmniBus/dashboard_3pane.py"]
        )
        processes.append(p4)

        # Wait for dashboard to finish
        p4.wait()

    except KeyboardInterrupt:
        cleanup()
    except Exception as e:
        print(f"\n❌ Error: {e}")
        cleanup()

if __name__ == '__main__':
    main()
