extends Node

# Global Event Bus for Native Hive-Lattice Game Client

signal action_requested(action_data: Dictionary)
signal event_emitted(event_data: Dictionary)
signal world_state_changed(delta_data: Dictionary)

signal scene_transition_requested(scene_id: String)
signal room_change_requested(room_id: String, entrance_name: String)
signal room_entered(room_id: String)
signal dialogue_started(actor_id: String, speaker_name: String, text: String, choices: Array)
signal dialogue_choice_selected(choice_id: String)
signal dialogue_closed()

signal inventory_changed()
signal item_armed(item_id: String)
signal item_disarmed()

signal overlay_opened(overlay_id: String)
signal overlay_closed(overlay_id: String)
signal notification_posted(message: String)
signal debug_toggled(is_enabled: bool)
signal camera_focus_requested(target_pos: Vector2, zoom_level: float)
signal camera_reset_requested()
signal virtual_move_input(input_vector: Vector2)

# First-person runtime signals. These are presentation/runtime events only;
# they do not add fields to the frozen campaign or save schemas.
signal virtual_look_input(look_delta: Vector2)
signal first_person_interact_pressed()
signal first_person_prompt_changed(prompt_text: String)
signal first_person_interaction_requested(interaction_data: Dictionary)
signal first_person_dialogue_requested(speaker_name: String, lines: Array)
signal first_person_dialogue_closed()
signal first_person_objective_changed(objective_text: String)
signal first_person_input_lock_changed(locked: bool)
signal first_person_inspect_started(target_name: String)
signal first_person_inspect_ended()

# Procedural world signals. Generated plans remain runtime data and persist only
# their deterministic seed/receipt through existing WorldState.world_state.
signal procgen_world_ready(receipt: Dictionary)
signal procgen_streaming_changed(active_cells: Array)


# Chalk Circle bridge signals. These are additive runtime events; Chalk state
# is persisted inside WorldState.world_state and does not change save schema v3.
signal chalk_circle_layer_changed(from_layer: int, to_layer: int, layer_name: String, cause: String)
signal chalk_circle_archived(entry: Dictionary)
signal chalk_circle_refusal(reason: String)
