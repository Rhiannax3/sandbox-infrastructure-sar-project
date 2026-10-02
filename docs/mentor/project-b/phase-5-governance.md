# Mentor — Phase 5 Governance

Developer: [phase-5-governance-rbac.md](../../developer/project-b/exercises/phase-5-governance-rbac.md)

**Ask:** Schema/table grants; analysts denied bronze/silver; evidence matrix; optional masking/tags.

## Concepts they should explain unprompted

UC hierarchy; least privilege; ownership; why catalog grants stay platform-owned.

## Acceptance rubric

| Level | Looks like |
|-------|------------|
| **Strong** | Grants on gold/platinum; deny evidence for bronze/silver; matrix filled; masking/tags stretch |
| **Adequate** | Correct allow/deny for main personas; some table-level gaps OK |
| **Not yet** | Analysts can SELECT bronze; only workspace assignment discussed; catalog GRANT fight with Terraform |

## Red flags

- Re-running `make apply-b` mid-phase then confusion about vanished catalog grants
- Granting `USE_CATALOG` and assuming that implies table SELECT

## Tiered hints

1. “Show `SHOW GRANTS` on bronze vs gold.”
2. “Workspace USER ≠ UC SELECT.”
3. “Mask with a view owned by engineers; grant SELECT on the view only.”

## Model answers

1. Platform keeps authoritative catalog baseline; engineer changes at catalog level get clobbered.
2. Assignment puts identity in the workspace; UC privileges control data.
3. Need USE_SCHEMA + SELECT (and USE_CATALOG) on the path to the table.

## Stretch assessment

Evidence of mask behaviour matters more than fancy ABAC.
