## Owns the panorama-sky background style and applies it to every registered
## [PanoramaSkyMaterial]. Scenes register their sky material on entry so the
## user's preference takes effect without per-scene wiring.
extends Node

const TEX_GRADIENT: Texture2D = preload("res://textures/grad1.png")
const TEX_CLOUDS:   Texture2D = preload("res://textures/sky_19_2k.png")

const BG_GRADIENT := "gradient"
const BG_CLOUDS := "clouds"

var background_style: String = BG_GRADIENT

var _sky_materials: Array[PanoramaSkyMaterial] = []


func _ready() -> void:
	background_style = SettingsStore.get_value(
		"visuals", "background_style", background_style)


## Register a sky material so it tracks [member background_style] changes.
## Scenes call this in their [method Node._ready].
func register_sky_material(m: PanoramaSkyMaterial) -> void:
	if m and not _sky_materials.has(m):
		_sky_materials.append(m)


## Push the current style's texture to all registered sky materials.
func apply() -> void:
	var tex: Texture2D = TEX_CLOUDS if background_style == BG_CLOUDS else TEX_GRADIENT
	for m in _sky_materials:
		if m:
			m.panorama = tex


## Persist the current preference to [SettingsStore].
func save() -> void:
	SettingsStore.set_value("visuals", "background_style", background_style)
	SettingsStore.save()
