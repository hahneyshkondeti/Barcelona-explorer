import unreal
path = '/Game/CityExplorer/Vehicles/TouringCar/TouringCarRigged/SkeletalMeshes/SK_TouringCar_PhysicsAsset'
asset = unreal.load_asset(path)
assert unreal.ExplorerVehicleAssetTools.configure_chassis(asset)
assert unreal.EditorAssetLibrary.save_loaded_asset(asset)
print('CITY_EXPLORER_CHASSIS_CONFIG_SUCCESS')
