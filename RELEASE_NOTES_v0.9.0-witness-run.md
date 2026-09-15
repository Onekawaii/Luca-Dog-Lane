# Hive-Lattice v0.9.0 — Witness Run

This release turns the first-person prototype into a bounded, completable campaign journey.

## Player journey

- Boot through the native title screen and choose a persistent witness slot.
- Resolve the Wetberry containment problem in the authored breakroom.
- Open the east service exit and enter the streamed Lattice.
- Traverse twelve named main sectors.
- Explore two optional side chambers per sector (24 total).
- Record optional physical Witness Echoes that persist in the save.
- Reach THE LATTICE and use the physical completion terminal.
- Close the witness record, save the completion state, and reach an ending screen.
- Return to title or re-enter the completed world.

## World expansion

The streamed route now contains at least 49 materialized cells: the breakroom portal/spine, twelve main sectors, inter-sector transit cells, and 24 lateral exploration chambers. Each side chamber contains a deterministic optional Witness Echo.

The final sector no longer opens into unsupported void space. It terminates at a physical wall and completion terminal.
## Release hardening

- Windows and Android export metadata now agree on version 0.9.0.
- Android versionCode is 9.
- BUILD_NATIVE_PC.ps1 now treats Android export failure as fatal rather than printing a false suite success.
- Packaging now fails when mandatory Windows or Android artifacts are missing.
- `tools/write_release_receipt.py` produces an exact-head artifact receipt with SHA-256 hashes, ZIP integrity checks, and Android signature verification.

## Qualification target

A release is not complete until the exact committed head passes the native contract, exports Windows and Android artifacts, packages the source and Windows bundle, verifies the APK signature, writes checksums/receipt, and publishes retrievable artifacts.

The procedural route is a playable campaign architecture, not a claim that every sector is final hand-authored production art. That remains future content work rather than being mislabeled as release verification.
