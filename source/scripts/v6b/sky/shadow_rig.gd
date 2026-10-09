class_name ShadowRig
extends RefCounted
## v6b "shadows" module: realistic sun shadows. Desktop (High): 4 blended
## cascades out to ~90 m, tighter near splits, a soft penumbra (angular
## size of the sun + PCF blur). Web (High): 2 cascades to 45 m with a light
## blur - cheap on the Compatibility renderer. Low / Off stay as before.
## Called from SettingsPanel._apply_shadows (and at start).


static func style() -> ShadowStyle:
	return Modules.style("shadows") as ShadowStyle


static func apply(sun: DirectionalLight3D, level: int) -> void:
	var st := style()
	if sun == null or st == null or level != 0:
		return
	if OS.has_feature("web"):
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_max_distance = st.web_distance
		sun.directional_shadow_split_1 = 0.25
		sun.shadow_blur = st.web_blur
		sun.directional_shadow_blend_splits = false
		return
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = st.desktop_distance
	sun.directional_shadow_split_1 = st.desktop_splits.x
	sun.directional_shadow_split_2 = st.desktop_splits.y
	sun.directional_shadow_split_3 = st.desktop_splits.z
	sun.directional_shadow_blend_splits = st.blend_splits
	sun.directional_shadow_fade_start = st.fade_start
	sun.light_angular_distance = st.desktop_angular
	sun.shadow_blur = st.desktop_blur
