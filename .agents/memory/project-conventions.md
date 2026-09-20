---
type: project
created: 2026-05-25
updated: 2026-08-18
---

# Project Conventions

## Git Workflow
- Always create a new dedicated branch for major code changes.
- Branch name format should follow: `feature/[task-slug]` or `fix/[bug-slug]`.

## Supported AI platforms (AG Kit)
- AG Kit **only supports Gemini CLI and Google Antigravity**.
- Do not claim compatibility with Claude Code, Cursor, Copilot, Windsurf, or other assistants unless the user explicitly expands scope.
- Copy on the website, docs, FAQ, README, and marketing should describe AG Kit as a toolkit for Gemini CLI / Antigravity-style agent setups.

## Riverpod Best Practices
- **Never use `late final` for injected variables inside `build()`**: In Riverpod `Notifier` or `AsyncNotifier` classes, the `build()` method executes every time the provider is refreshed or invalidated. If a variable is declared as `late final` (e.g., `late final FirebaseAuth _firebaseAuth`) and assigned inside `build()`, any invalidation will trigger a second assignment attempt, leading to a `LateInitializationError`. Always use standard `late` variables (e.g., `late FirebaseAuth _firebaseAuth`) or compute dependencies via getters.
- **Stream + Controller Pattern for Detail Pages**: For screens observing a real-time Firestore stream (such as `Appointment` document by ID) that also perform transactional actions, separate the stream into a `StreamProvider.family` and the mutations into an imperative `Controller` class (exposed via a standard `Provider`). This avoids Riverpod 2.x family notifier binding complexities while keeping business logic decoupled from UI widgets.
