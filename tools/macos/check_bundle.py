#!/usr/bin/env python3
"""Check the standalone Mac app's metadata, universal binary and packaged data."""
import pathlib, plistlib, subprocess, sys
app=pathlib.Path(sys.argv[1]).resolve()
with (app/'Contents/Info.plist').open('rb') as f: info=plistlib.load(f)
assert info['CFBundleIdentifier']=='com.hahneyshkondeti.cityexplorer.mac'
assert info['CFBundleName']=='City Explorer'
exe=app/'Contents/MacOS'/info['CFBundleExecutable']
arches=subprocess.check_output(['lipo','-archs',str(exe)],text=True)
assert 'arm64' in arches and 'x86_64' in arches
packs=list((app/'Contents/Resources').glob('*.pck'))
assert len(packs)==1 and packs[0].stat().st_size>100_000_000
subprocess.run(['codesign','--verify','--deep','--strict',str(app)],check=True)
print('PASS: standalone City Explorer bundle, universal executable, packaged city, valid local signature')
