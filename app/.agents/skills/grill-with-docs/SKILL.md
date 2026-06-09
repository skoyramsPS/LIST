---
name: grill-with-docs
description: >-
  Structured requirements interview for TheLIST. Challenges a feature idea or
  change against the existing architecture docs, locked decisions, and domain
  vocabulary before a PRD is written. Use at the START of a new feature, major
  change, or significant update — before /to-prd. Output feeds directly into
  to-prd; no files are written during the session.
---

# Grill With Docs — TheLIST

## Purpose

Turn a rough idea into precise, contradiction-free requirements — **before**
anyone writes a PRD. The output of this session is the input to `to-prd`.

This skill does **not** write files during the session. It does not create ADRs,
update glossaries, or modify architecture docs. Its sole output is a shared
understanding that the `to-prd` skill then captures. Decisions made during
implementation are recorded then, not during planning.

## Position in the workflow

```
grill-with-docs  →  to-prd  →  architect-review review-prd  →  to-tasks  → ...
```

Do not skip this step for anything non-trivial. A PRD written from an un-grilled
idea inherits the idea's ambiguities and contradictions. The architect-review
will find them — better to surface them here, in conversation, before they're
baked into a document.

## What "grilling" means here

This is not a friendly clarification session. It is a structured challenge. The
agent's job is to find the places where:

- The idea contradicts a locked decision in `AGENTS.md` or the architecture docs
- The idea is ambiguous against the domain vocabulary in `docs/architecture/`
- The idea conflicts with the layering rules in `AGENTS.md §2`
- The idea touches the sync engine or E2EE model in ways that haven't been
  thought through
- The idea is actually two ideas that need to be separated
- A non-goal in `PRD.md §4` is being smuggled in as a sub-feature

Finding one of these is a good session. Finding three is a great one.

## Before the first question

Read these before asking anything:

1. `AGENTS.md` — the non-negotiable constraints. Anything the idea violates is
   an immediate challenge, not a question.
2. `docs/architecture/index.md` — route to the specific architecture doc(s) the
   idea touches.
3. The relevant architecture doc(s) — understand the current shape of the system
   in the area being changed.
4. `docs/planning/active/the-list/PRD.md §4` — the explicit non-goals. Know them cold.

Do not start the interview from general first principles. Start from what this
project has already decided.

## How to run the session

**One question at a time.** Wait for an answer before asking the next. Do not
front-load five questions at once — the answers to early questions change what
the later questions should be.

**For each question, give your recommended answer.** Do not just probe — propose.
"I think the answer is X because of Y in the architecture docs — do you agree?"
This is faster and more useful than open-ended questions.

**If a question can be answered by reading the codebase or docs, read them
first.** Do not ask the human something the repo already answers.

**Challenge against the existing domain vocabulary.** When the human uses a term
that has a specific meaning in `docs/architecture/` (Sheet, Row, Cell, Column,
Reminder, AttentionItem, SyncTransport, Clock, AppTokens, template_kind,
semantic_role, position, sync_version, encrypted_payload, FakeClock,
FakeMemoryTransport, InMemoryDrift), use that term exactly. If they use a
different term for the same thing, flag it: "The architecture calls this a Cell —
are you describing a Cell, or something different?"

**Surface contradictions with locked decisions explicitly.** If the idea implies
something that conflicts with a decision in `AGENTS.md` or the architecture docs,
name the entry: "AGENTS.md §3 locks X — your proposal implies Y. Is this a
different case, or are you reopening that decision?" Only raise it if the
friction is real enough to warrant reopening.

**Probe the sync and E2EE implications.** Any feature that creates, reads,
updates, or deletes user data has sync implications. Any data that syncs has
E2EE implications. These are not optional considerations — they are core to the
project thesis. Ask:
- Does this data need to sync across devices? If yes, which table(s) does it
  touch, and does it carry the full sync contract (updated_at, deleted_at,
  encrypted_payload)?
- Does this data belong inside the encrypted_payload, or is it sync metadata?
  (Rule: anything the server must not read goes in the payload.)
- Does adding this feature change the convergence matrix? If two devices edit
  this simultaneously offline, what is the correct merged result?

**Probe the layering implications.** Which lib/ layers does this feature touch?
Does it require a new repository method? A new Riverpod provider? A new UI
component? Does anything about the proposed design require a shortcut across
layers? (If yes, the design is wrong — not the rule.)

**Probe the test implications.** How will this be tested? Which of the three
seams does it exercise (FakeClock, FakeMemoryTransport, InMemoryDrift)? Is there
a convergence matrix case that needs to be added?

## Finishing the session

The session is complete when:

- The feature is described precisely enough that `to-prd` can write it without
  asking any follow-up questions
- Every contradiction with locked decisions has been resolved or consciously
  deferred
- The sync, E2EE, layering, and testing implications are understood
- The scope boundary is clear — what is in, what is out

At the end, produce a **session summary** in the following structure. This is
the handoff document that `to-prd` works from:

```
## Grill Session Summary — <feature name>
**Date:** <today>

### What we're building
<1-3 sentences. Precise. Uses the project domain vocabulary.>

### Scope boundary
**In:** <what is included>
**Out:** <what is explicitly excluded — reference PRD non-goals where relevant>

### Sync and E2EE implications
<Which tables are touched. What goes in encrypted_payload vs plaintext metadata.
Convergence behaviour if two devices edit simultaneously.>

### Layering implications
<Which lib/ layers are touched. New repository methods, providers, or components
required.>

### Testing implications
<Which seams are exercised. Whether the convergence matrix needs a new case.>

### Locked decisions touched
<Any decisions in AGENTS.md or architecture docs that were relevant. Whether they
were confirmed, challenged, or consciously deferred.>

### Open questions (if any)
<Anything that could not be resolved in this session and must be decided during
implementation. Flag these — the architect-review will look for them.>
```

Hand this summary to `to-prd`. The PRD writes itself from this.
