#!/usr/bin/env python3
"""Run the real Swift engine offline; resource layout matches the app bundle."""
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix="klimax-liturgy-") as directory:
    stage = Path(directory)
    for source in (root / "Klimax/LiturgicalData").rglob("*.json"):
        shutil.copy2(source, stage / source.name)
    for name in ["scripture", "koinonika", "kontakia", "prokeimena", "apolytikia"]:
        shutil.copy2(root / "Klimax" / f"{name}.json", stage / f"{name}.json")
    shutil.copy2(root / "tests/liturgical/readings_test_input.json", stage)
    subprocess.run([
        "xcrun", "swiftc", "-module-cache-path", str(stage / "cache"),
        str(root / "Klimax/ScriptureModels.swift"),
        str(root / "Klimax/Paschalion.swift"),
        str(root / "Klimax/LiturgicalServices.swift"),
        str(root / "tests/liturgical/runtime_test.swift"),
        "-o", str(stage / "runtime-test"),
    ], check=True)
    subprocess.run([str(stage / "runtime-test")], check=True)
