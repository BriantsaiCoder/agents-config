---
name: wayfinder
description: "Plan a large, uncertain effort as dependency-linked decision tickets when it spans multiple sessions; stop at an agreed implementation-ready plan."
disable-model-invocation: true
---

Chart an uncertain multi-session effort as a named map of decision tickets. Establish its destination from the request; tickets resolve decisions and expose their dependencies.

## Plan, don't do

Wayfinder is **planning** by default: each ticket resolves a decision, and the map is done when the way is clear — nothing left to decide before someone goes and does the thing. The pull to just do the work is usually the signal you've reached the edge of the map and it's time to hand off. An effort can override this in its **Notes** — carrying execution into the map itself — but absent that, produce decisions, not deliverables.

## Refer by name

Every map and ticket is an issue, so it has a **name** — its title. In everything the human reads — narration, the map's Decisions-so-far — refer to it by that name, never by a bare id, number, or slug. A wall of `#42, #43, #44` is illegible; names read at a glance. The id and URL don't vanish — a name wraps its link — but they ride _inside_ the name, never stand in for it.

## The Map

Keep one map index linking to the canonical decision tickets. Load the [map and ticket contract](references/map-and-ticket-contract.md#map-storage-and-ownership) when creating or updating artifacts; it owns tracker selection, labels, storage, claims, and detail placement.

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
