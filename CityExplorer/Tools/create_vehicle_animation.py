import unreal
skeleton = unreal.load_asset('/Game/CityExplorer/Vehicles/TouringCar/TouringCarRigged/SkeletalMeshes/SK_TouringCar_Skeleton')
bp = unreal.load_asset('/Game/CityExplorer/Vehicles/ABP_TouringCar') or unreal.ExplorerVehicleAssetTools.create_wheel_animation(skeleton)
assert bp, 'Could not build standard vehicle animation graph'
assert unreal.EditorAssetLibrary.save_loaded_asset(bp)
print('CITY_EXPLORER_ANIMATION_SUCCESS')
