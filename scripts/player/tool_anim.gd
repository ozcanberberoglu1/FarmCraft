class_name ToolAnim
extends RefCounted
## First-person tool strokes: keyframes for the held item (anticipation, hang, strike,
## impact hold, follow-through, recovery) and the cue timeline a hold-to-use action runs
## on the player's action clock. The gameplay effect, its sound, particles and the camera
## kick all land on the impact cue; the rest of the action's duration is a committed
## follow-through, so every action keeps its length and pace.
##
## Keys: [u, position offset (m, camera space), rotation offset (deg: pitch X, yaw Y,
## roll Z, about the hand, in the stroke's swing frame), trans, ease]. u runs 0..1 over
## one stroke; a segment eases with the trans/ease of the key it ends on, turning along
## the shortest arc between the keys' rotations.
## Signs: +X pitch tips the tool's head back over the shoulder, -X forward and down (the
## watering can's spout down); -Y yaw turns the head to the right.
## "axis" (Euler degrees, camera space) is the swing frame the key rotations turn in: the
## long tools are held with their head in its YZ plane (HeldPoses), so a stroke of pure
## pitch keeps the blade, the pick's point or the hoe's edge leading all the way into the
## target; the scythe's frame is tipped back like the ground under a lowered gaze, so its
## yaw sweeps the blade flat over the grass.
## Profile fields: "impact" (u of contact: the pose is latched there and a hit cue fires),
## "final" (u of the effect when it is not the impact), "whoosh" (a swoosh just before
## contact), "kick" (camera punch: pitch, yaw, roll in degrees and a dip in metres),
## "trauma" (camera shake 0..1), "pour" (u range the can pours), "drips" (cosmetic hits
## while pouring) and "release" (u the hand lets seeds, feed or fertilizer go).

## The contact pose is held about this long (baked into the keys); targets react after it.
const HIT_STOP := 0.06
## The swoosh starts this long before contact (its peak lands just before the hit).
const WHOOSH_LEAD := 0.14
## Seconds thrown seeds fly from the packet to the soil.
const SEED_FLIGHT := 0.38
## Length of one push of the profiles that repeat (milking, brushing...).
const WORK_STROKE := 0.5
const DEG := PI / 180.0

