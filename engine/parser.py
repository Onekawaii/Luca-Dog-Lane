#!/usr/bin/env python3
# parser.py - Input parsing and intent normalization for Hive-Lattice Bard

import re

class Parser:
    def __init__(self, game_state):
        self.game_state = game_state

    def parse_input(self, user_input):
        """Parse user input into normalized intent."""
        input_lower = user_input.lower().strip()
        
        # Handle empty input
        if not input_lower:
            return {"intent": "EMPTY"}
        
        # Handle special forms first
        if input_lower in ["inventory", "i", "inv"]:
            return {"intent": "INVENTORY"}
        elif input_lower in ["look", "l"]:
            return {"intent": "LOOK"}
        elif input_lower.startswith("go ") or input_lower in ["north", "south", "east", "west", "up", "down", "n", "s", "e", "w", "u", "d"]:
            direction = self.extract_direction(input_lower)
            return {"intent": "MOVE", "direction": direction}
        elif input_lower.startswith("take ") or input_lower.startswith("get "):
            obj = self.extract_object(input_lower, ["take", "get"])
            return {"intent": "TAKE", "item": obj}
        elif input_lower.startswith("drop "):
            obj = self.extract_object(input_lower, ["drop"])
            return {"intent": "DROP", "item": obj}
        elif input_lower.startswith("examine ") or input_lower.startswith("x "):
            obj = self.extract_object(input_lower, ["examine", "x"])
            return {"intent": "EXAMINE", "target": obj}
        elif input_lower.startswith("use "):
            obj = self.extract_object(input_lower, ["use"])
            return {"intent": "USE", "item": obj}
        elif input_lower.startswith("talk ") or input_lower.startswith("speak "):
            target = self.extract_object(input_lower, ["talk", "speak"])
            return {"intent": "TALK", "target": target}
        elif input_lower.startswith("open "):
            obj = self.extract_object(input_lower, ["open"])
            return {"intent": "OPEN", "target": obj}
        elif input_lower.startswith("close "):
            obj = self.extract_object(input_lower, ["close"])
            return {"intent": "CLOSE", "target": obj}
        elif input_lower.startswith("read "):
            obj = self.extract_object(input_lower, ["read"])
            return {"intent": "READ", "target": obj}
        elif input_lower.startswith("eat "):
            obj = self.extract_object(input_lower, ["eat"])
            if obj == "random item":
                return {"intent": "EAT_RANDOM_ITEM"}
            else:
                return {"intent": "EAT", "item": obj}
        elif input_lower.startswith("drink "):
            obj = self.extract_object(input_lower, ["drink"])
            return {"intent": "DRINK", "item": obj}
        elif input_lower.startswith("throw ") or input_lower.startswith("toss "):
            parts = input_lower.split()
            if len(parts) >= 3 and parts[2] in ["at", "to"]:
                item = " ".join(parts[1:2])
                target = " ".join(parts[3:])
                return {"intent": "THROW", "item": item, "target": target}
            else:
                obj = self.extract_object(input_lower, ["throw", "toss"])
                return {"intent": "THROW", "item": obj}
        elif input_lower.startswith("search "):
            obj = self.extract_object(input_lower, ["search"])
            return {"intent": "SEARCH", "target": obj}
        elif input_lower.startswith("push ") or input_lower.startswith("pull "):
            obj = self.extract_object(input_lower, ["push", "pull"])
            return {"intent": "PUSH_PULL", "target": obj}
        elif input_lower.startswith("light ") or input_lower.startswith("burn "):
            obj = self.extract_object(input_lower, ["light", "burn"])
            return {"intent": "LIGHT", "target": obj}
        elif input_lower.startswith("extinguish "):
            obj = self.extract_object(input_lower, ["extinguish"])
            return {"intent": "EXTINGUISH", "target": obj}
        elif input_lower.startswith("smell ") or input_lower.startswith("sniff "):
            obj = self.extract_object(input_lower, ["smell", "sniff"])
            return {"intent": "SMELL", "target": obj}
        elif input_lower.startswith("listen ") or input_lower.startswith("hear "):
            obj = self.extract_object(input_lower, ["listen", "hear"])
            return {"intent": "LISTEN", "target": obj}
        elif input_lower.startswith("save"):
            return {"intent": "SAVE"}
        elif input_lower.startswith("load"):
            return {"intent": "LOAD"}
        elif input_lower.startswith("quit") or input_lower == "q":
            return {"intent": "QUIT"}
        elif input_lower.startswith("help") or input_lower == "?":
            return {"intent": "HELP"}
        
        # Brother Ape commands
        elif input_lower.startswith("ape ") or input_lower.startswith("scream at "):
            target = self.extract_object(input_lower, ["ape", "scream at"])
            return {"intent": "APE_SCREAM", "target": target}
        elif input_lower == "eat random item":
            return {"intent": "EAT_RANDOM_ITEM"}
        elif input_lower.startswith("befriend "):
            obj = self.extract_object(input_lower, ["befriend"])
            return {"intent": "BEFRIEND", "target": obj}
        elif input_lower.startswith("accuse ") or input_lower.startswith("blame "):
            obj = self.extract_object(input_lower, ["accuse", "blame"])
            return {"intent": "ACCUSE", "target": obj}
        elif input_lower.startswith("worship "):
            obj = self.extract_object(input_lower, ["worship"])
            return {"intent": "WORSHIP", "target": obj}
        elif input_lower.startswith("insult "):
            obj = self.extract_object(input_lower, ["insult"])
            return {"intent": "INSULT", "target": obj}
        elif input_lower == "dance badly":
            return {"intent": "DANCE_BADLY"}
        elif input_lower.startswith("stamp "):
            obj = self.extract_object(input_lower, ["stamp"])
            return {"intent": "STAMP", "target": obj}
        elif input_lower == "ask chicken for legal advice":
            return {"intent": "ASK_CHICKEN_LEGAL"}
        elif input_lower.startswith("queue"):
            return {"intent": "QUEUE"}
        elif input_lower.startswith("appeal "):
            obj = self.extract_object(input_lower, ["appeal"])
            return {"intent": "APPEAL", "target": obj}
        elif input_lower.startswith("audit"):
            return {"intent": "AUDIT"}
        elif input_lower.startswith("file "):
            obj = self.extract_object(input_lower, ["file"])
            return {"intent": "FILE", "target": obj}
        elif input_lower.startswith("complain") or input_lower.startswith("complaint"):
            return {"intent": "COMPLAINT"}
        elif input_lower.startswith("notarize "):
            obj = self.extract_object(input_lower, ["notarize"])
            return {"intent": "NOTARIZE", "target": obj}
        elif input_lower.startswith("deny "):
            obj = self.extract_object(input_lower, ["deny"])
            return {"intent": "DENY", "target": obj}
        elif input_lower.startswith("resubmit"):
            return {"intent": "RESUBMIT"}

        # Chapter 3: Department of Sustained Loss commands
        elif input_lower == "report loss":
            return {"intent": "REPORT_LOSS"}
        elif input_lower.startswith("surrender "):
            obj = self.extract_object(input_lower, ["surrender"])
            return {"intent": "SURRENDER", "item": obj}
        elif input_lower.startswith("reclaim "):
            obj = self.extract_object(input_lower, ["reclaim"])
            return {"intent": "RECLAIM", "item": obj}
        elif input_lower == "catalogue":
            return {"intent": "CATALOGUE"}
        
        # Special room commands
        if self.game_state.room and input_lower in self.game_state.room.get("special_commands", {}):
            return {"intent": "SPECIAL", "command": input_lower}
        
        # Fallback to unknown
        return {"intent": "UNKNOWN", "input": user_input}

    def extract_direction(self, input_str):
        """Extract direction from movement commands."""
        words = input_str.split()
        if len(words) == 1:
            return words[0]
        elif words[0] == "go":
            return words[1] if len(words) > 1 else ""
        return ""

    def extract_object(self, input_str, prefixes):
        """Extract object from command like 'take receipt'."""
        for prefix in prefixes:
            if input_str.startswith(prefix + " "):
                return input_str[len(prefix)+1:].strip()
        return input_str

    def normalize_object(self, obj):
        """Normalize object names (pronouns, etc.)."""
        if obj == "it" and self.game_state.last_object:
            return self.game_state.last_object
        return obj