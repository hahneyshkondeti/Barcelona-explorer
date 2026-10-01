"""Repair only steering mappings; run with Unreal's Python commandlet."""
import unreal

context = unreal.load_asset('/Game/CityExplorer/Input/IMC_Driving')
assert context, 'Driving input context is missing'
data = context.get_editor_property('default_key_mappings')
mappings = data.get_editor_property('mappings')
seen = set()
for index, mapping in enumerate(mappings):
    key = str(mapping.get_editor_property('key').get_editor_property('key_name'))
    if key not in ('A', 'Left', 'D', 'Right'):
        continue
    assert mapping.get_editor_property('action').get_name() == 'IA_Steer'
    modifiers = [m for m in mapping.get_editor_property('modifiers') if not isinstance(m, unreal.InputModifierNegate)]
    if key in ('A', 'Left'):
        negate = unreal.InputModifierNegate(outer=context)
        negate.set_editor_property('x', True)
        modifiers.append(negate)
    mapping.set_editor_property('modifiers', modifiers)
    mappings[index] = mapping
    seen.add(key)
assert seen == {'A', 'Left', 'D', 'Right'}
data.set_editor_property('mappings', mappings)
context.set_editor_property('default_key_mappings', data)
assert unreal.EditorAssetLibrary.save_loaded_asset(context, only_if_is_dirty=False)
# Verify the saved mapping values: keyboard axis +1 is negated only for left.
for mapping in context.get_editor_property('default_key_mappings').get_editor_property('mappings'):
    key = str(mapping.get_editor_property('key').get_editor_property('key_name'))
    if key in seen:
        negative = any(isinstance(m, unreal.InputModifierNegate) and m.get_editor_property('x') for m in mapping.get_editor_property('modifiers'))
        assert negative == (key in ('A', 'Left')), key
        unreal.log('CITY_STEERING_MAPPING %s=%s' % (key, -1 if negative else 1))
unreal.log('CITY_STEERING_REPAIR_SUCCESS')
