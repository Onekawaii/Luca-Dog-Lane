# Hive-Lattice Bard

A surreal interactive text game built around bureaucracy, strange rituals, and Brother Ape flavored command chaos.

You move through authored chapters, manipulate paperwork, trigger absurd consequence tables, and push through a world where forms, queues, denials, goblins, chickens, and clerk logic all matter.

## Current State

This repository contains a modular Python text adventure engine with:

* data-driven chapter content
* intent-based parsing
* consequence-table driven special actions
* Chapter 1 vertical slice and Chapter 2 system wiring
* validation tools and path tests
* frozen content schemas for controlled expansion

## Project Goals

Hive-Lattice Bard is being built as a real interactive text game, not a fake sample sim.

The long-term target is a 100-node authored experience organized into chapters, with:

* multiple route styles
* bureaucracy-based progression
* absurd command interactions with real consequences
* recurring NPC memory and route reactivity
* testable chapter progression without softlocks

## Repository Structure

```text
content/
  rooms_ch01.json
  rooms_ch02.json
  rooms_ch03.json
  items.json
  characters.json
  commands.json
  level_rules.json
  templates/
    room_template.json
    character_template.json
    item_template.json
    consequence_table_template.json

engine/
  combatless_resolution.py
  command_router.py
  game_state.py
  parser.py
  progression.py
  random_events.py
  save_system.py
  validate_content.py
  world_loader.py

tests/
  test_chapter1_minimal_path.py
  test_chapter2_hybrid_path.py
  test_chapter2_lawful_path.py
  test_parser.py
  test_progression.py
  test_room_graph.py

tools/
  content_lint.py
  generate_chapter_shell.py

writing/
  ape_voice_lines.json
  bad_idea_results.json
  flavor_tables.json

main.py
README.md
ARCHITECTURE_FREEZE.md
SCHEMA_VERSIONS.md
SPRINT_SUMMARY.md
.gitignore
.gitattributes
```

## Running the Game

From the repository root:

```bash
python main.py
```

## Running Validation

Lint the content:

```bash
python tools/content_lint.py
```

Run the full test suite:

```bash
python -m unittest discover -s tests -p "test*.py"
```

Run the spine tests directly:

```bash
python tests/test_chapter1_minimal_path.py
python tests/test_chapter2_lawful_path.py
python tests/test_chapter2_hybrid_path.py
```

## Design Pillars

### 1. Data-driven content

Rooms, items, characters, and progression rules are authored outside the core engine so chapters can scale without turning the codebase into a swamp.

### 2. Parser to intent flow

Player input is normalized into intents and routed through command handlers instead of being trapped in one giant monolithic parse loop.

### 3. Consequence tables

Special actions such as screaming, filing, stamping, queuing, or asking a chicken for legal advice are resolved through weighted rule tables with actual state changes.

### 4. Freeze before scale

Schemas, validation, and chapter structure are being locked before large-scale chapter expansion. No schema drift. No decorative growth.

## Current Chapter Focus

### Chapter 1

The introductory vertical slice. It establishes movement, item interactions, bureaucracy flavor, and weird-command behavior.

### Chapter 2

Frank and the Necessary Denials. This chapter introduces systemic Frank reputation, filing status, queue logic, appeals, and route differences between lawful, ape-chaos, and hybrid play.

## Development Workflow

1. Author content using the frozen templates.
2. Validate content with `content_lint.py`.
3. Run spine tests.
4. Add or harden mechanics.
5. Only then expand chapters.

## Roadmap

* finish Chapter 2 route polish
* strengthen Frank reputation reactivity
* complete Chapter 2 end-state reporting
* expand Chapter 3 from shell to authored content
* continue chapter-by-chapter until full 100-node structure is complete

## Notes

This project is intentionally weird, but the architecture is meant to stay disciplined.

Small knife. Sharp edge.
