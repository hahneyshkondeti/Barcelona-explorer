#!/usr/bin/env python3
"""Validate the actual exported app before accepting a CI artifact."""
import json
from pathlib import Path
import plistlib
import sys

project, app = map(Path, sys.argv[1:])
info = plistlib.loads((app / "Info.plist").read_bytes())
assert info["CFBundleIdentifier"] == "com.hahneyshkondeti.brisa"
assert info["UIDeviceFamily"] == [1], "Expected iPhone-only target"
assert float(info["MinimumOSVersion"]) >= 16
assert all("Landscape" in item for item in info["UISupportedInterfaceOrientations"])
assert (app / "Brisa.pck").stat().st_size > 100_000_000
privacy_files = list(app.rglob("PrivacyInfo.xcprivacy"))
assert privacy_files, "Missing privacy manifest"
for path in privacy_files:
    privacy = plistlib.loads(path.read_bytes())
    assert not privacy.get("NSPrivacyTracking", False)
    assert not privacy.get("NSPrivacyCollectedDataTypes", [])
icons = list(project.rglob("*1024*.png"))
assert icons, "Missing App Store icon"
print(json.dumps({"bundle": info["CFBundleIdentifier"], "build": info["CFBundleVersion"], "minimum_ios": info["MinimumOSVersion"], "privacy_manifests": len(privacy_files)}, indent=2))
