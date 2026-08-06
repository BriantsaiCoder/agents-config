# Skill mechanics

Load this branch only when the target is an Agent Skill.

## Invocation

- Apply [Model-Invoked](GLOSSARY.md#model-invoked) when discovery is required: keep a trigger-rich `description`, omit `disable-model-invocation`, and enable every host's implicit-invocation key.
- Apply [User-Invoked](GLOSSARY.md#user-invoked) for deliberate manual reach: keep a short human-facing `description`, set `disable-model-invocation: true`, and disable every host invocation key the folder carries, including `allow_implicit_invocation: false` in `agents/openai.yaml`.

Model invocation includes direct user reach. User-only invocation removes agent discovery and therefore cannot be activated by another skill.

## Description

State identity and one real trigger per [Branch](GLOSSARY.md#branch). Start with words users actually use, collapse synonyms that name the same branch, and add a reach clause only when another skill needs it. Describe the trigger, not the post-invocation procedure.

## Granularity and routers

Use the [Granularity](GLOSSARY.md#granularity) and [Router Skill](GLOSSARY.md#router-skill) tests. Split by invocation only for an independently triggered or reached branch. Split by sequence only when an observed rush survives a sharper completion criterion. Otherwise keep one skill. Several hard-to-remember user-only skills justify one user-only router; it never bypasses explicit-only metadata.
