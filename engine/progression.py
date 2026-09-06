#!/usr/bin/env python3
# progression.py - Handle chapter progression and checkpoints

class Progression:
    def __init__(self, game_state):
        self.game_state = game_state

    def on_enter_room(self):
        """Called when entering a room."""
        room = self.game_state.room
        # Set flags on enter
        for flag in room.get("set_flags_on_enter", []):
            if flag.startswith("global:"):
                self.game_state.global_flags.add(flag[7:])
            elif flag.startswith("chapter:"):
                self.game_state.chapter_flags.add(flag[8:])
        
        # Check for chapter progression
        progress_value = room.get("chapter_progress_value", 0)
        if progress_value > 0:
            self.game_state.level_index += progress_value
            if self.game_state.level_index >= 10:  # Assuming 10 levels per chapter
                self.advance_chapter()

    def advance_chapter(self):
        """Advance to next chapter."""
        self.game_state.chapter += 1
        self.game_state.level_index = 1
        self.game_state.checkpoint = self.game_state.chapter
        self.game_state.chapter_flags.clear()
        # Unlock new commands based on chapter
        new_commands = self.get_chapter_commands(self.game_state.chapter)
        for cmd in new_commands:
            self.game_state.unlocked_commands.add(cmd)
        # Auto-save at checkpoint
        # self.save_system.save_checkpoint()

    def get_chapter_commands(self, chapter):
        """Get commands unlocked at chapter start."""
        chapter_commands = {
            1: ["eat random item"],
            2: ["stamp"],
            3: ["queue"],
            4: ["appeal"],
            5: ["audit"],
            6: ["befriend object"],
            7: ["scream at bureaucracy"],
            8: ["file false memory"],
            9: ["deny form"],
            10: ["clerk override"]
        }
        return chapter_commands.get(chapter, [])

    def check_win_condition(self):
        """Check if player has won."""
        return self.game_state.room["name"] == "Core" and self.game_state.chapter >= 10

    def check_failure_conditions(self):
        """Check for failure states."""
        if self.game_state.stats["health"] <= 0:
            return "death"
        if self.game_state.stats["hive_pressure"] >= 100:
            return "hive_absorbed"
        return None