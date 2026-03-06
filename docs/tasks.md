# Task Engine and Persistence

Protocol Widget uses a straightforward task engine tuned for daily protocol execution.

## Conceptual Model

Each task tracks:

- Identity and ordering within the protocol.
- Planning metadata (optional targets/time fields).
- Runtime state and accumulated elapsed time.
- Completion semantics.

## Task Status and Time

At a high level, a task moves through states such as:

- Running
- Paused
- Done

Runtime controls update timestamps/accumulated duration so progress can be resumed and completed consistently.

## Control Column Responsibilities

The control column provides direct execution controls for the active workflow, including actions such as:

- Start/Resume
- Pause
- Done

This allows fast keyboard/mouse interaction without leaving the main protocol view.

## Data Persistence with Isar

Tasks and settings are stored locally in Isar:

- Data is persisted on-device (local-first behavior).
- App startup opens a singleton Isar instance.
- Task updates are committed via Isar write transactions.
- Lifecycle recovery paths can reset and reopen DB handles when needed.

## Known Issues / Backlog

- Add Task sometimes requires a second confirm.

[Back to Docs Home](index.md)
