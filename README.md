# Hive-Lattice Bard

A text-based adventure game with Brother Ape flavored bureaucracy and weird commands.

## Project Structure

```
game/
  main.py                 # Main entry point
  engine/                 # Core game systems
    game_state.py         # Central state management
    parser.py             # Input parsing and intent normalization
    command_router.py     # Route intents to handlers
    world_loader.py       # Load world data from JSON
    save_system.py        # Save/load functionality
    progression.py        # Chapter and level progression
    combatless_resolution.py  # Resolve silly commands with consequences
    random_events.py      # Random events system
  content/                # Game content data
    rooms_ch01.json       # Chapter 1 rooms
    items.json            # Item definitions
    characters.json       # NPC definitions
    commands.json         # Command categories
    level_rules.json      # Progression rules
  writing/                # Flavor text and tables
    flavor_tables.json    # Generic flavor text
    bad_idea_results.json # Weighted result tables for silly commands
    ape_voice_lines.json  # Brother Ape voice responses
  tests/                  # Unit tests
    test_parser.py        # Parser tests
    test_room_graph.py    # Room connectivity tests
    test_progression.py   # Progression tests
```

## Running the Game

```bash
python main.py
```

## Development

This is a refactored version of the original prototype, split into a modular architecture for easier expansion to 100 nodes across 10 chapters.

### Key Features

- Intent-based command parsing
- JSON-driven world data
- Weighted consequence tables for silly commands
- Chapter-based progression
- Comprehensive save system
- Unit testing framework

### Adding New Content

1. **Rooms**: Add to `content/rooms_chXX.json` with the full schema
2. **Items**: Add to `content/items.json`
3. **Commands**: Add handlers in `command_router.py` and parsers in `parser.py`
4. **Consequences**: Add weighted tables to `writing/bad_idea_results.json`

### Testing

Run tests with:
```bash
python -m unittest discover tests/
```

## Architecture Overview

The game uses a layered architecture:

1. **GameState**: Central state holder
2. **World Data**: JSON-loaded content
3. **Parser**: Input → Intent normalization
4. **Command Router**: Intent → Handler resolution
5. **Content Rules**: Consequence tables and logic
6. **Testing**: Validation and reachability checks

This structure supports scaling to 100 authored nodes with mechanical depth.