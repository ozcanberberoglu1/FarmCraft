extends Node
## Global signal bus. Gameplay systems emit here so UI and other systems can react
## without holding direct references to each other.

# Economy
signal money_changed(new_amount: int, delta: int)

# Items
signal item_picked_up(item_id: StringName, count: int)
signal item_sold(item_id: StringName, count: int, gold: int)

# Farm work (quests and farm experience listen to these)
signal action_done(action_id: String, target: Node)
signal placed(item_id: StringName)
signal crafted(item_id: StringName, count: int)
signal machine_started(machine_id: StringName)
signal product_made(item_id: StringName, count: int)
signal animal_born(species: StringName)
signal order_delivered(item_id: StringName, count: int, reward: int)

# The first day's hands-on steps (the tutorial and achievements listen to these)
signal door_toggled(door_id: StringName, open: bool)
signal drawer_opened(drawer_id: StringName)
signal world_item_taken(item_id: StringName)
signal vehicle_entered(vehicle: Node)
signal vehicle_exited(vehicle: Node)
signal animals_bought(species: StringName, count: int)
signal crate_stored(item_id: StringName, where: StringName)
signal construction_started(build_id: StringName, site: Node)
signal building_completed(build_id: StringName, building: Node)
signal animal_released(species: StringName, home: Node)
signal shipped(item_id: StringName, count: int)
signal achievement_unlocked(achievement_id: StringName)
signal morning_sale(gold: int)
# Looking after the coop, and mending run-down walls by hand
signal coop_fed(coop: Node)
signal coop_watered(coop: Node)
signal nest_filled(coop: Node, filled: int)
signal wall_patched(building_id: StringName, done: int, total: int)
signal building_repaired(building_id: StringName)
# An egg thrown from the hand broke where it landed
signal egg_broken(at: Vector3)
# Fishing, the campfire and eating (the tutorial and achievements listen to these)
signal line_cast
signal fish_caught(item_id: StringName)
signal campfire_lit(fire: Node)
signal campfire_out(fire: Node)
signal food_cooked(item_id: StringName)
signal food_eaten(item_id: StringName)
# A sapling put in the ground, and one that has grown into a tree
signal sapling_planted(sapling: Node)
signal sapling_grown(tree: Node)
# Wild game caught by hand (a rabbit...), and a catch cleaned at the food table
signal game_caught(item_id: StringName)
signal food_cleaned(item_id: StringName)
# A fertilised egg hatched into a chick, and a chick grown up
signal chick_hatched(chick: Node)
signal chick_grown(animal: Node)
# Wolves (WolfRaids) hurt or killed a farm animal (Animals.injure / kill: its id, and for
# a death its species and where its remains lie); the vet healed one (it is back home)
signal animal_injured(id: int)
signal animal_killed(id: int, species: StringName, at: Vector3)
signal animal_healed(id: int)

# Player feedback
signal notification_requested(text: String, color: Color)
signal interaction_prompt_changed(lines: PackedStringArray)
signal action_progress_started(label: String, duration: float)
signal action_progress_updated(ratio: float)
signal action_progress_finished(completed: bool)

# Weather & day cycle
signal lightning
signal day_ending
signal passed_out
# The farmer was hurt until he fainted (PlayerState.hurt): emitted as he falls, before
# the night's skip that carries him home to bed (SleepScreen.start_sleep).
signal player_knocked_out

# UI focus (inventory, shop, menus...)
signal ui_opened(ui_name: StringName)
signal ui_closed(ui_name: StringName)

# Time
signal clock_tick(total_minutes: float, delta_minutes: float)
signal hour_passed(hour: int)
signal day_started(day: int)
signal season_changed(season: int)
signal time_skipped(delta_minutes: float)
