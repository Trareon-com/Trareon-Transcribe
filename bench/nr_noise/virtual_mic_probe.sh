#!/bin/bash
# #69 on Kali without a physical mic: feed FLEURS speech into a virtual PipeWire
# source and run the real capture path (input_probe) against it. Silent (null sink).
set -u
PROBE=${PROBE:-../../rust_core/target/release/input_probe}
SP=${SP:?clean speech wav, e.g. 3 concatenated set/clean files}
NOISY=${NOISY:-set/babble5/00.wav}
ORIG=$(pactl get-default-source)
M1=$(pactl load-module module-null-sink sink_name=tt_probe_feed sink_properties=device.description=tt_probe_feed)
M2=$(pactl load-module module-remap-source master=tt_probe_feed.monitor source_name=tt_probe_mic source_properties=device.description=tt_probe_mic)
pactl set-default-source tt_probe_mic
sleep 1
echo "default_source=$(pactl get-default-source)"
probe() { timeout 20 $PROBE 3000 2>&1 | tail -1; }
for i in 1 2; do echo "senyap#$i  $(probe)"; done
for f in "$SP:bicara-bersih" "$NOISY:bicara+babble5dB"; do
  wav=${f%%:*}; label=${f##*:}
  paplay --device=tt_probe_feed "$wav" &
  P=$!
  sleep 0.5
  echo "$label  $(probe)"
  kill $P 2>/dev/null; wait $P 2>/dev/null
done
pactl set-default-source "$ORIG"
pactl unload-module "$M2"; pactl unload-module "$M1"
echo "restored default_source=$(pactl get-default-source)"
