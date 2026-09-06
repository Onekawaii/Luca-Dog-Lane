# Strawberry Omen Integration

This upgrade adds a campaign-module layer beside the original Hive-Lattice Bard adventure. The module is deliberately book-shaped and runtime-shaped at the same time:

- `campaign.book.md` is the readable source for future PDF/manual export.
- `game/*.json` is the active runtime data.
- `assets/**/*.placeholder.md` records missing art prompts without blocking implementation.
- `play_strawberry.py` runs the first playable vertical slice.

## Commands

```bash
python tools/validate_campaign_module.py
python play_strawberry.py
python -m unittest discover -s tests
```

## Rule

Do not move logic into prose. Prose can be beautiful. JSON must be authoritative for gameplay.
