# Mentor — Phase 3 Gold

Developer: [phase-3-gold-dimensional-model.md](../../developer/project-b/exercises/phase-3-gold-dimensional-model.md)

**Ask:** Kimball star with declared grains; facts + dims; naming conventions.

## Concepts they should explain unprompted

Grain; fact vs dim; surrogate vs natural key; conformed dim; SCD types (at least 1 vs 2).

## Acceptance rubric

| Level | Looks like |
|-------|------------|
| **Strong** | Written grains; dims + 3 facts; naming; Q1–6 join sketches; CDF/MERGE attempt or clear design; SCD2 or accumulating snapshot stretch |
| **Adequate** | Star exists; grains mostly right; can answer ≥2 questions via joins |
| **Not yet** | Undeclared grain; officer name on fact as only “model”; silver copied and renamed |

## Expected shapes

- `dim_officer` ~ 4 rows (unless SCD2 history grows)
- Facts only from **clean** silver (no quarantined requests)

## Red flags

- Undeclared grain
- Degenerate mess: everything in one wide table called `fact`
- Joining to bronze for “convenience”

## Tiered hints

1. “Say the grain sentence before CREATE TABLE.”
2. “Which attributes change slowly and are shared across facts?”
3. “SCD2 needs effective dating / current flag — show a role change.”

## Model answers

1. Grain example: “one row per SAR request (current state) as of load.”
2. Officer name on dim — facts stay numeric/keys; names change independently.
3. SCD2 when history of role/attribute matters for as-of analysis.

## Stretch assessment

Prefer a clear accumulating-snapshot design note over a half-broken SCD2 implementation.
