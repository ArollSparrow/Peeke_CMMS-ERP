# Peeke CMMS-ERP

**Peeke™** CMMS-ERP — clean-slate Riverpod app (greenfield workspace).

> Repo name on GitHub: `Peeke_CMMS-ERP` (spaces are not allowed in repository names).

## Purpose

New development baseline for a full Riverpod architecture without carrying legacy patterns from the current production app.

| Repo | Role |
|------|------|
| [`ArollSparrow/Peeke`](https://github.com/ArollSparrow/Peeke) | Production CMMS-ERP (current) |
| **`ArollSparrow/Peeke_CMMS-ERP`** | Clean-slate Riverpod app (this repo) |

## Principles

- **Riverpod-first** state (AsyncNotifier / Notifier, families, code-gen where useful)
- Port features deliberately; no forced parity until ready
- Agent branches: `*_grok`
- Strategy and implementation land here first

## Status

Seeded. Flutter + Riverpod scaffold and migration strategy next.
