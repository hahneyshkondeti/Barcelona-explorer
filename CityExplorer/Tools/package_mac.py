#!/usr/bin/env python3
"""Build and stage an arm64 development app outside macOS Documents metadata.

Run the packaged physics probe and inspect the game before installation. The
staged app is self-contained; its folder may be named City Explorer Unreal.app.
"""
import os
from pathlib import Path
import subprocess
import tempfile

project = Path(__file__).resolve().parents[1]
engine = Path(os.environ.get('UE_ROOT', '/Users/Shared/Epic Games/UE_5.8'))
stage = Path(tempfile.mkdtemp(prefix='CityExplorerStage-'))
env = os.environ.copy()
# Unreal supports this for builds whose app finalization is managed separately.
env['UE_BUILD_FROM_XCODE'] = '1'
subprocess.run([str(engine / 'Engine/Build/BatchFiles/Mac/Build.sh'), 'CityExplorer', 'Mac', 'Development', '-architecture=arm64', f'-Project={project / "CityExplorer.uproject"}'], env=env, check=True)
subprocess.run([str(engine / 'Engine/Build/BatchFiles/RunUAT.sh'), 'BuildCookRun', f'-project={project / "CityExplorer.uproject"}', '-noP4', '-platform=Mac', '-clientconfig=Development', '-architecture=arm64', '-cook', '-stage', '-pak', f'-stagingdirectory={stage}'], check=True)
app = stage / 'Mac/CityExplorer.app'
subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
print(f'Signed standalone app: {app}')
