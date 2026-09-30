"""Stage the preserved engine-neutral map data for Unreal cooking."""
from pathlib import Path
import shutil
project = Path(__file__).resolve().parents[1]
repo = project.parent
output = project / 'Content/CityExplorer/Data/Offline'
output.mkdir(parents=True, exist_ok=True)
for folder in ['city', 'terrain', 'lighting']:
    shutil.copytree(repo / 'data' / folder, output / folder, dirs_exist_ok=True)
for source, name in [(repo/'data/LICENSE.md', 'DATA_LICENSE.md'), (repo/'ASSET_LICENSES.md', 'ASSET_LICENSES.md')]:
    shutil.copy2(source, output / name)
print(f'Offline map data staged in {output}')
