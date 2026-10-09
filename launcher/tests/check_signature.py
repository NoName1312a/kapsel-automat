"""Prüft, ob eine Windows-.exe eine Authenticode-Signatur enthält (Sicherheitsverzeichnis im PE-Kopf).
Aufruf: python3 check_signature.py KapselLauncher.exe"""
import re, struct, sys

data = open(sys.argv[1], "rb").read()
pe = struct.unpack_from("<I", data, 0x3C)[0]
magic = struct.unpack_from("<H", data, pe + 24)[0]
off = pe + 24 + (112 if magic == 0x20B else 96) + 4 * 8
va, size = struct.unpack_from("<II", data, off)
if size == 0 or va + size > len(data):
    sys.exit("Keine Signatur in %s" % sys.argv[1])
names = sorted(set(m.decode() for m in re.findall(rb"Godot Foundation|Sectigo[ \w]*", data[va:va + size])))
print("Signatur gefunden (%d Bytes): %s" % (size, ", ".join(names)))
