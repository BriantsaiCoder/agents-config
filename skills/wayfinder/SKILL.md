---
name: wayfinder
description: "Plan a large, uncertain effort as dependency-linked decision tickets when it spans multiple sessions; stop at an agreed implementation-ready plan."
disable-model-invocation: true
---

A loose idea has arrived — too big for one agent session, and wrapped in fog: the way from here to the **destination** isn't visible yet. Wayfinding is about finding that way, not charging at the destination. This skill charts the way as a **shared map** on the repo's issue tracker, then works its **decision tickets** — questions whose resolution is a decision, not slices of a build to execute — one at a time until the route is clear.

The destination varies per effort, and naming it is the first act of charting — it shapes every ticket. It might be a spec to hand off and iterate on, a decision to lock before planning starts, or a change made in place like a data-structure migration. The map is domain-agnostic — engineering work, course content, whatever fits the shape.

## Plan, don't do

Wayfinder is **planning** by default: each ticket resolves a decision, and the map is done when the way is clear — nothing left to decide before someone goes and does the thing. The pull to just do the work is usually the signal you've reached the edge of the map and it's time to hand off. An effort can override this in its **Notes** — carrying execution into the map itself — but absent that, produce decisions, not deliverables.

## Refer by name

Every map and ticket is an issue, so it has a **name** — its title. In everything the human reads — narration, the map's Decisions-so-far — refer to it by that name, never by a bare id, number, or slug. A wall of `#42, #43, #44` is illegible; names read at a glance. The id and URL don't vanish — a name wraps its link — but they ride _inside_ the name, never stand in for it.

## The Map

The map is a single issue on this repo's issue tracker, labelled `wayfinder:map` — the canonical artifact. Its tickets are child issues of the map.

The map is an **index**, not a store. It lists the decisions made and points at the tickets that hold their detail; a decision lives in exactly one place — its ticket — so the map never restates it, only gists it and links.

**Where the map, its child tickets, blocking, and frontier queries physically live is tracker-specific.** The tracker contract belongs to repo `docs/agents/issue-tracker.md`, then the shared fallback under `dev-workflow` INT-5. Setup runs only on explicit request. Consult the tracker doc's "Wayfinding operations" section for how _this_ repo expresses them. If no tracker has been provided, default to the local-markdown tracker.

The [map and ticket contract](references/map-and-ticket-contract.md) owns artifact shape, claim semantics, blocking relationships, and context pointers. Load it when creating or updating the map.


## Decision model

[Decision frontier](references/decision-frontier.md) owns HITL/AFK ticket types, fog versus precise tickets, and out-of-scope decisions. Load it when selecting, classifying, or resolving a decision. A live human exchange remains required for HITL unless the user explicitly delegates that decision under the calling contract.


## Invocation

Two modes share the same authorization boundary. Continue through the authorized frontier while relevant context remains available; a required user decision or missing authorization pauses only its dependent ticket. Use the canonical continuation contract for context transitions.

### Chart the map

For a loose multi-session idea, use [chart-map.md](references/chart-map.md). Record the destination and actionable frontier, preserving the authorization boundary for tracker writes and follow-on work.


### Work through the map

For an existing map, use [resolve-ticket.md](references/resolve-ticket.md). Claim an eligible ticket, resolve it with evidence, and update only the authorized tracker scope.

## Completion

The requested chart or decision is delivered, every resolved decision has one canonical owner, and the frontier reflects remaining dependencies. Continue authorized work while context permits; user-only decisions, unavailable capability, or missing authorization pause only the dependent ticket. Planning alone does not authorize production implementation, credentials, provisioning, or external publication.
