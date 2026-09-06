# The Strawberry Omen

*A Breakroom Campaign of Moist Corporate Horror*

## How to Use This Module

This folder is both a book-shaped campaign source and an active Hive module. The Markdown is for reading and future PDF export. The JSON files are for runtime. Do not make the app scrape prose for game state; every playable scene, item, NPC, flag, and outcome has a stable ID.

## Campaign Overview

The party discovers Wetberry, the Breakroom Relic, standing upright on a communal table. The first problem is embarrassment. The second problem is that the label turns to face people. The third problem is that the relic is one of the Condiments of Collapse, a set of cursed workplace artifacts that can open the Employee Portal into the Moist Undercorporate.

## Core Relics

Wetberry governs awkward discovery. The Ancient Mayonnaise governs expiration denial. The Sentient Creamer governs false hospitality. The Forbidden Ranch governs overconfidence. The Breakroom Hot Sauce governs avoidable escalation.

## Act I: The Upright Omen

### Chapter Summary

The party enters the Breakroom of Inappropriate Discovery. Wetberry stands on the central table beside suspicious moisture. Darla of the Microwave, Keith the Janitor, and Tammy from HR can become allies, obstacles, or witnesses depending on the party's choices.

### Starting State

- Party location: Central Breakroom Table.
- Known facts: a strange upright product box is visible.
- Active relics: Wetberry.
- Locked areas: Fridge of Forgotten Things.
- Immediate threat: the social shock of being associated with the object.

### Read-Aloud Text

The breakroom is silent except for the fluorescent hum. In the center of the nearest table stands a small white carton. Its red strawberry glyphs gleam beneath the lights. Beside it, a suspicious wet mark reflects not the ceiling, but something pink and distant.

The coffee maker clicks on by itself.

The box turns slightly.

Roll initiative.

### Key Locations

#### Central Table

The central table is the ritual site for Act I. Wetberry begins here. The Aura of HR Proximity covers a ten-foot radius around it.

#### Coffee Counter

The coffee maker produces bitter prophecy. Darla appears here if the microwave is inspected or activated.

#### Fridge of Forgotten Things

Initially locked. Unlocks when the First Stain clue is recovered or when the party survives the First Memo encounter.

## Act II: The Fridge of Forgotten Things

### Chapter Summary

With the Fridge of Forgotten Things unlocked, the party ventures deeper into corporate horror. The ancient artifacts stored there have been waiting for millennia. Wetberry warned the party about the Condiments of Collapse, and now they face the most dangerous one of all: Ancient Mayonnaise, keeper of expired lunches and guardian of forbidden secrets.

### Starting State

- Party location: Central Table (must have completed Act I and unlocked Fridge)
- Known facts: Fridge is unlocked but still dangerous
- Active relics: Wetberry, Ancient Mayonnaise
- Locked areas: None
- Immediate threat: The emptiness inside the Fridge

### Read-Aloud Text

The breakroom hums with the memory of thousands of lunches. You step into the Fridge of Forgotten Things, where time bends around you. The walls are lined with jars of preserved moments, some still warm with dread. In the center stands Moldric, the Duke of the Back Shelf, guardian of everything that's been forgotten.

### Key Locations

#### Central Door Shelf

The entry point to the Fridge. This is where you make the first choices: approach Moldric, examine the marshes, or retreat.

#### Leftover Marshes

A swamp of discarded meals and mysterious bacterial growth. The Lunch Thief Goblins hide among the food cans.

#### Yogurt Catacombs

Towers of moldy yogurt containers, some still bubbly with ancient life. The Expired Yogurt Cultist guards the center.

#### Back Corner

The sacred back shelf where Moldric and Ancient Mayonnaise reside. This is the culmination of your journey.

#### Fridge Visions (Optional)

At any point while at the Door Shelf, the party may peer into the frost and witness the fridge's memories: fleeting visions of every lunch ever stored within. This optional scene reveals the depth of corporate neglect and sets the `act2_fridge_visions_seen` flag. The visions do not grant items or change outcomes, but they provide context for Moldric's grief and the fridge's purpose. The party may return to the Door Shelf or follow the visions directly to Moldric.

### Hive Runtime References

- campaign_id: strawberry_omen
- first_scene_id: scene.act1.first_sighting
- first_location_id: location.breakroom.central_table
- first_item_id: relic.wetberry

### Act II Summary

The journey through the Fridge is a test of whether you can navigate corporate horror without becoming corporate yourself. Each choice determines your path through the maze of forgotten things, and the final decision will either preserve Moldric's legacy or unleash something worse.

## Act III: The Vending Machine That Eats Names

### Chapter Summary

After completing Act II, the party discovers a hallway nobody remembers. At its end stands Vendrick, a sentient vending machine that demands payment in accountability instead of coins. The Snack Wraiths - phantom leftovers of forgotten lunches - guard the path. Only by facing them and offering genuine accountability can the party obtain the Accountability Token and complete Act III.

### Starting State

- Party location: Forgotten Hallway (behind the Fridge)
- Known facts: Vendrick exists, the Snack Wraiths are restless
- Active relics: Ancient Mayonnaise, Accountability Token (if obtained)
- Locked areas: None
- Immediate threat: The Snack Wraiths demand accountability for forgotten lunches

### Read-Aloud Text

The fluorescent lights flicker in a pattern that almost spells 'INSERT MEMORY.' A hallway stretches before you, its walls lined with faded motivational posters that have given up. At the far end, a vending machine glows with an otherworldly light.

Its display reads: 'INSERT MEMORY. RECEIVE TRUTH.'

The machine's coils begin to spin. A voice crackles from the speaker: 'I am Vendrick. I consume memories and dispense accountability. Name your price.'

### Key Locations

#### The Forgotten Hallway

A hallway nobody remembers, lined with motivational posters that have surrendered to entropy. The lights hum hold music. This is the threshold between corporate horror and corporate truth.

#### Vendrick's Domain

Vendrick the Vending Machine stands sentinel. His glass front displays snacks that never existed: 'Existential Crisps,' 'Bag of Unresolved Feelings,' 'Diet Denial.' He demands accountability, not coins.

#### Snack Wraith Aisle

Phantom snacks float through the air - translucent sandwiches, ghostly granola bars, spectral chips. They are the forgotten lunches of millennia, and they demand acknowledgment.

#### The Accountability Slot

A glowing slot where genuine accountability is deposited. It smells like honesty and regret. Those who pass through here are forever Accountable.

### Hive Runtime References

- campaign_id: strawberry_omen
- first_scene_id: scene.act1.first_sighting
- first_location_id: location.breakroom.central_table
- first_item_id: relic.wetberry

### Act III Summary

Act III is the final test of corporate character. Vendrick does not want coins or memories - he wants genuine accountability. The Snack Wraiths are the forgotten lunches of history, and they deserve to be acknowledged. Only by facing them honestly can the party prove they are Accountable.
