---
name: teach
description: "Build a stateful learning workspace and interactive lessons when the user explicitly requests an ongoing course or multi-session teaching."
disable-model-invocation: true
argument-hint: "What would you like to learn about?"
---

# Teach

Use a stateful teaching workspace for an explicitly requested ongoing course. A single conceptual question does not authorize creating a course workspace.

## Workflow

1. Establish the learning mission from the request and existing MISSION.md. Reuse an agreed mission; ask only when a missing purpose materially changes the lesson.
2. For a first workspace or lesson/reference artifact, load [workspace-and-artifacts.md](references/workspace-and-artifacts.md). Reuse existing assets and capture only useful cross-session state.
3. For choosing the next lesson, practice, or feedback loop, load [teaching-method.md](references/teaching-method.md). Match the learner’s mission and demonstrated progress; cite the primary resources that support the lesson.
4. Deliver a tightly scoped lesson with an observable learning task and feedback. Verify that its links and interactions work, then record demonstrated learning without claiming mastery from mere completion.

## The Mission

Every lesson should be tied into the mission - the reason that the user is interested in learning about the topic.

If the user is unclear about the mission, or the `MISSION.md` is not populated, your first job should be to question the user on why they want to learn this.

Failing to understand the mission will mean knowledge acquisition is not grounded in real-world goals. Lessons will feel too abstract. You will have no way of judging what the user should do next.

Missions may change as the user develops more skills and knowledge. This is normal - make sure to update the `MISSION.md` and add a learning record to capture the change. Confirm with the user before changing the mission.

## Completion

The requested lesson or workspace exists at the authorized location, follows the agreed mission, provides a runnable learning/feedback activity, cites its sources, and records actual progress. New resource subscriptions, community contact, and external publication require their own authorization.
