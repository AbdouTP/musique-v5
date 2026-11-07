#!/usr/bin/env python3
"""Affiche l'UDID du premier simulateur iPhone disponible (utilisé par Codemagic)."""
import json
import subprocess
import sys

raw = subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"])
devices = json.loads(raw)["devices"]

candidates = []
for runtime, items in devices.items():
    if "iOS" not in runtime:
        continue
    for d in items:
        if d.get("isAvailable", True) and d["name"].startswith("iPhone"):
            candidates.append((runtime, d["name"], d["udid"]))

if not candidates:
    sys.exit("Aucun simulateur iPhone disponible")

# Runtime le plus récent, puis nom le plus "grand" (ex. iPhone 17 Pro > iPhone 17).
candidates.sort(key=lambda c: (c[0], c[1]))
print(candidates[-1][2])
