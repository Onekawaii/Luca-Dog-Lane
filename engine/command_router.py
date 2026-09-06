#!/usr/bin/env python3
# command_router.py - Route parsed intents to appropriate handlers

import random
from engine.game_state import GameState

class CommandRouter:
    def __init__(self, game_state, parser, world_loader, progression, combatless_resolution, random_events):
        self.game_state = game_state
        self.parser = parser
        self.world_loader = world_loader
        self.progression = progression
        self.combatless_resolution = combatless_resolution
        self.random_events = random_events

    def route_intent(self, intent):
        """Route intent to appropriate handler."""
        intent_type = intent["intent"]
        
        if intent_type == "EMPTY":
            return self.handle_empty()
        elif intent_type == "INVENTORY":
            return self.handle_inventory()
        elif intent_type == "LOOK":
            return self.handle_look()
        elif intent_type == "MOVE":
            return self.handle_move(intent)
        elif intent_type == "TAKE":
            return self.handle_take(intent)
        elif intent_type == "DROP":
            return self.handle_drop(intent)
        elif intent_type == "EXAMINE":
            return self.handle_examine(intent)
        elif intent_type == "USE":
            return self.handle_use(intent)
        elif intent_type == "TALK":
            return self.handle_talk(intent)
        elif intent_type == "OPEN":
            return self.handle_open(intent)
        elif intent_type == "CLOSE":
            return self.handle_close(intent)
        elif intent_type == "READ":
            return self.handle_read(intent)
        elif intent_type == "EAT":
            return self.handle_eat(intent)
        elif intent_type == "EAT_RANDOM_ITEM":
            return self.handle_eat_random_item()
        elif intent_type == "DRINK":
            return self.handle_drink(intent)
        elif intent_type == "THROW":
            return self.handle_throw(intent)
        elif intent_type == "SEARCH":
            return self.handle_search(intent)
        elif intent_type == "PUSH_PULL":
            return self.handle_push_pull(intent)
        elif intent_type == "LIGHT":
            return self.handle_light(intent)
        elif intent_type == "EXTINGUISH":
            return self.handle_extinguish(intent)
        elif intent_type == "SMELL":
            return self.handle_smell(intent)
        elif intent_type == "LISTEN":
            return self.handle_listen(intent)
        elif intent_type == "SAVE":
            return self.handle_save()
        elif intent_type == "LOAD":
            return self.handle_load()
        elif intent_type == "QUIT":
            return self.handle_quit()
        elif intent_type == "HELP":
            return self.handle_help()
        # Brother Ape commands
        elif intent_type == "APE_SCREAM":
            return self.handle_ape_scream(intent)
        elif intent_type == "BEFRIEND":
            return self.handle_befriend(intent)
        elif intent_type == "ACCUSE":
            return self.handle_accuse(intent)
        elif intent_type == "WORSHIP":
            return self.handle_worship(intent)
        elif intent_type == "INSULT":
            return self.handle_insult(intent)
        elif intent_type == "DANCE_BADLY":
            return self.handle_dance_badly()
        elif intent_type == "STAMP":
            return self.handle_stamp(intent)
        elif intent_type == "ASK_CHICKEN_LEGAL":
            return self.handle_ask_chicken_legal()
        elif intent_type == "QUEUE":
            return self.handle_queue()
        elif intent_type == "APPEAL":
            return self.handle_appeal(intent)
        elif intent_type == "AUDIT":
            return self.handle_audit()
        elif intent_type == "FILE":
            return self.handle_file(intent)
        elif intent_type == "COMPLAINT":
            return self.handle_complaint()
        elif intent_type == "NOTARIZE":
            return self.handle_notarize(intent)
        elif intent_type == "DENY":
            return self.handle_deny(intent)
        elif intent_type == "RESUBMIT":
            return self.handle_resubmit()
        elif intent_type == "SPECIAL":
            return self.handle_special(intent)
        # Chapter 3: Department of Sustained Loss
        elif intent_type == "REPORT_LOSS":
            return self.handle_report_loss()
        elif intent_type == "SURRENDER":
            return self.handle_surrender(intent)
        elif intent_type == "RECLAIM":
            return self.handle_reclaim(intent)
        elif intent_type == "CATALOGUE":
            return self.handle_catalogue()
        else:
            return self.handle_unknown(intent)

    def handle_empty(self):
        return "You stare into the void. The void stares back."

    def handle_inventory(self):
        if not self.game_state.inventory:
            return "You're carrying nothing but existential dread."
        items = sorted(self.game_state.inventory)
        return f"You're carrying: {', '.join(items)}"

    def handle_look(self):
        # Similar to original look method
        r = self.game_state.room
        title = f"[ {r['name']} ]"
        output = [title, "-"*len(title)]
        if self.game_state.description_mode != "superbrief" or not r["visited"]:
            output.append(r["desc"])
        if r["items"]:
            output.append(f"You see: {', '.join(sorted(r['items']))}")
        if r.get("containers"):
            for container, items in r["containers"].items():
                status = "locked" if container in self.game_state.locked_items else ("open" if container in self.game_state.open_containers else "closed")
                msg = f"There is a {container} here ({status})."
                if container in self.game_state.open_containers and items:
                    msg += f" Inside: {', '.join(sorted(items))}"
                output.append(msg)
        if r.get("characters"):
            output.append(f"You see: {', '.join(r['characters'])}")
        if r["exits"]:
            output.append(f"Exits: {', '.join([f'{k} -> {v}' for k, v in r['exits'].items()])}")
        if self.game_state.description_mode == "verbose":
            output.append(f"Hive Pressure: {self.game_state.stats['hive_pressure']} | Resistance: {self.game_state.stats['resistance']} | Alter: {self.game_state.stats['alter']} | Chicken: {'alive' if self.game_state.flags['chicken_alive'] else '???'}")
        return "\n".join(output)

    def handle_move(self, intent):
        direction = intent.get("direction", "")
        r = self.game_state.room
        dest = r["exits"].get(direction.lower())
        if not dest:
            return "You bump into architectural intent. That way doesn't go yet."
        # Check hazards
        hazard_result = self.combatless_resolution.check_hazards(r, direction)
        if hazard_result:
            return hazard_result
        self.game_state.room = self.game_state.rooms[dest]
        if not self.game_state.room["visited"]:
            self.game_state.room["visited"] = True
            self.progression.on_enter_room()
        return self.handle_look()

    def handle_take(self, intent):
        obj = intent.get("item", "")
        obj = self.parser.normalize_object(obj)
        if not obj:
            return "Take what—narrative control?"
        if obj == "number":
            return self.handle_queue()
        # Handle multiple items
        if "," in obj or " and " in obj:
            items = [i.strip() for i in obj.replace(" and ", ",").split(",")]
            results = []
            for item in items:
                results.append(self.take_single_item(item))
            return "\n".join(results)
        return self.take_single_item(obj)

    def take_single_item(self, item):
        if item in self.game_state.room["items"]:
            if self.game_state.can_carry(item):
                self.game_state.room["items"].remove(item)
                self.game_state.inventory.add(item)
                self.game_state.last_object = item
                return f"Taken: {item}"
            else:
                return "You're carrying too much already."
        else:
            return f"You don't see {item} here."

    def handle_drop(self, intent):
        obj = intent.get("item", "")
        obj = self.parser.normalize_object(obj)
        if obj in self.game_state.inventory:
            self.game_state.inventory.remove(obj)
            self.game_state.room["items"].append(obj)
            return f"Dropped: {obj}"
        else:
            return f"You're not carrying {obj}."

    def handle_examine(self, intent):
        target = intent.get("target", "")
        target = self.parser.normalize_object(target)
        # Check room details
        if target in self.game_state.room_details.get(self.game_state.room["name"], {}):
            return self.game_state.room_details[self.game_state.room["name"]][target]
        # Check items
        if target in self.game_state.inventory or target in self.game_state.room["items"]:
            return f"You examine the {target}. It looks important."
        # Check characters
        if target in self.game_state.room.get("characters", []):
            return f"You examine {target}. They look back at you."
        return f"You don't see {target} here."

    def handle_use(self, intent):
        item = intent.get("item", "")
        item = self.parser.normalize_object(item)
        if item not in self.game_state.inventory:
            return f"You're not carrying {item}."
        # Check for special use effects
        return f"You use the {item}. Nothing happens yet."

    def handle_talk(self, intent):
        target = intent.get("target", "")
        if target in self.game_state.room.get("npcs", []):
            if target == "frank" and self.game_state.room["id"] == "ch02_08_frank_outer_desk":
                # Evaluate paperwork
                if self.game_state.filed_status == "stamped":
                    self.game_state.filed_status = "approved"
                    self.game_state.frank_reputation += 1
                    return "Frank approves your paperwork. You may proceed."
                elif self.game_state.filed_status == "appealed":
                    if self.game_state.frank_reputation > 0:
                        self.game_state.filed_status = "approved"
                        return "Frank reviews your appeal and approves."
                    else:
                        self.game_state.filed_status = "denied"
                        self.game_state.frank_reputation -= 1
                        return "Frank denies your appeal."
                else:
                    self.game_state.filed_status = "denied"
                    self.game_state.frank_reputation -= 1
                    return "Frank denies your paperwork."
            return f"You talk to {target}. They respond cryptically."
        return f"There's no one named {target} here to talk to."

    def handle_open(self, intent):
        target = intent.get("target", "")
        if target in self.game_state.room.get("containers", {}):
            if target in self.game_state.locked_items:
                return f"The {target} is locked."
            self.game_state.open_containers.add(target)
            items = self.game_state.room["containers"][target]
            if items:
                return f"You open the {target}. Inside: {', '.join(items)}"
            else:
                return f"You open the {target}. It's empty."
        return f"You can't open {target}."

    def handle_close(self, intent):
        target = intent.get("target", "")
        if target in self.game_state.open_containers:
            self.game_state.open_containers.remove(target)
            return f"You close the {target}."
        return f"The {target} is already closed."

    def handle_read(self, intent):
        target = intent.get("target", "")
        if target in self.game_state.inventory or target in self.game_state.room["items"]:
            return f"You read the {target}. It says something profound."
        return f"You can't read {target}."

    def handle_eat(self, intent):
        item = intent.get("item", "")
        if item in self.game_state.inventory:
            self.game_state.inventory.remove(item)
            return f"You eat the {item}. It tastes like regret."
        return f"You're not carrying {item}."

    def handle_eat_random_item(self):
        return self.combatless_resolution.resolve_eat_random_item()

    def handle_drink(self, intent):
        item = intent.get("item", "")
        if item in self.game_state.inventory:
            self.game_state.inventory.remove(item)
            return f"You drink the {item}. It burns going down."
        return f"You're not carrying {item}."

    def handle_throw(self, intent):
        item = intent.get("item", "")
        target = intent.get("target", "")
        if item in self.game_state.inventory:
            self.game_state.inventory.remove(item)
            return f"You throw the {item} at {target}. It shatters dramatically."
        return f"You're not carrying {item}."

    def handle_search(self, intent):
        target = intent.get("target", "")
        return f"You search the {target}. You find nothing of interest."

    def handle_push_pull(self, intent):
        target = intent.get("target", "")
        return f"You push/pull the {target}. It moves slightly."

    def handle_light(self, intent):
        target = intent.get("target", "")
        if target in self.game_state.inventory or target in self.game_state.room["items"]:
            self.game_state.lit_items.add(target)
            return f"You light the {target}. It burns brightly."
        return f"You can't light {target}."

    def handle_extinguish(self, intent):
        target = intent.get("target", "")
        if target in self.game_state.lit_items:
            self.game_state.lit_items.remove(target)
            return f"You extinguish the {target}."
        return f"The {target} isn't lit."

    def handle_smell(self, intent):
        target = intent.get("target", "")
        return f"You smell the {target}. It smells like bureaucracy."

    def handle_listen(self, intent):
        target = intent.get("target", "")
        return f"You listen to the {target}. It whispers secrets."

    def handle_save(self):
        # Use save_system
        return "Game saved."

    def handle_load(self):
        return "Game loaded."

    def handle_quit(self):
        return "Goodbye!"

    def handle_help(self):
        return "Available commands: look, go, take, drop, inventory, examine, use, talk, save, load, quit"

    # Brother Ape commands
    def handle_ape_scream(self, intent):
        target = intent.get("target", "")
        return self.combatless_resolution.resolve_ape_scream(target)

    def handle_befriend(self, intent):
        target = intent.get("target", "")
        return f"You try to befriend {target}. It stares blankly."

    def handle_accuse(self, intent):
        target = intent.get("target", "")
        return f"You accuse {target} of everything. They deny it."

    def handle_worship(self, intent):
        target = intent.get("target", "")
        return f"You worship {target}. The hive approves."

    def handle_insult(self, intent):
        target = intent.get("target", "")
        return f"You insult {target}. The air thickens."

    def handle_dance_badly(self):
        return "You dance badly. The geometry judges you."

    def handle_stamp(self, intent):
        target = intent.get("target", "")
        if target == "form" and self.game_state.filed_status == "filed":
            self.game_state.filed_status = "stamped"
        return self.combatless_resolution.resolve_special_action("stamp", target=target)

    def handle_ask_chicken_legal(self):
        return "The chicken clucks legal advice. It's surprisingly sound."

    def handle_queue(self):
        if self.game_state.queue_number is None:
            self.game_state.queue_number = f"Q-{random.randint(10000, 99999)}"
            self.game_state.inventory.add("queue_slip")
        return self.combatless_resolution.resolve_special_action("queue")

    def handle_appeal(self, intent):
        target = intent.get("target", "")
        if target == "denial" and self.game_state.filed_status == "denied":
            self.game_state.filed_status = "appealed"
            self.game_state.global_flags.add("appeal_logged")
        return self.combatless_resolution.resolve_special_action("appeal", target=target)

    def handle_audit(self):
        return "You audit the room. Numbers dance."

    def handle_file(self, intent):
        target = intent.get("target", "")
        if target == "form":
            if self.game_state.filed_status == "none":
                self.game_state.filed_status = "filed"
            elif self.game_state.filed_status == "denied":
                self.game_state.filed_status = "resubmitted"
        return f"You attempt to file {target}."

    def handle_complaint(self):
        return "You file a complaint. The hive sighs."

    def handle_notarize(self, intent):
        target = intent.get("target", "")
        return f"You notarize {target}. It's now legal."

    def handle_deny(self, intent):
        target = intent.get("target", "")
        return f"You deny {target}. Denial noted."

    def handle_resubmit(self):
        return "You resubmit. The queue grows."

    def handle_special(self, intent):
        command = intent.get("command", "")
        return self.game_state.room["special_commands"].get(command, "Nothing happens.")

    # --- Chapter 3: Department of Sustained Loss ---
    def _in_chapter3(self):
        return bool(self.game_state.room and self.game_state.room.get("chapter") == 3)

    def handle_report_loss(self):
        if not self._in_chapter3():
            return "No department here will accept your loss report."
        if self.game_state.loss_report_filed:
            return "Your loss report is already filed. The ledger remembers."
        self.game_state.mark_loss_report_filed()
        # Filing creates an initial debt that must be processed
        self.game_state.add_loss_debt(1)
        return self.combatless_resolution.resolve_special_action("report_loss")

    def handle_catalogue(self):
        if not self._in_chapter3():
            return "You catalogue nothing in particular."
        # Deterministic mechanical effect for Chapter 3 hybrid route:
        # cataloguing a loss increases debt by one (paperwork multiplies sorrow).
        self.game_state.add_loss_debt(1)
        return self.combatless_resolution.resolve_special_action("catalogue")

    def handle_surrender(self, intent):
        if not self._in_chapter3():
            return "There is no department desk here to receive surrendered items."
        item = self.parser.normalize_object(intent.get("item", "")).strip()
        if not item:
            return "Surrender what?"
        if not self.game_state.surrender_item(item):
            return f"You're not carrying {item}."
        # Surrendering reduces debt by one (but does not guarantee release).
        self.game_state.add_loss_debt(-1)
        return self.combatless_resolution.resolve_special_action("surrender", target=item)

    def handle_reclaim(self, intent):
        if not self._in_chapter3():
            return "You have nothing to reclaim here."
        item = self.parser.normalize_object(intent.get("item", "")).strip()
        if not item:
            return "Reclaim what?"
        if not self.game_state.loss_report_filed:
            self.game_state.set_chapter3_release_status("retained_for_review")
            return "No report on file. You are retained for review."
        if item not in self.game_state.surrendered_items:
            self.game_state.set_chapter3_release_status("retained_for_review")
            return "That reclaim request does not match departmental records. You are retained for review."
        # Reclaim is allowed only when debt is cleared.
        if self.game_state.loss_debt > 0:
            self.game_state.set_chapter3_release_status("retained_for_review")
            return "Your debt is unresolved. Reclaim denied. You are retained for review."
        self.game_state.reclaim_item(item)
        return self.combatless_resolution.resolve_special_action("reclaim", target=item)

    def handle_unknown(self, intent):
        return f"I don't understand '{intent.get('input', '')}'."