const PROFILES := {
	# Wound up over the right shoulder, a hang, then a fast diagonal fall that drives the
	# bit into the trunk.
	&"axe": {"impact": 0.58, "whoosh": true, "axis": Vector3(0, 40, -12), "kick": Vector4(-1.6, 0.4, -0.8, -0.02), "trauma": 0.45, "keys": [
		[0.0, Vector3.ZERO, Vector3.ZERO],
		[0.38, Vector3(0.1, 0.26, 0.0), Vector3(40, 0, 0), Tween.TRANS_CUBIC, Tween.EASE_OUT],
		[0.46, Vector3(0.11, 0.27, 0.01), Vector3(45, 0, 0), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.58, Vector3(-0.15, 0.15, -0.12), Vector3(-22, 0, 0), Tween.TRANS_EXPO, Tween.EASE_IN],
		[0.67, Vector3(-0.15, 0.145, -0.115), Vector3(-21, 0, 0), Tween.TRANS_LINEAR, Tween.EASE_IN],
		[0.76, Vector3(-0.09, 0.08, -0.07), Vector3(-12, 0, 0), Tween.TRANS_BACK, Tween.EASE_OUT],
		[1.0, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_SINE, Tween.EASE_IN_OUT]]},
	# Raised over the right shoulder, brought down point first onto the stone, and a
	# rebound off it.
	&"pickaxe": {"impact": 0.6, "whoosh": true, "axis": Vector3(0, 40, -8), "kick": Vector4(-2.0, 0.0, 0.6, -0.03), "trauma": 0.4, "keys": [
		[0.0, Vector3.ZERO, Vector3.ZERO],
		[0.4, Vector3(0.08, 0.27, 0.04), Vector3(44, 0, 0), Tween.TRANS_CUBIC, Tween.EASE_OUT],
		[0.47, Vector3(0.08, 0.29, 0.05), Vector3(49, 0, 0), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.6, Vector3(-0.12, 0.16, -0.1), Vector3(-32, 0, 0), Tween.TRANS_EXPO, Tween.EASE_IN],
		[0.66, Vector3(-0.12, 0.17, -0.09), Vector3(-29, 0, 0), Tween.TRANS_LINEAR, Tween.EASE_IN],
		[0.76, Vector3(-0.07, 0.12, -0.04), Vector3(-10, 0, 0), Tween.TRANS_BACK, Tween.EASE_OUT],
		[1.0, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_SINE, Tween.EASE_IN_OUT]]},
	# Lifted, chopped blade first into the soil, then dragged back toward the feet.
	&"hoe": {"impact": 0.6, "whoosh": true, "axis": Vector3(0, 34, -6), "kick": Vector4(-1.0, 0.0, 0.4, -0.02), "trauma": 0.12, "keys": [
		[0.0, Vector3.ZERO, Vector3.ZERO],
		[0.4, Vector3(0.06, 0.14, 0.0), Vector3(30, 0, 0), Tween.TRANS_CUBIC, Tween.EASE_OUT],
		[0.48, Vector3(0.06, 0.15, 0.0), Vector3(34, 0, 0), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.6, Vector3(-0.14, 0.1, -0.14), Vector3(-14, 0, 0), Tween.TRANS_EXPO, Tween.EASE_IN],
		[0.66, Vector3(-0.14, 0.09, -0.15), Vector3(-17, 0, 0), Tween.TRANS_LINEAR, Tween.EASE_IN],
		[0.82, Vector3(-0.14, 0.02, -0.03), Vector3(-12, 0, 0), Tween.TRANS_SINE, Tween.EASE_OUT],
		[1.0, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_SINE, Tween.EASE_IN_OUT]]},
	# The blade drawn back to the right, then one wide flat sweep to the left, pulled in
	# toward the body; it cuts mid-arc.
	&"scythe": {"impact": 0.52, "whoosh": true, "axis": Vector3(30, 0, 0), "kick": Vector4(0.0, 0.9, 0.6, 0.0), "trauma": 0.0, "keys": [
		[0.0, Vector3.ZERO, Vector3.ZERO],
		[0.36, Vector3(0.1, 0.05, 0.06), Vector3(0, -44, -4), Tween.TRANS_CUBIC, Tween.EASE_OUT],
		[0.42, Vector3(0.11, 0.05, 0.07), Vector3(0, -47, -4), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.62, Vector3(-0.1, 0.04, 0.06), Vector3(0, 38, 2), Tween.TRANS_QUART, Tween.EASE_IN_OUT],
		[0.72, Vector3(-0.11, 0.05, 0.07), Vector3(0, 42, 4), Tween.TRANS_SINE, Tween.EASE_OUT],
		[1.0, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_SINE, Tween.EASE_IN_OUT]]},
	# Tipped forward about the handle until the spout points ahead toward the aim, held
	# there while it pours.
	&"can_pour": {"final": 0.78, "pour": Vector2(0.22, 0.8), "drips": [0.35, 0.5, 0.65], "wobble": true, "keys": [
		[0.0, Vector3.ZERO, Vector3.ZERO],
		[0.22, Vector3(-0.08, 0.0, -0.14), Vector3(-32, -14, 12), Tween.TRANS_CUBIC, Tween.EASE_OUT],
		[0.3, Vector3(-0.08, 0.0, -0.14), Vector3(-35, -14, 13), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.8, Vector3(-0.08, 0.0, -0.14), Vector3(-32, -14, 12), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[1.0, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_SINE, Tween.EASE_IN_OUT]]},
	# Dipped into the well or pond and brought back up full.
	&"can_dip": {"final": 0.72, "keys": [
		[0.0, Vector3.ZERO, Vector3.ZERO],
		[0.35, Vector3(-0.05, -0.18, -0.1), Vector3(-22, 0, 4), Tween.TRANS_CUBIC, Tween.EASE_IN_OUT],
		[0.52, Vector3(-0.05, -0.21, -0.1), Vector3(-26, 0, 5), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.7, Vector3(-0.05, -0.17, -0.1), Vector3(-18, 0, 3), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[1.0, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_BACK, Tween.EASE_OUT]]},
	# The packet drawn in, flicked out in an arc (the seeds fly), then shaken empty.
	&"scatter": {"release": 0.4, "final": 0.82, "keys": [
		[0.0, Vector3.ZERO, Vector3.ZERO],
		[0.3, Vector3(0.06, 0.02, 0.06), Vector3(10, -25, -20), Tween.TRANS_SINE, Tween.EASE_OUT],
		[0.42, Vector3(-0.1, 0.05, -0.12), Vector3(-28, 32, 26), Tween.TRANS_EXPO, Tween.EASE_OUT],
		[0.52, Vector3(-0.1, 0.03, -0.11), Vector3(-20, 28, 18), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.6, Vector3(-0.1, 0.04, -0.12), Vector3(-26, 30, 24), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[1.0, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_SINE, Tween.EASE_IN_OUT]]},
	# A bag or armful swung forward and tipped out (fertilizer, manure, hay into a trough).
	&"sack": {"release": 0.48, "final": 0.75, "keys": [
		[0.0, Vector3.ZERO, Vector3.ZERO],
		[0.35, Vector3(0.02, 0.08, 0.08), Vector3(12, -10, -8), Tween.TRANS_SINE, Tween.EASE_OUT],
		[0.5, Vector3(-0.06, 0.0, -0.16), Vector3(-22, 14, 10), Tween.TRANS_CUBIC, Tween.EASE_IN],
		[0.62, Vector3(-0.05, 0.01, -0.14), Vector3(-18, 12, 8), Tween.TRANS_SINE, Tween.EASE_OUT],
		[1.0, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_SINE, Tween.EASE_IN_OUT]]},
	# The fork stabbed into the heap, then a forkful lifted and tossed over the shoulder.
	&"fork": {"impact": 0.45, "final": 0.76, "whoosh": true, "kick": Vector4(-0.8, 0.0, 0.0, -0.015), "trauma": 0.0, "keys": [
		[0.0, Vector3.ZERO, Vector3.ZERO],
		[0.3, Vector3(0.0, 0.06, 0.12), Vector3(18, 0, 0), Tween.TRANS_SINE, Tween.EASE_OUT],
		[0.45, Vector3(0.0, -0.08, -0.22), Vector3(-30, 0, 0), Tween.TRANS_EXPO, Tween.EASE_IN],
		[0.52, Vector3(0.0, -0.08, -0.22), Vector3(-30, 0, 0), Tween.TRANS_LINEAR, Tween.EASE_IN],
		[0.78, Vector3(-0.08, 0.14, -0.1), Vector3(25, 20, -15), Tween.TRANS_BACK, Tween.EASE_OUT],
		[1.0, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_SINE, Tween.EASE_IN_OUT]]},
	# Side-to-side strokes (brushing, shearing).
	&"brush": {"impact": 0.5, "keys": [
		[0.0, Vector3.ZERO, Vector3.ZERO],
		[0.25, Vector3(0.05, 0.01, -0.05), Vector3(0, -10, -6), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.75, Vector3(-0.07, -0.01, -0.07), Vector3(-4, 14, 8), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[1.0, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_SINE, Tween.EASE_IN_OUT]]},
	# Drawn back by the ear, then flung forward and down (an egg thrown); lets go at "release".
	&"throw": {"release": 0.46, "keys": [
		[0.0, Vector3.ZERO, Vector3.ZERO],
		[0.32, Vector3(0.06, 0.12, 0.14), Vector3(38, -12, -10), Tween.TRANS_SINE, Tween.EASE_OUT],
		[0.46, Vector3(-0.04, 0.02, -0.2), Vector3(-34, 8, 6), Tween.TRANS_EXPO, Tween.EASE_IN],
		[0.6, Vector3(-0.05, -0.04, -0.18), Vector3(-40, 10, 8), Tween.TRANS_SINE, Tween.EASE_OUT],
		[1.0, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_SINE, Tween.EASE_IN_OUT]]},
	# Food brought up to the mouth, two bites, back down (Eating: RMB with food in hand).
	&"eat": {"keys": [
		[0.0, Vector3.ZERO, Vector3.ZERO],
		[0.3, Vector3(-0.26, 0.13, 0.26), Vector3(18, 24, 8), Tween.TRANS_CUBIC, Tween.EASE_OUT],
		[0.38, Vector3(-0.25, 0.115, 0.285), Vector3(10, 24, 8), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.5, Vector3(-0.26, 0.13, 0.25), Vector3(18, 24, 8), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.6, Vector3(-0.25, 0.115, 0.285), Vector3(10, 24, 8), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.72, Vector3(-0.22, 0.09, 0.22), Vector3(12, 20, 6), Tween.TRANS_SINE, Tween.EASE_OUT],
		[1.0, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_SINE, Tween.EASE_IN_OUT]]},
	# The fishing rod (Angler drives these through HeldItem.debug_pose, u from its own
	# clock). Every profile starts where the one before it ends: rest -> cast -> wait/bite
	# (the rod lowered toward the float, "F") -> strike or retrieve -> rest.
	# Cast: drawn back over the shoulder while the power builds (u 0..0.55, held), a hang,
	# then a whip forward that lets the float go at "release" and settles at F.
	&"rod_cast": {"release": 0.7, "keys": [
		[0.0, Vector3.ZERO, Vector3.ZERO],
		[0.3, Vector3(0.03, 0.1, 0.08), Vector3(58, 0, 4), Tween.TRANS_CUBIC, Tween.EASE_OUT],
		[0.55, Vector3(0.04, 0.12, 0.1), Vector3(66, 0, 6), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.6, Vector3(0.04, 0.125, 0.105), Vector3(68, 0, 6), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.72, Vector3(-0.02, 0.0, -0.12), Vector3(-30, 0, -2), Tween.TRANS_EXPO, Tween.EASE_IN],
		[0.86, Vector3(0.0, -0.03, -0.08), Vector3(-17, 0, 0), Tween.TRANS_BACK, Tween.EASE_OUT],
		[1.0, Vector3(0.0, -0.03, -0.08), Vector3(-18, 0, 0), Tween.TRANS_SINE, Tween.EASE_IN_OUT]]},
	# Waiting at F, the tip breathing a little (looped).
	&"rod_wait": {"keys": [
		[0.0, Vector3(0.0, -0.03, -0.08), Vector3(-18, 0, 0)],
		[0.5, Vector3(0.0, -0.025, -0.08), Vector3(-15.5, 0, 0.6), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[1.0, Vector3(0.0, -0.03, -0.08), Vector3(-18, 0, 0), Tween.TRANS_SINE, Tween.EASE_IN_OUT]]},
	# A fish on: the tip yanked down in jerks (looped over the bite).
	&"rod_bite": {"keys": [
		[0.0, Vector3(0.0, -0.03, -0.08), Vector3(-18, 0, 0)],
		[0.18, Vector3(0.0, -0.06, -0.11), Vector3(-31, 2, -2), Tween.TRANS_EXPO, Tween.EASE_OUT],
		[0.45, Vector3(0.0, -0.035, -0.085), Vector3(-20, -1, 1), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.6, Vector3(0.0, -0.055, -0.1), Vector3(-28, -2, 2), Tween.TRANS_EXPO, Tween.EASE_OUT],
		[1.0, Vector3(0.0, -0.03, -0.08), Vector3(-18, 0, 0), Tween.TRANS_SINE, Tween.EASE_IN_OUT]]},
	# The strike: the rod swept up hard, held as the fish comes out, then brought home.
	&"rod_strike": {"keys": [
		[0.0, Vector3(0.0, -0.03, -0.08), Vector3(-18, 0, 0)],
		[0.18, Vector3(0.03, 0.1, 0.06), Vector3(40, 0, 5), Tween.TRANS_EXPO, Tween.EASE_OUT],
		[0.6, Vector3(0.03, 0.09, 0.05), Vector3(34, 0, 4), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[1.0, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_SINE, Tween.EASE_IN_OUT]]},
	# Reeling in an empty line: lifted a little from F, the hand turning the crank (small
	# rolls), then home to rest.
	&"rod_retrieve": {"keys": [
		[0.0, Vector3(0.0, -0.03, -0.08), Vector3(-18, 0, 0)],
		[0.12, Vector3(0.0, -0.02, -0.06), Vector3(-8, 0, 0), Tween.TRANS_CUBIC, Tween.EASE_OUT],
		[0.25, Vector3(0.004, -0.018, -0.06), Vector3(-7, 0, 2.5), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.38, Vector3(-0.004, -0.022, -0.06), Vector3(-9, 0, -2.5), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.51, Vector3(0.004, -0.018, -0.06), Vector3(-7, 0, 2.5), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.64, Vector3(-0.004, -0.022, -0.06), Vector3(-9, 0, -2.5), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.77, Vector3(0.004, -0.018, -0.06), Vector3(-7, 0, 2.5), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[1.0, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_SINE, Tween.EASE_IN_OUT]]},
	# A sapling set into the ground by hand, nothing struck: the hand reaches out to the
	# spot under the aim in one easy move (forward along the lowered gaze is down to the
	# ground), straightening the sapling as it goes, lowers its root ball into the soil
	# (it is planted at "final"), then firms the earth round it with one soft pat (the
	# "impact", after it) and comes back. Every move eases in and out; the head only nods.
	&"set_down": {"final": 0.64, "impact": 0.84, "kick": Vector4(-0.3, 0.0, 0.0, -0.012), "trauma": 0.0, "keys": [
		[0.0, Vector3.ZERO, Vector3.ZERO],
		[0.42, Vector3(-0.2, 0.15, -0.34), Vector3(14, 4, -3), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.64, Vector3(-0.23, 0.1, -0.42), Vector3(24, 4, -5), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.75, Vector3(-0.22, 0.12, -0.4), Vector3(22, 4, -5), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[0.84, Vector3(-0.23, 0.1, -0.42), Vector3(24, 4, -5), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[1.0, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_SINE, Tween.EASE_IN_OUT]]},
	# The knife: drawn back a hand's width, then a fast straight stab ahead along the blade,
	# a hold at full reach, and back (Combat: LMB with the knife in hand).
	&"stab": {"impact": 0.4, "whoosh": true, "kick": Vector4(-0.5, 0.0, 0.3, -0.004), "trauma": 0.0, "keys": [
		[0.0, Vector3.ZERO, Vector3.ZERO],
		[0.22, Vector3(0.03, -0.015, 0.08), Vector3(10, -6, 4), Tween.TRANS_SINE, Tween.EASE_OUT],
		[0.4, Vector3(-0.07, 0.045, -0.24), Vector3(-6, 10, -6), Tween.TRANS_EXPO, Tween.EASE_IN],
		[0.5, Vector3(-0.072, 0.046, -0.245), Vector3(-7, 10, -6), Tween.TRANS_LINEAR, Tween.EASE_IN],
		[1.0, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_SINE, Tween.EASE_IN_OUT]]},
	# A short push forward and back (milking, feeding, medicine, anything else).
	&"work": {"impact": 0.5, "keys": [
		[0.0, Vector3.ZERO, Vector3.ZERO],
		[0.5, Vector3(-0.03, 0.01, -0.07), Vector3(-8, 0, 4), Tween.TRANS_SINE, Tween.EASE_IN_OUT],
		[1.0, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_SINE, Tween.EASE_IN_OUT]]},
}
## Action id -> [profile, strokes]. Profile &"" is the tool's own (TOOL_PROFILES);
## 0 strokes is one WORK_STROKE push per half second. Unlisted actions: [&"work", 0].
const ACTIONS := {
	"hoe": [&"hoe", 2], "clear": [&"", 1], "chop": [&"axe", 1], "break": [&"pickaxe", 1],
	"cut": [&"scythe", 1], "harvest": [&"scythe", 1], "water": [&"can_pour", 1], "fill_water": [&"can_pour", 1],
	"refill": [&"can_dip", 1], "plant": [&"scatter", 1], "fertilize": [&"sack", 1], "fill_feed": [&"sack", 1],
	"muck": [&"fork", 1], "brush": [&"brush", 0], "shear": [&"brush", 0], "douse": [&"can_pour", 1],
	"plant_sapling": [&"set_down", 1],
}
## A tool's own stroke (clearing a bed, swinging at nothing).
const TOOL_PROFILES := {&"axe": &"axe", &"pickaxe": &"pickaxe", &"hoe": &"hoe", &"scythe": &"scythe", &"pitchfork": &"fork"}
## Seconds of a swing at nothing, per tool (other items give a 0.35 s push).
const AIR := {&"axe": 0.7, &"pickaxe": 0.75, &"hoe": 0.6, &"scythe": 0.7, &"pitchfork": 0.6}


## [profile, strokes] for an action done with `stack`.
static func resolve(action_id: String, stack: ItemStack) -> Array:
	var entry: Array = ACTIONS.get(action_id, [&"work", 0])
	var profile: StringName = entry[0]
	if profile == &"":
		var tool: StringName = stack.item.tool_type if stack else &""
		profile = TOOL_PROFILES.get(tool, &"work")
	return [profile, int(entry[1])]


## Strokes an action of `duration` seconds plays (0 = one push per WORK_STROKE).
static func strokes_for(strokes: int, duration: float) -> int:
	return strokes if strokes > 0 else maxi(1, roundi(duration / WORK_STROKE))


## The profile's contact point (0..1 of a stroke), or -1 when it has none.
static func impact_u(profile: StringName) -> float:
	var p: Dictionary = PROFILES.get(profile, {})
	return float(p.get("impact", -1.0))


## The cue timeline of an action: [[seconds, kind, stroke]] in time order. Kinds:
## &"whoosh", &"pour_on", &"pour_off", &"release", &"hit" (cosmetic contact) and
## &"final" (exactly one: the gameplay effect).
static func cues(profile: StringName, strokes: int, duration: float) -> Array:
	var p: Dictionary = PROFILES.get(profile, PROFILES[&"work"])
	var n := maxi(strokes, 1)
	var stroke := duration / float(n)
	var impact := float(p.get("impact", -1.0))
	var final_u := float(p.get("final", impact if impact > 0.0 else 1.0))
	var out: Array = []
	for i in n:
		var t0 := stroke * float(i)
		var last := i == n - 1
		if impact > 0.0 and not (last and is_equal_approx(final_u, impact)):
			out.append([t0 + stroke * impact, &"hit", i])
		if last:
			out.append([t0 + stroke * final_u, &"final", i])
		if p.get("whoosh", false) and impact > 0.0:
			out.append([maxf(t0 + stroke * impact - WHOOSH_LEAD, t0), &"whoosh", i])
		if p.has("pour"):
			var pour: Vector2 = p["pour"]
			out.append([t0 + stroke * pour.x, &"pour_on", i])
			out.append([t0 + stroke * pour.y, &"pour_off", i])
		if p.has("release"):
			out.append([t0 + stroke * float(p["release"]), &"release", i])
		for d: float in p.get("drips", []):
			out.append([t0 + stroke * d, &"hit", i])
	out.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	return out


## The pose offset of `profile` at `u` (0..1 of one stroke): [position, rotation about the
## hand (camera space)].
static func sample(profile: Dictionary, u: float) -> Array:
	var keys: Array = profile.get("keys", [])
	if keys.size() < 2:
		return [Vector3.ZERO, Quaternion.IDENTITY]
	for k in range(1, keys.size()):
		var b: Array = keys[k]
		if u <= float(b[0]) or k == keys.size() - 1:
			var a: Array = keys[k - 1]
			var span := maxf(float(b[0]) - float(a[0]), 0.0001)
			var w := clampf(u - float(a[0]), 0.0, span)
			var trans := Tween.TRANS_SINE
			var ease_type := Tween.EASE_IN_OUT
			if b.size() > 4:
				trans = b[3]
				ease_type = b[4]
			var f: float = Tween.interpolate_value(0.0, 1.0, w, span, trans, ease_type)
			var pa: Vector3 = a[1]
			var pb: Vector3 = b[1]
			var qa := Quaternion.from_euler((a[2] as Vector3) * DEG)
			var q := qa.slerp(Quaternion.from_euler((b[2] as Vector3) * DEG), f)
			if profile.has("axis"):
				var frame := Quaternion.from_euler((profile["axis"] as Vector3) * DEG)
				q = frame * q * frame.inverse()
			return [pa + (pb - pa) * f, q]
	return [Vector3.ZERO, Quaternion.IDENTITY]
