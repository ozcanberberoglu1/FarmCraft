class_name VehicleTable
extends RefCounted
## Vehicles: the dealership's, and Grandpa's old pickup that comes with the farm. An
## entry with "base" takes every key of that entry it doesn't set itself. Model
## positions are in the model's own frame (front along +X, left along -Z, ground at
## y = 0); Vehicle turns it to face +Z.

const VEHICLES := {
	&"pickup_90": {
		"name_key": "VEHICLE_PICKUP_90",
		"desc_key": "VEHICLE_PICKUP_90_DESC",
		"model": "res://art/models/vehicles/pickup_90/scene.gltf",
		## Modelled tyres, rims, brakes and steering wheel that replace the model's own
		## (tools/build_pickup_hd.py, VehicleLook.add_detail).
		"detail": "res://art/models/vehicles/pickup_90/hd_parts.glb",
		"price": 550,
		## vehicle_paint.gdshader parameters (the rest keep the shader's defaults): a
		## metallic navy under a deep clear coat, only road dust low down.
		"paint": {"paint": Color(0.07, 0.12, 0.26), "metallic": 0.5, "roughness": 0.36, "clearcoat": 1.0,
			"clearcoat_roughness": 0.035, "wear": 0.22},
		## vehicle_trim.gdshader (bumpers, bull bar, underbody) and vehicle_wheel.gdshader.
		"trim": {"wear": 0.25},
		"wheel": {"wear": 0.08, "rubber": Color(0.14, 0.14, 0.14)},
		## Number plate drawn over the model's own (tools/make_vehicle_plates.py).
		"plate": "res://art/models/vehicles/plates/pickup_90.png",
		## Windows (vehicle_glass.gdshader) and lamp lenses: clean, a trace of dust.
		"glass": {"grime": 0.1, "panes": ["Windshield", "Glass_Rear", "Glass_Driver", "Glass_Passenger"],
			"covers": ["Headlights_Glass", "Taillights_Glass"]},
		"mass": 1450.0,
		"engine_force": 4300.0,
		"reverse_force": 2600.0,
		"brake_force": 85.0,
		"max_speed": 70.0,
		"max_reverse": 22.0,
		"steer_deg": 34.0,
		## Per wheel. VehicleWheel3D scales spring and damper forces by the chassis
		## mass: ride frequency is sqrt(stiffness) / pi Hz and the damping ratio about
		## damping / sqrt(stiffness) (0.35 bump, 0.45 rebound here). anti_roll: bar
		## rate per axle as a share of one spring.
		"suspension": {"stiffness": 36.0, "compression": 2.1, "relaxation": 2.7, "travel": 0.22, "rest": 0.2,
			"max_force": 24000.0, "roll_influence": 0.05, "anti_roll": 0.3},
		## Centre of mass above the ground (kept low: see Vehicle._ready).
		"com_height": 0.32,
		"fuel_capacity": 45.0,
		## Litres per kilometre at full throttle (it is a thirsty old truck).
		"fuel_per_km": 0.6,
		"cargo_units": 160,
		"wheels": {"fl": "WheelStock_FL", "fr": "WheelStock_FR", "rl": "WheelStock_RL", "rr": "WheelStock_RR"},
		"steering_wheel": "Steering_Wheel",
		"headlights": "Headlights_UCB",
		"brakelights": "Brakelights",
		"reverselights": "Reverse_UCB",
		## Driver's eyes, model frame.
		"eyes": Vector3(0.42, 1.52, -0.38),
		## Chassis collision boxes, model frame: [center, size].
		"boxes": [[Vector3(0.13, 0.8, 0.0), Vector3(5.3, 0.66, 1.94)], [Vector3(0.85, 1.36, 0.0), Vector3(1.45, 0.6, 1.76)]],
		## The model comes with a load baked into its bed trim: loose parts of that mesh
		## lying wholly inside this box are cut away.
		"strip_parts": ["Truckbed_Trim", AABB(Vector3(-2.25, 0.6, -0.83), Vector3(2.3, 0.8, 1.66))],
		## Bed interior (measured): slot row edges from the cab to the tailgate, column
		## edges across, floor and rail heights, wheel wells (packages ride on top).
		"bed_rows": [0.06, -0.52, -1.1, -1.68, -2.2],
		"bed_cols": [-0.8, -0.4, 0.0, 0.4, 0.8],
		"bed_floor": 0.67,
		"bed_top": 1.23,
		"bed_center": Vector3(-1.07, 0.9, 0.0),
		"wheel_wells": [AABB(Vector3(-1.68, 0.67, -0.8), Vector3(0.9, 0.3, 0.4)), AABB(Vector3(-1.68, 0.67, 0.4), Vector3(0.9, 0.3, 0.4))],
		## Interaction box around the bed and tailgate; wraps the rear of the body box.
		"bed_zone": AABB(Vector3(-2.62, 0.4, -1.02), Vector3(2.72, 1.05, 2.04)),
		"colors": [Color(0.55, 0.16, 0.12), Color(0.16, 0.28, 0.42), Color(0.72, 0.7, 0.64), Color(0.2, 0.32, 0.2)],
	},
	## Grandpa's pickup: the same truck thirty years and a lot of weather later. It
	## comes with the farm (not sold at the dealership): a tired engine, soft brakes, a
	## thirstier carburettor, the same steel bed.
	&"pickup_old": {
		"base": &"pickup_90",
		"name_key": "VEHICLE_PICKUP_OLD",
		"desc_key": "VEHICLE_PICKUP_OLD_DESC",
		"price": 0,
		"mass": 1500.0,
		"engine_force": 3500.0,
		"reverse_force": 2200.0,
		"brake_force": 70.0,
		"max_speed": 60.0,
		"max_reverse": 18.0,
		"steer_deg": 32.0,
		"fuel_capacity": 40.0,
		"fuel_per_km": 0.8,
		## Once sage green, now chalky where the sun hits it, rust through the sills and
		## wheel arches, dust and grime streaks down the doors.
		"paint": {"paint": Color(0.21, 0.31, 0.25), "fade": 0.62, "rust": 0.68, "streaks": 0.7, "wear": 0.9,
			"roughness": 0.52, "metallic": 0.08, "clearcoat": 0.25, "clearcoat_roughness": 0.22,
			"dirt_color": Color(0.45, 0.38, 0.29)},
		## Bumpers, bull bar, underbody and bed trim: hazy, pitted chrome and steel
		## rusting from the lower edges. Steel wheels in old cream paint gone grey with
		## brake dust, rust round the nuts; tyres faded with age, dust caked on the tread.
		"trim": {"wear": 0.9, "rust": 0.55, "chrome_dull": 0.35, "tint": Color(0.92, 0.9, 0.86)},
		"wheel": {"wear": 0.85, "rim_paint": 1.0, "rim_color": Color(0.58, 0.56, 0.5), "rust": 0.5,
			"rubber": Color(0.18, 0.175, 0.17)},
		## Windows (vehicle_glass.gdshader): a film of dust, thickest along the seals,
		## wiped in two arcs on the windshield, which also carries a stone chip low on
		## the passenger side with a crack running up from it (crack_at: pane fraction
		## from the left edge and the bottom). Lamp covers go yellow and hazy.
		"glass": {"grime": 0.8, "clarity_loss": 0.3, "panes": ["Windshield", "Glass_Rear", "Glass_Driver", "Glass_Passenger"],
			"wiped": "Windshield", "cracked": "Windshield", "crack_at": Vector2(0.8, 0.3),
			"covers": ["Headlights_Glass", "Taillights_Glass"], "cover_tint": Color(0.93, 0.85, 0.66),
			"cover_haze": 0.3},
		"plate": "res://art/models/vehicles/plates/pickup_old.png",
		## Old sealed-beam headlamps: warmer and weaker.
		"lamp_color": Color(1.0, 0.84, 0.6),
		"lamp_energy": 0.75,
		## Engine loop pitch at idle (Audio; the dealer's truck idles at 0.62).
		"engine_pitch": 0.54,
	},
}


static func get_info(id: StringName) -> Dictionary:
	var info: Dictionary = VEHICLES.get(id, {})
	if info.has("base"):
		return get_info(info["base"]).merged(info, true)
	return info
