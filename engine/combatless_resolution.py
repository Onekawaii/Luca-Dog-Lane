#!/usr/bin/env python3
# combatless_resolution.py - Resolve silly commands and bad ideas with consequences

import random

class CombatlessResolution:
    def __init__(self, game_state):
        self.game_state = game_state

    def check_hazards(self, room, direction):
        """Check for hazards when moving."""
        hazards = room.get("hazards", [])
        for hazard in hazards:
            if hazard == "trip" and random.random() < 0.3:
                self.game_state.stats["health"] -= 5
                return "You trip on the escalator. Health -5."
            elif hazard == "security_drone" and random.random() < 0.2:
                self.game_state.stats["hive_pressure"] += 10
                return "A security drone scans you. Hive Pressure +10."
        return None

    def resolve_eat_random_item(self):
        """Resolve eating a random item."""
        edible_candidates = []
        # Find edible items in inventory and room
        for item in self.game_state.inventory:
            if self.is_edible(item):
                edible_candidates.append(item)
        for item in self.game_state.room["items"]:
            if self.is_edible(item):
                edible_candidates.append(item)
        
        if not edible_candidates:
            # Use terrible idea fallback
            return self.resolve_special_action("eat_nothing")
        
        item = random.choice(edible_candidates)
        # Remove from wherever it was
        if item in self.game_state.inventory:
            self.game_state.inventory.remove(item)
        else:
            self.game_state.room["items"].remove(item)
        
        # Resolve through consequence engine
        return self.resolve_special_action("eat_random_item", target=item)

    def resolve_ape_scream(self, target):
        """Resolve ape scream command."""
        result = self.resolve_special_action("ape_scream", target=target)
        self.game_state.adjust_ape_chaos(1)  # Always increase ape chaos
        return result

    def resolve_special_action(self, action_id, target=None):
        """Unified resolver for special actions with weighted consequences."""
        # Load consequence tables
        try:
            import json
            import os
            tables_path = os.path.join("writing", "bad_idea_results.json")
            with open(tables_path, 'r') as f:
                tables = json.load(f)
        except:
            # Fallback to hardcoded
            tables = self.get_fallback_tables()

        if action_id not in tables:
            return f"Nothing happens with {action_id}."

        table = tables[action_id]
        
        # Filter entries by conditions
        applicable_entries = []
        for entry in table:
            conditions = entry.get("conditions", [])
            if self.check_conditions(conditions):
                applicable_entries.append(entry)
        
        if not applicable_entries:
            applicable_entries = table  # Fallback to all entries
        
        # Weight-based selection
        total_weight = sum(entry["weight"] for entry in applicable_entries)
        if total_weight == 0:
            return "Nothing happens."
        
        roll = random.randint(1, total_weight)
        current_weight = 0
        selected_entry = None
        
        for entry in applicable_entries:
            current_weight += entry["weight"]
            if roll <= current_weight:
                selected_entry = entry
                break
        
        if not selected_entry:
            return "Nothing happens."
        
        # Apply effects
        effects = selected_entry.get("effects", {})
        self.apply_effects(effects)
        
        # Return text
        text = selected_entry["text"]
        if target and "{target}" in text:
            text = text.replace("{target}", target)
        elif target and "{item}" in text:
            text = text.replace("{item}", target)
            
        return text

    def check_conditions(self, conditions):
        """Check if conditions are met."""
        for condition in conditions:
            if condition.startswith("room_tag:"):
                tag = condition[9:]
                if tag not in self.game_state.room.get("tags", []):
                    return False
            elif condition.startswith("inventory_has:"):
                item = condition[13:]
                if item not in self.game_state.inventory:
                    return False
            elif condition.startswith("npc_present:"):
                npc = condition[12:]
                if npc not in self.game_state.room.get("npcs", []):
                    return False
            elif condition.startswith("flag:"):
                flag = condition[5:]
                if flag not in self.game_state.global_flags and flag not in self.game_state.chapter_flags:
                    return False
            elif condition.startswith("state:filed_status="):
                status = condition[18:]
                if self.game_state.filed_status != status:
                    return False
            elif condition == "frank_rep_low":
                if self.game_state.frank_reputation >= 0:
                    return False
            elif condition == "frank_rep_high":
                if self.game_state.frank_reputation <= 0:
                    return False
            elif condition.startswith("high_ape_chaos"):
                if self.game_state.brother_ape_chaos_meter < 5:
                    return False
            elif condition.startswith("high_bureaucracy"):
                if self.game_state.stats["bureaucracy"] < 5:
                    return False
            elif condition.startswith("high_reputation_frank"):
                if self.game_state.frank_reputation < 3:
                    return False
            elif condition.startswith("low_reputation_frank"):
                if self.game_state.frank_reputation > -3:
                    return False
            elif condition.startswith("has_item:"):
                item = condition[9:]
                if item not in self.game_state.inventory:
                    return False
        return True

    def apply_effects(self, effects):
        """Apply effects to game state."""
        for effect_key, value in effects.items():
            if effect_key == "health":
                self.game_state.adjust_health(value)
            elif effect_key == "alter":
                self.game_state.adjust_alter(value)
            elif effect_key == "bureaucracy":
                self.game_state.adjust_bureaucracy(value)
            elif effect_key == "ape_chaos":
                self.game_state.adjust_ape_chaos(value)
            elif effect_key.startswith("reputation_"):
                faction = effect_key[11:]  # Remove "reputation_"
                self.game_state.adjust_reputation(faction, value)
            elif effect_key == "frank_reputation":
                self.game_state.frank_reputation = max(-3, min(3, self.game_state.frank_reputation + value))
            elif effect_key == "filed_status":
                self.game_state.filed_status = value
            elif effect_key == "remove_item":
                if value in self.game_state.inventory:
                    self.game_state.inventory.remove(value)
            elif effect_key == "add_item":
                self.game_state.inventory.add(value)
            elif effect_key == "queue_number":
                self.game_state.queue_number = value
            elif effect_key == "hive_pressure":
                self.game_state.adjust_hive_pressure(value)
            elif effect_key == "resistance":
                self.game_state.adjust_resistance(value)
            elif effect_key == "unlock_flag":
                self.game_state.set_flag(value)
            # Add more effect types as needed

    def get_fallback_tables(self):
        """Fallback tables if JSON loading fails."""
        return {
            "eat_random_item": [
                {
                    "weight": 50,
                    "conditions": [],
                    "text": "You eat something random. It has consequences.",
                    "effects": {"health": -5}
                }
            ],
            "ape_scream": [
                {
                    "weight": 100,
                    "conditions": [],
                    "text": "You scream. The ape within you stirs.",
                    "effects": {"ape_chaos": 1}
                }
            ]
        }

    def is_edible(self, item):
        """Check if item is edible."""
        edible_items = ["receipt", "amber_shard", "rock"]  # Define edible items
        return item in edible_items