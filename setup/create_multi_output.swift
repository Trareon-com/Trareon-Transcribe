// create_multi_output.swift — Opens Audio MIDI Setup with routing instructions.
// This is a SAFE helper that only shows instructions and opens the utility.
// It does NOT create any CoreAudio devices or modify system audio settings.

import Foundation

print("=== Trareon Audio Router ===\n")
print("To capture system audio (YouTube/Zoom/Teams) in the app's SPK channel,")
print("you need a Multi-Output Device. This duplicates audio to both")
print("BlackHole (for capture) and your speakers (so you can hear).\n")
print("Steps (30 seconds, one-time setup):\n")
print("1. Audio MIDI Setup will open now")
print("2. Click + (bottom-left corner) → Create Multi-Output Device")
print("3. Check BOTH boxes:")
print("   ☑ BlackHole 2ch")
print("   ☑ MacBook Pro Speakers")
print("4. Close Audio MIDI Setup")
print("5. Open System Settings → Sound → Output")
print("6. Select \"Multi-Output Device\"\n")
print("Done! Now audio will route through BlackHole (captured by app)")
print("AND your speakers (so you can still hear).\n")

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
task.arguments = ["-b", "com.apple.audio.AudioMIDISetup"]
try? task.run()

print("Audio MIDI Setup launched. Complete steps 2-5 above.")
