#!/usr/bin/env python3
"""Validate the installed Mac toolchain and build the existing editor target.

Set DEVELOPER_DIR to a compatible side-by-side Xcode installation if needed.
UE_ROOT may point to a different installation of the same engine version.
"""
import os
from pathlib import Path
import subprocess
import sys

project = Path(__file__).resolve().parents[1]
engine = Path(os.environ.get("UE_ROOT", "/Users/Shared/Epic Games/UE_5.8"))
build = engine / "Engine/Build/BatchFiles/Mac/Build.sh"
logs = project / "Saved/BuildDiagnostics"
logs.mkdir(parents=True, exist_ok=True)
if not build.is_file():
    sys.exit(f"Unreal build tool not found: {build}")
validation = subprocess.run([str(build), "-Mode=ValidatePlatforms", "-Platforms=Mac",
    f"-Log={logs / 'platform.log'}"], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
print(validation.stdout, end="")
if validation.returncode or "##PlatformValidate: Mac VALID" not in validation.stdout:
    sys.exit("Mac toolchain validation failed. Select a compatible full Xcode via DEVELOPER_DIR.")
sys.exit(subprocess.run([str(build), "CityExplorerEditor", "Mac", "Development",
    "-architecture=arm64", f"-Project={project / 'CityExplorer.uproject'}",
    f"-Log={logs / 'editor.log'}"]).returncode)
