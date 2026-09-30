"""Run in Unreal Editor's Python environment to create/configure migration assets.
Existing assets are reused. Source Godot files are read only.
"""
import unreal
from pathlib import Path
assets = unreal.AssetToolsHelpers.get_asset_tools()
root = '/Game/CityExplorer'

def asset(name, folder, cls, factory):
    path = f'{root}/{folder}/{name}'
    existing = unreal.EditorAssetLibrary.load_asset(path) if unreal.EditorAssetLibrary.does_asset_exist(path) else None
    return existing or assets.create_asset(name, f'{root}/{folder}', cls, factory)

def data(name, cls):
    factory = unreal.DataAssetFactory()
    factory.set_editor_property('data_asset_class', cls)
    return asset(name, 'Input', cls, factory)

def blueprint(name, parent, folder):
    factory = unreal.BlueprintFactory()
    factory.set_editor_property('parent_class', unreal.load_class(None, parent))
    return asset(name, folder, unreal.Blueprint, factory)

actions = {}
for name in ['Gas', 'Brake', 'Steer']:
    a = data('IA_' + name, unreal.InputAction)
    a.set_editor_property('value_type', unreal.InputActionValueType.AXIS1D)
    actions[name] = a
context = data('IMC_Driving', unreal.InputMappingContext)
mapping_data = context.get_editor_property('default_key_mappings')
mapping_data.set_editor_property('mappings', [])
context.set_editor_property('default_key_mappings', mapping_data)
for name, keys in [('Gas', ['W', 'Up']), ('Brake', ['S', 'Down', 'SpaceBar']), ('Steer', ['D', 'Right', 'A', 'Left'])]:
    for key in keys:
        input_key = unreal.Key()
        input_key.set_editor_property("key_name", key)
        context.map_key(actions[name], input_key)
mapping_data = context.get_editor_property('default_key_mappings')
mappings = mapping_data.get_editor_property('mappings')
for mapping in mappings:
    if mapping.get_editor_property('key').get_editor_property('key_name') in ['A', 'Left']:
        mapping.set_editor_property('modifiers', [unreal.InputModifierNegate(outer=context)])
mapping_data.set_editor_property('mappings', mappings)
context.set_editor_property('default_key_mappings', mapping_data)
car = blueprint('BP_TouringCar', '/Script/CityExplorer.ExplorerVehicle', 'Vehicles')
car_class = unreal.EditorAssetLibrary.load_blueprint_class(car.get_path_name())
car_default = unreal.get_default_object(car_class)
car_default.set_editor_property('drive_context', context)
for name, prop in [('Gas', 'gas_action'), ('Brake', 'brake_action'), ('Steer', 'steer_action')]:
    car_default.set_editor_property(prop, actions[name])
mode = blueprint('BP_CityExplorerGameMode', '/Script/CityExplorer.ExplorerGameMode', 'Core')
mode_class = unreal.EditorAssetLibrary.load_blueprint_class(mode.get_path_name())
unreal.get_default_object(mode_class).set_editor_property('default_pawn_class', car_class)
material = asset('M_CityVertexColor', 'Materials', unreal.Material, unreal.MaterialFactoryNew())
if not unreal.MaterialEditingLibrary.get_num_material_expressions(material):
    color = unreal.MaterialEditingLibrary.create_material_expression(material, unreal.MaterialExpressionVertexColor)
    unreal.MaterialEditingLibrary.connect_material_property(color, '', unreal.MaterialProperty.MP_BASE_COLOR)
    unreal.MaterialEditingLibrary.recompile_material(material)
level_path = root + '/Maps/Barcelona'
level_system = unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)
if not unreal.EditorAssetLibrary.does_asset_exist(level_path):
    level_system.new_level(level_path)
else:
    level_system.load_level(level_path)
actor_system = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
existing = actor_system.get_all_level_actors()
if not any(isinstance(a, unreal.DirectionalLight) for a in existing):
    sun = actor_system.spawn_actor_from_class(unreal.DirectionalLight, unreal.Vector(0, 0, 10000), unreal.Rotator(-40, -45, 0))
    sun.get_component_by_class(unreal.DirectionalLightComponent).set_editor_property('intensity', 3.0)
if not any(isinstance(a, unreal.SkyLight) for a in existing):
    sky = actor_system.spawn_actor_from_class(unreal.SkyLight, unreal.Vector(0, 0, 0))
    sky.get_component_by_class(unreal.SkyLightComponent).set_editor_property('intensity', 1.0)
if not any(isinstance(a, unreal.SkyAtmosphere) for a in existing):
    actor_system.spawn_actor_from_class(unreal.SkyAtmosphere, unreal.Vector(0, 0, 0))
unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world().get_world_settings().set_editor_property('default_game_mode', mode_class)
level_system.save_current_level()
unreal.EditorAssetLibrary.save_directory(root)
print('CITY_EXPLORER_BOOTSTRAP_SUCCESS')
