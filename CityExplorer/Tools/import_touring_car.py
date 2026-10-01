import unreal
from pathlib import Path
source = Path(unreal.Paths.project_dir()) / 'SourceAssets' / 'TouringCarRigged.glb'
task = unreal.AssetImportTask()
task.set_editor_property('filename', str(source.resolve()))
task.set_editor_property('destination_path', '/Game/CityExplorer/Vehicles/TouringCar')
task.set_editor_property('destination_name', 'SK_TouringCar')
task.set_editor_property('automated', True)
task.set_editor_property('replace_existing', True)
task.set_editor_property('save', True)
unreal.AssetToolsHelpers.get_asset_tools().import_asset_tasks([task])
paths = task.get_editor_property('imported_object_paths')
for path in paths:
    obj = unreal.load_asset(path)
    print('TOURING_CAR_IMPORTED', path, obj.get_class().get_name())
unreal.EditorAssetLibrary.save_directory('/Game/CityExplorer/Vehicles/TouringCar')
assert any(isinstance(unreal.load_asset(p), unreal.SkeletalMesh) for p in paths), 'Rig did not import as a SkeletalMesh'
print('CITY_EXPLORER_RIG_IMPORT_SUCCESS')
