class_name WaterSource
extends RefCounted
## Shared "refill the watering can" behaviour for the well and the pond.

const ACTION := {"id": "refill", "verb": "ACTION_REFILL", "label": "PROGRESS_REFILLING", "duration": 1.0}


static func use_prompt(stack: ItemStack) -> String:
	return TranslationServer.translate("ACTION_REFILL") if _is_can(stack) else ""


static func use_action(stack: ItemStack) -> Dictionary:
	return ACTION if _is_can(stack) else {}


static func can_start(stack: ItemStack) -> String:
	return TranslationServer.translate("MSG_CAN_FULL") if stack.water >= stack.item.water_capacity else ""


static func refill(stack: ItemStack) -> void:
	stack.water = stack.item.water_capacity
	PlayerState.inventory.changed.emit()


static func _is_can(stack: ItemStack) -> bool:
	return stack != null and stack.item.water_capacity > 0
