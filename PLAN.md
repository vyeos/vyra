# Vyra Product Plan

## Product Direction

Vyra is a desktop control center focused on one core promise:

**Control your Mac from one place with fast commands and automation.**

Core product pillars:
- app launcher
- window management actions
- global hotkeys and custom key behavior (Hyper key style)
- theme manager as a feature

## Problem Statement

Users who rely on many apps and keyboard workflows lose time due to:
- too many launch and switch steps
- repetitive window arrangement work
- fragmented hotkey setups across tools
- theme changes spread across multiple app configs

Vyra solves this by acting as a single command and control layer for desktop workflows.

## Core Value Proposition

- One command surface to launch apps and run actions
- One place to manage windows quickly with shortcuts
- One system to configure global keys and custom key behavior
- One feature to sync themes across supported apps

## MVP Scope (v0.1)

### 1) App Launcher (Primary)
- Global shortcut to open Vyra command palette
- Search and launch installed apps quickly
- Pin favorites and recents

### 2) Window Management
- Quick actions for move/resize/snap
- Shortcut-driven layout actions
- Basic preset layouts for common workflows

### 3) Hotkeys + Key Behavior
- Register global shortcuts for:
  - open Vyra
  - launch favorite apps
  - run window/actions
- Basic custom key behavior mode (Hyper-like mapping)

### 4) Theme Manager (Feature)
- Let user create/select a theme profile (base palette + variants)
- Let user choose installed apps to connect
- Apply selected theme to connected apps through per-app adapters
- Show apply status (success/failure per app)

### 5) Basic Menubar Presence
- Menubar icon with:
  - quick launcher entry
  - common window actions
  - quick theme switch
  - open main app action

## Non-Goals for MVP

- Full productivity analytics dashboard
- Deep todo/project management
- Complex AI automation
- Cross-device sync and cloud accounts

## Suggested Connector Priority (Theme Feature)

Start with apps that are both popular and theme-configurable:
1. Terminal app (iTerm2 or Terminal-compatible path)
2. VS Code
3. One additional code editor/terminal
4. One browser-like target (if technically feasible)

Each connector should implement:
- read current theme/config
- write new values safely
- rollback or backup before overwrite

## Technical Strategy (High-Level)

- Command layer (core): launcher + actions + hotkeys
- Window actions module: move/resize/snap primitives
- Theme layer (feature): theme profile model + connector adapters
- UI layer: menubar + optional main window

Config updates should be:
- idempotent
- reversible (backup before changes)
- validated before write

## Rollout Phases

## Phase 1 - Foundation
- Build command palette + app launcher
- Implement global shortcut registration
- Implement initial window action primitives

## Phase 2 - Usable MVP
- Add favorites, recents, and key behavior settings
- Add basic menubar quick actions
- Add theme module with 2-3 connectors and quick switch

## Phase 3 - Workflow Expansion
- Add richer window presets and shortcut chaining
- Expand theme connectors to 5+ apps
- Add starter analytics (only if core usage is stable)

## Success Metrics

- App launch from command palette under 1 second median
- Common window action completion under 2 seconds
- Theme apply success rate above 95% on supported connectors
- Weekly active usage of launcher/hotkeys by early testers

## Immediate Next Tasks (Execution Checklist)

1. Finalize v0.1 command surface and non-goals
2. Build command palette with app launch action
3. Implement 5-8 core window actions
4. Add global shortcuts and key behavior settings
5. Add menubar quick actions
6. Implement theme connectors (start with 2-3 apps)
7. Run internal dogfooding on real daily workflows

