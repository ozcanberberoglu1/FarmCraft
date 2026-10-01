class_name ZeynepPerson
extends Townsperson
## Zeynep, the new neighbour, as a townsperson of her own (ZeynepHome places and drives
## her; SideStory knows what she says): E meets her, hands her what she asked
## for, or has a word with her, instead of a greeting's bubble. Looking at her shows her
## name with the friendship's hearts (Relations) once they have met. Hidden and without a
## collider while she is indoors.

var home: ZeynepHome


func interact_title() -> String:
	if not SideStory.met:
		return tr("PERSON_ZEYNEP")
	return "%s  %s" % [tr("PERSON_ZEYNEP"), Relations.hearts_text(SideStory.WHO)]


func interact_prompt(_player: Node) -> String:
	if home == null or not home.can_talk():
		return ""
	if not SideStory.met:
		return tr("ACTION_MEET_ZEYNEP")
	if SideStory.can_deliver():
		var kind := SideStory.errand_kind()
		if kind in ["gift", "food"]:
			return tr("ACTION_GIVE_DOG_FOOD")
		if SideStory.errand_needs_item():
			return tr("ACTION_GIVE_%s" % kind.to_upper())
	return tr("ACTION_TALK")


func interact(_player: Node) -> void:
	if home != null:
		home.talk()


## Indoors (hidden, no collider, not animated) or out where she can be seen.
func set_indoors(inside: bool) -> void:
	visible = not inside
	collision_layer = 0 if inside else (4 | 16)
	process_mode = Node.PROCESS_MODE_DISABLED if inside else Node.PROCESS_MODE_INHERIT


func is_indoors() -> bool:
	return not visible
