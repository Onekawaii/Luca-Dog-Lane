#!/usr/bin/env python3
# game_state.py - Core game state management for Hive-Lattice Bard

import random
import json
import os

class GameState:
    def __init__(self):
        self.rooms = {}
        self.room = None
        self.inventory = set()
        self.flags = {
            "chicken_alive": True,
            "used_exit_sign": False,
            "amber_tool": False,
            "drone_ally": False,
            "overseer_staggered": False,
            "time_slips": 0,
        }
        self.stats = {
            "health": 100,
            "alter": 0,
            "bureaucracy": 0,
            "ape_chaos": 0,
            "reputation_frank": 0,
            "reputation_goblins": 0,
            "reputation_succubi": 0,
            "chapter_progress": 0,
            "curse": 0,
            "hive_pressure": 0,
            "resistance": 1,
            "score": 0
        }
        # Bard skills as simple consumables or repeatables
        self.skills = {
            "shiny_rock": True,      # one reroll/stall per play
            "escalator_hum": True,   # bypass one hazard
            "coupon_chant": True,    # get drone ally
            "foggy_receipt": True,   # skip an encounter
            "jingle_memory": True,   # +1 alter for all allies (here: just player)
            "mall_pebble": True,     # -1 hive pressure OR charm
            "exit_sign": True        # once per run teleport two nodes
        }
        # Hive-Lattice Bard command additions
        self.last_command = None
        self.last_object = None  # For pronoun handling (IT, HIM, HER)
        self.description_mode = "normal"  # normal, verbose, brief, superbrief
        self.containers = {}  # item_name -> set of contained items
        self.open_containers = set()  # which containers are open
        self.locked_items = set()  # locked containers/doors
        self.keys = {}  # item_name -> key_name that unlocks it
        self.item_weights = {}  # item_name -> weight
        self.max_weight = 50  # maximum carrying capacity
        self.treasures = set()  # collected treasures
        self.room_details = {}  # room_name -> dict of examinable details
        self.lit_items = set()  # items that are currently lit/burning
        self.profanity_responses = [
            "Such language in a high-class establishment like this!",
            "The hive tuts disapprovingly.",
            "Your words curdle the ambient neon.",
            "The architecture blushes and looks away.",
            "A security drone makes a note of your vocabulary."
        ]
        # New fields for chapter system
        self.chapter = 1
        self.level_index = 1
        self.checkpoint = 1
        self.global_flags = set()
        self.chapter_flags = set()
        self.unlocked_commands = set(["look", "go", "take", "drop", "inventory", "examine", "use", "talk", "save", "load"])  # base commands
        self.visited_nodes = set()
        self.bad_idea_counters = {}
        self.curse_counters = {}
        self.brother_ape_chaos_meter = 0
        
        # Chapter progression tracking (persistent across chapters)
        self.chapter_route_history = []  # list of end-of-chapter summaries
        self.chapters_completed = []  # [1, 2, 3] etc

        # Chapter 2 specific state
        self.frank_reputation = 0  # -3 to +3, clamp rules applied
        self.filed_status = "none"  # none, incomplete, filed, stamped, denied, appealed, approved
        self.queue_number = None  # str or None

        # Chapter 3: Department of Sustained Loss (system state)
        self.loss_debt = 0  # integer meter; higher means you "owe" more loss
        self.loss_report_filed = False  # has the player filed a loss report this chapter?
        self.reclaimed_losses = set()  # items successfully reclaimed
        self.surrendered_items = set()  # items surrendered to the department
        self.chapter3_release_status = None  # released_clean | released_with_loss | retained_for_review | None

    def load_world_data(self, content_dir="content"):
        """Load rooms, items, characters from JSON files."""
        # Load rooms for all chapters
        for chapter in [1, 2, 3]:
            rooms_file = os.path.join(content_dir, f"rooms_ch{chapter:02d}.json")
            if os.path.exists(rooms_file):
                with open(rooms_file, 'r') as f:
                    rooms_data = json.load(f)
                    for room_data in rooms_data:
                        self.add_room_from_data(room_data)

        # Load items
        items_file = os.path.join(content_dir, "items.json")
        if os.path.exists(items_file):
            with open(items_file, 'r') as f:
                items_data = json.load(f)
                self.item_weights = {item["name"]: item.get("weight", 1) for item in items_data}

        # Load characters
        characters_file = os.path.join(content_dir, "characters.json")
        if os.path.exists(characters_file):
            with open(characters_file, 'r') as f:
                characters_data = json.load(f)
                # Process characters data

        # Set starting room
        for room in self.rooms.values():
            if room["id"] == "ch01_entry_mall":
                self.room = room
                break

    def add_room_from_data(self, data):
        """Add a room from JSON data."""
        room_id = data["id"]
        name = data["name"]
        self.rooms[room_id] = {
            "id": room_id,
            "chapter": data["chapter"],
            "level_index": data["level_index"],
            "name": name,
            "desc": data["description"],  # Changed to desc for compatibility
            "short_description": data.get("short_description", ""),
            "exits": data.get("exits", {}),
            "items": data.get("items", []),
            "npcs": data.get("npcs", []),
            "tags": data.get("tags", []),
            "hazards": data.get("hazards", []),
            "required_flags": data.get("required_flags", []),
            "set_flags_on_enter": data.get("set_flags_on_enter", []),
            "events": data.get("events", []),
            "special_commands": data.get("special_commands", {}),
            "failure_table": data.get("failure_table", []),
            "success_table": data.get("success_table", []),
            "chapter_progress_value": data.get("chapter_progress_value", 0),
            "visited": False
        }
        if data.get("details"):
            self.room_details[room_id] = data["details"]

    def populate_fallback(self):
        """Fallback hardcoded rooms for initial testing."""
        self.add_room("Entry Mall", desc=(
            "Sliding doors gasp. Fog rolls out. Neon primes flicker overhead. "
            "A chicken pecks the tile and stares as if it knows the ending."
        ), exits={"east": "Escalator Split"}, items=["receipt", "rock"],
        special_commands={"echo": "The mall's acoustics amplify your voice strangely."},
        details={
            "walls": "The walls are covered in geometric patterns that shift when you're not looking directly at them.",
            "ceiling": "The ceiling is lost in fog and neon. You can't see where it ends.",
            "floor": "The floor is polished tile that reflects the neon above. Your footsteps echo.",
            "doors": "The sliding doors move with a mechanical sigh. They seem to breathe.",
            "neon": "The neon lights pulse in patterns that might be code. Or music. Or both."
        })

        self.add_room("Escalator Split", desc=(
            "Two escalators spiral: one up, one down. The handrails hum a familiar note."
        ), exits={"up": "Storefront Eleven", "down": "Hive Concourse", "west": "Entry Mall"})

        self.add_room("Storefront Eleven", desc=(
            "A nameless storefront glows only the numeral 11. "
            "Glass unbroken, bargains unspoken."
        ), exits={"down": "Hive Concourse", "south": "Atrium Void"}, items=["amber_shard"])

        self.add_room("Hive Concourse", desc=(
            "Overhead, a honeycomb vault drips bioluminescent amber. "
            "Footsteps echo in a rhythm the hive enjoys."
        ), exits={"up": "Storefront Eleven", "north": "Atrium Void", "west": "Escalator Split"})

        self.add_room("Atrium Void", desc=(
            "Black circular plaza. A tungsten beam pinholes the dust. "
            "Silence tastes metallic."
        ), exits={"east": "Overseer Ring", "west": "Storefront Eleven", "south": "Hive Concourse"})

        self.add_room("Overseer Ring", desc=(
            "A skyscraper made of staircases. Windows blink like hex eyes. "
            "You feel watched by math."
        ), exits={"east": "Core", "west": "Atrium Void"})

        self.add_room("Core", desc=(
            "The lattice collapses into a single pulsing node—like a heart that learned geometry."
        ), exits={})

        self.room = next((r for r in self.rooms.values() if r["name"] == "Entry Mall"), None)

    def add_room(self, name, desc, exits=None, items=None, containers=None, characters=None, special_commands=None, details=None):
        """Legacy method for adding rooms."""
        self.rooms[name] = {
            "name": name,
            "desc": desc,
            "exits": exits or {},
            "items": items or [],
            "containers": containers or {},
            "characters": characters or [],
            "special_commands": special_commands or {},
            "details": details or {},
            "visited": False
        }
        if characters:
            self.characters[name] = characters
        if details:
            self.room_details[name] = details

    # State management methods
    def adjust_health(self, amount):
        """Adjust health with clamping."""
        self.stats["health"] = max(0, min(100, self.stats["health"] + amount))

    def adjust_alter(self, amount):
        """Adjust alter level."""
        self.stats["alter"] = max(0, self.stats["alter"] + amount)

    def adjust_bureaucracy(self, amount):
        """Adjust bureaucracy level."""
        self.stats["bureaucracy"] = max(0, self.stats["bureaucracy"] + amount)

    def adjust_ape_chaos(self, amount):
        """Adjust ape chaos meter."""
        self.brother_ape_chaos_meter = max(0, self.brother_ape_chaos_meter + amount)
        self.stats["ape_chaos"] = self.brother_ape_chaos_meter

    def adjust_reputation(self, faction, amount):
        """Adjust reputation with a faction."""
        key = f"reputation_{faction}"
        if key in self.stats:
            self.stats[key] = max(-10, min(10, self.stats[key] + amount))

    def adjust_hive_pressure(self, amount):
        """Adjust hive pressure."""
        self.stats["hive_pressure"] = max(0, self.stats["hive_pressure"] + amount)

    def adjust_resistance(self, amount):
        """Adjust resistance."""
        self.stats["resistance"] = max(0, self.stats["resistance"] + amount)

    def adjust_frank_reputation(self, amount):
        """Adjust Frank reputation with clamping to -3 to +3."""
        self.frank_reputation = max(-3, min(3, self.frank_reputation + amount))

    def get_frank_reputation_band(self):
        """Get Frank reputation band: Hostile, Neutral, or Trusted."""
        if self.frank_reputation <= -2:
            return "Hostile"
        elif self.frank_reputation >= 2:
            return "Trusted"
        else:
            return "Neutral"

    def initialize_frank_reputation_from_chapter_1(self):
        """Initialize Frank reputation based on Chapter 1 route leaning."""
        if not self.chapter_route_history:
            self.frank_reputation = 0
            return
        
        last_chapter_summary = self.chapter_route_history[-1]
        leaning = last_chapter_summary.get("route_leaning", "hybrid")
        
        # Base value from route leaning
        if leaning == "bureaucratic":
            self.frank_reputation = 1
        elif leaning == "ape":
            self.frank_reputation = -1
        else:  # hybrid
            self.frank_reputation = 0
        
        # Apply flag modifiers
        if "self_filed" in self.global_flags:
            self.frank_reputation += 1
        if "ate_receipt" in self.global_flags:
            self.frank_reputation -= 1
        if "asked_chicken_legal_advice" in self.global_flags:
            pass  # Frank finds it weird but not illegal, no change
        if "stamped_contraband" in self.global_flags:
            self.frank_reputation -= 1
        
        # Clamp
        self.frank_reputation = max(-3, min(3, self.frank_reputation))

    def set_filed_status(self, status):
        """Set the filing status."""
        valid_statuses = ["none", "incomplete", "filed", "stamped", "denied", "appealed", "approved"]
        if status in valid_statuses:
            self.filed_status = status

    def set_flag(self, flag_name):
        """Set a global flag."""
        self.global_flags.add(flag_name)

    def has_flag(self, flag_name):
        """Check if a flag is set."""
        return flag_name in self.global_flags or flag_name in self.chapter_flags

    def unlock_command(self, command):
        """Unlock a command."""
        self.unlocked_commands.add(command)

    def is_command_unlocked(self, command):
        """Check if a command is unlocked."""
        return command in self.unlocked_commands

    def get_inventory_weight(self):
        """Get current inventory weight."""
        return self.get_current_weight()

    def can_carry_more(self, item):
        """Check if can carry additional item."""
        return self.can_carry(item)

    def get_current_weight(self):
        """Calculate total weight of inventory."""
        total = 0
        for item in self.inventory:
            weight = self.item_weights.get(item, 1)
            total += weight
            if item in self.containers:
                for contained in self.containers[item]:
                    total += self.item_weights.get(contained, 1)
        return total

    def can_carry(self, item):
        """Check if player can carry an additional item."""
        item_weight = self.item_weights.get(item, 1)
        return (self.get_current_weight() + item_weight) <= self.max_weight

    def update_state(self, changes):
        """Apply state changes from command resolution."""
        for key, value in changes.items():
            if key in self.stats:
                self.stats[key] += value
            elif key in self.flags:
                self.flags[key] = value
            elif key == "inventory_add":
                self.inventory.add(value)
            elif key == "inventory_remove":
                self.inventory.discard(value)
            elif key == "global_flag_add":
                self.global_flags.add(value)
            elif key == "chapter_flag_add":
                self.chapter_flags.add(value)
            elif key == "unlock_command":
                self.unlocked_commands.add(value)
            elif key == "bad_idea_counter":
                self.bad_idea_counters[value] = self.bad_idea_counters.get(value, 0) + 1
            elif key == "curse_counter":
                self.curse_counters[value] = self.curse_counters.get(value, 0) + 1
            elif key == "chaos_meter":
                self.brother_ape_chaos_meter += value
            # Add more as needed

    def check_requirements(self, requirements):
        """Check if player meets flag/item requirements."""
        for req in requirements:
            if req.startswith("flag:"):
                flag = req[5:]
                if flag not in self.global_flags and flag not in self.chapter_flags:
                    return False
            elif req.startswith("item:"):
                item = req[5:]
                if item not in self.inventory:
                    return False
            elif req.startswith("stat:"):
                stat, op, val = req[5:].split()
                current = self.stats.get(stat, 0)
                if op == ">" and not (current > int(val)):
                    return False
                # Add more operators as needed
        return True

    def calculate_route_leaning(self):
        """Determine player's primary route based on stats."""
        bureaucracy = self.stats["bureaucracy"]
        ape_chaos = self.stats["ape_chaos"]
        alter = self.stats["alter"]
        
        # Check if hybrid (all within 2 of each other)
        stats = [bureaucracy, ape_chaos, alter]
        if max(stats) - min(stats) <= 2:
            return "hybrid"
        
        # Determine dominant route
        max_stat = max(bureaucracy, ape_chaos, alter)
        if bureaucracy == max_stat:
            return "bureaucratic"
        elif ape_chaos == max_stat:
            return "feral"
        else:
            return "altered"

    def save_chapter_summary(self, chapter_num):
        """Create end-of-chapter summary for persistence."""
        import time
        summary = {
            "chapter": chapter_num,
            "route_leaning": self.calculate_route_leaning(),
            "chapters_completed": self.chapters_completed + [chapter_num],
            "key_flags": list(self.chapter_flags),
            "npc_standings": {
                "frank": self.stats["reputation_frank"],
                "chicken": self.stats.get("reputation_chicken", 0),
                "goblins": self.stats["reputation_goblins"],
                "succubi": self.stats["reputation_succubi"]
            },
            "special_actions_taken": list(self.bad_idea_counters.keys()),
            "final_health": self.stats["health"],
            "final_bureaucracy": self.stats["bureaucracy"],
            "final_ape_chaos": self.stats["ape_chaos"],
            "final_alter": self.stats["alter"],
            "completion_time_seconds": 0  # Will be filled by caller with actual time
        }
        self.chapter_route_history.append(summary)
        self.chapters_completed.append(chapter_num)
        return summary

    # --- Chapter 3 helpers (Department of Sustained Loss) ---
    def add_loss_debt(self, delta):
        self.loss_debt = max(0, int(self.loss_debt) + int(delta))
        self.evaluate_chapter3_release_status()

    def mark_loss_report_filed(self):
        self.loss_report_filed = True
        self.evaluate_chapter3_release_status()

    def surrender_item(self, item):
        if item in self.inventory:
            self.inventory.remove(item)
            self.surrendered_items.add(item)
            self.evaluate_chapter3_release_status()
            return True
        return False

    def reclaim_item(self, item):
        if item in self.surrendered_items:
            self.surrendered_items.remove(item)
            self.inventory.add(item)
            self.reclaimed_losses.add(item)
            self.evaluate_chapter3_release_status()
            return True
        return False

    def set_chapter3_release_status(self, status):
        allowed = {"released_clean", "released_with_loss", "retained_for_review", None}
        if status in allowed:
            self.chapter3_release_status = status

    def evaluate_chapter3_release_status(self):
        if self.chapter3_release_status == "retained_for_review":
            return self.chapter3_release_status
        if not self.loss_report_filed:
            self.chapter3_release_status = None
            return self.chapter3_release_status
        if self.loss_debt == 0 and not self.surrendered_items:
            self.chapter3_release_status = "released_clean"
        else:
            self.chapter3_release_status = "released_with_loss"
        return self.chapter3_release_status

    def check_requirements(self, requirements):
        """Check if player meets flag/item requirements."""
        for req in requirements:
            if req.startswith("flag:"):
                flag = req[5:]
                if flag not in self.global_flags and flag not in self.chapter_flags:
                    return False
            elif req.startswith("item:"):
                item = req[5:]
                if item not in self.inventory:
                    return False
            elif req.startswith("stat:"):
                stat, op, val = req[5:].split()
                current = self.stats.get(stat, 0)
                if op == ">" and not (current > int(val)):
                    return False
                # Add more operators as needed
        return True