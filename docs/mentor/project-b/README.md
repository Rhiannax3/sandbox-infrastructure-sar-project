# Project B — Mentor facilitation guide

**Mentor only.** Do not share this folder with juniors before they attempt the matching developer exercises.

Developer path: [docs/developer/project-b/exercises/](../../developer/project-b/exercises/README.md)  
Programme intent: [programme-briefing.md](../../developer/programme-briefing.md) §4  
Defect key: [anomaly-map.md](../anomaly-map.md)

## Coaching stance

- **Concept before syntax.** If they cannot explain *why*, they are not done — even if the notebook runs.
- **Mentorship over prescriptiveness.** Point to docs and contracts; resist pasting full solutions.
- **Discovery before reveal.** Especially Phase 2: let them profile before opening the anomaly map.
- **Stretch is design-heavy.** Score reasoning and trade-offs above clever code.

## Reveal discipline

| Material | When to reveal |
|----------|----------------|
| [anomaly-map.md](../anomaly-map.md) | After Layer A defect list in Phase 2 (or if stuck >1 mentoring session) |
| This folder’s phase rubrics | Never as a handout; use live at checkpoints |
| Expected row counts | Use to sanity-check; do not publish as a target list up front |

## Checkpoint cadence

Walk each phase’s **You are done when** list. Typical rhythm:

1. Vocabulary check (concepts unprompted)
2. Artefact review (tables / grants / dashboard / design note)
3. Red-flag scan (below in each phase file)
4. Stretch status (done / deferred / in progress)
5. Explicit go/no-go to next phase

## Competency mapping (briefing goals)

| Programme goal | Where it shows up |
|----------------|-------------------|
| Technical vocabulary | Every phase “concepts they can explain” |
| Engineering confidence | Stretch challenges; Phase 6 judgements |
| Architectural knowledge | C1/C2 in overview; Kimball; push vs pull; governance split |
| Incremental complexity | Bronze → … → streaming retrofit |

## Environment reset between phases

Safe:

- `DROP SCHEMA … CASCADE` for a layer they want to rebuild (agree first)
- Re-run seed apply only if blobs corrupted (`make apply-b`) — same static paths
- Stop Jobs / streaming queries; terminate clusters

Avoid mid-phase:

- Re-applying Terraform during Phase 5 (catalog grants are authoritative — can confuse)
- Deleting the workspace / catalog to “start clean” unless full reprovision is intended

## Phase files

| Phase | Mentor file | Developer file |
|-------|-------------|----------------|
| 1 | [phase-1-bronze.md](./phase-1-bronze.md) | [phase-1-bronze-ingestion.md](../../developer/project-b/exercises/phase-1-bronze-ingestion.md) |
| 2 | [phase-2-silver.md](./phase-2-silver.md) | [phase-2-silver-quality.md](../../developer/project-b/exercises/phase-2-silver-quality.md) |
| 3 | [phase-3-gold.md](./phase-3-gold.md) | [phase-3-gold-dimensional-model.md](../../developer/project-b/exercises/phase-3-gold-dimensional-model.md) |
| 4 | [phase-4-platinum.md](./phase-4-platinum.md) | [phase-4-platinum-business-logic.md](../../developer/project-b/exercises/phase-4-platinum-business-logic.md) |
| 5 | [phase-5-governance.md](./phase-5-governance.md) | [phase-5-governance-rbac.md](../../developer/project-b/exercises/phase-5-governance-rbac.md) |
| 6 | [phase-6-streaming.md](./phase-6-streaming.md) | [phase-6-streaming-near-real-time.md](../../developer/project-b/exercises/phase-6-streaming-near-real-time.md) |

## Pre-handover verification (as a *non-admin* data-engineer)

After `make apply-b` with new infra:

1. SQL warehouse query succeeds (`CAN_USE`)
2. Cluster create only via cost-capped policy (`allow_cluster_create` false)
3. `LIST` landing, external, checkpoints
4. Create schema / function / volume in catalog
5. Drop file under `incoming/` → queue message (Event Grid path)
