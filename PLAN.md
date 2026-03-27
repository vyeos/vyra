# Vyra Product Plan

## Product Direction

Vyra is a desktop control center focused on one core promise:

**Control your Mac from one place with fast commands and automation.**

Core product pillars:
- app launcher
- window management actions
- global hotkeys and custom key behavior (Hyper key style)
- record/replay macros for repeatable workflows
- theme manager as a feature

## Problem Statement

Users who rely on many apps and keyboard workflows lose time due to:
- too many launch and switch steps
- repetitive window arrangement work
- fragmented hotkey setups across tools
- theme changes spread across multiple app configs

Vyra solves this by acting as a single command and control layer for desktop workflows.

## Core Value Proposition

- One command surface to launch apps, open files, and run actions
- One place to manage windows quickly with shortcuts
- One system to configure global keys and custom key behavior
- One macro recorder to automate repeated multi-app setup flows
- One feature to sync themes across supported apps

## MVP Scope (v0.1)

### 1) App Launcher (Primary)
- Global shortcut to open Vyra command palette
- Search and launch installed apps quickly
- Pin favorites and recents
- Search and open files quickly (recent + indexed)
- Pin frequently used files and folders

### 2) Window Management
- Quick actions for move/resize/snap
- Shortcut-driven layout actions
- Basic preset layouts for common workflows

### 3) Hotkeys + Key Behavior
- Register global shortcuts for:
  - open Vyra
  - launch apps
  - run window/actions
- Basic custom key behavior mode (Hyper-like mapping)

### 4) Macro Recorder + Runner (Core Feature)
- Start and stop macro recording from Vyra
- Capture actionable events:
  - app launches/focus changes
  - Vyra window management actions
  - supported in-app keystrokes and commands
- Save macro with a name and replay via shortcut or command palette
- Show replay step status and failures (for debugging and trust)

### 5) Theme Manager (Feature)
- Let user create/select a theme profile (base palette + variants)
- Let user choose installed apps to connect
- Apply selected theme to connected apps through per-app adapters
- Show apply status (success/failure per app)

### 6) Basic Menubar Presence
- Menubar icon with:
  - quick launcher entry
  - common window actions
  - start/stop macro recording
  - quick theme switch
  - open main app action

## Non-Goals for MVP

- Complex AI automation
- Cross-device sync and cloud accounts
- Full universal in-app keystroke capture for every app (MVP supports selected apps only)

## Suggested Connector Priority (Theme Feature)

Start with apps that are both popular and theme-configurable:
1. Terminal app (iTerm2, Ghostty, Alacritty or Terminal-compatible path)
2. VS Code, Zed

Each connector should implement:
- read current theme/config
- write new values safely
- rollback or backup before overwrite

## Technical Strategy (High-Level)

- Command layer (core): launcher + actions + hotkeys
- Window actions module: move/resize/snap primitives
- Macro engine: event timeline, recorder, replayer, and step status
- Theme layer (feature): theme profile model + connector adapters
- UI layer: menubar + main window

Config updates should be:
- idempotent
- reversible (backup before changes)
- validated before write

Macro execution should be:
- deterministic (ordered step playback)
- interruptible (stop macro safely)
- resilient (retry/skip policy per step)

## Example Macro Use Case

Developer startup workspace:
1. user starts macro recording
2. open browser and tile left
3. open terminal and tile right
4. split terminal horizontally
5. run `nvim` on top pane and local server command on bottom pane

Result: user can replay this setup with one hotkey.

## Rollout Phases

## Phase 1 - Foundation
- Build command palette + app launcher
- Add file search/open support in command palette
- Implement global shortcut registration
- Implement initial window action primitives
- Define macro step schema and persistent storage format

## Phase 2 - Usable MVP
- Add favorites, recents, and key behavior settings
- Add basic menubar quick actions
- Ship macro record/replay for desktop and window actions
- Add theme module with 2-3 connectors and quick switch

## Phase 3 - Workflow Expansion
- Add richer window presets and shortcut chaining
- Add selected in-app macro actions (terminal/editor-first)
- Expand theme connectors to 5+ apps

## Success Metrics

- App launch from command palette under 1 second median
- File open from command palette under 1.5 seconds median
- Common window action completion under 2 seconds
- Macro replay success rate above 90% for recorded supported steps
- Theme apply success rate above 95% on supported connectors

## Immediate Next Tasks (Execution Checklist)

1. Finalize v0.1 command surface and non-goals
2. Build command palette with app launch + file open actions
3. Implement 5-8 core window actions
4. Add global shortcuts and key behavior settings
5. Define macro event model and recording boundaries
6. Implement macro record/replay for launcher + window actions
7. Add menubar quick actions (including macro controls)
8. Implement theme connectors (start with 2-3 apps)
9. Run internal dogfooding on real daily workflows

