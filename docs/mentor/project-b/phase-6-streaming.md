# Mentor — Phase 6 Streaming (capstone)

Developer: [phase-6-streaming-near-real-time.md](../../developer/project-b/exercises/phase-6-streaming-near-real-time.md)

**Ask:** Pull vs push comparison; AvailableNow default; streaming silver/gold with quarantine; freshness SLA; cost discipline; design note.

## Concepts they should explain unprompted

Push vs pull; micro-batch; watermark; delivery semantics; why continuous streams bypass auto-terminate; cost of NRT.

## Acceptance rubric

| Level | Looks like |
|-------|------------|
| **Strong** | Comparison table with measured latency; AvailableNow jobs; foreachBatch quarantine; freshness SLA; governance on new objects; capstone design note |
| **Adequate** | One working incremental path; honest cost discussion; stretch partially done |
| **Not yet** | Abandoned continuous stream; “incremental” only on static raw paths; no cost awareness |

## Operational safety (mentor actions)

| Symptom | Action |
|---------|--------|
| Cluster running overnight / streaming query forever | Cancel query; terminate cluster; check Jobs |
| Budget alert / high DBU | Stop Jobs; review `Trigger` settings; talk cost |
| Event Grid not firing | Confirm `incoming/` prefix; queue output; provider registered |

How to stop out of hours:

```bash
# Example — adjust host/auth
databricks clusters list -o json | jq '.[] | {id,state,cluster_name}'
# databricks clusters delete --cluster-id ...
databricks jobs list -o json | jq '.[].job_id'   # pause/delete as needed
```

## Red flags

- Continuous stream left running unsupervised
- Exactly-once claimed without idempotent sink
- Ignoring small-file / quarantine backlog topics in the design note

## Tiered hints

1. “Measure pull vs push with the same simulator drops.”
2. “AvailableNow is the default — justify anything else.”
3. “MERGE keys + checkpoints — what happens on replay?”

## Model answers

1. Listing cost/latency grows with file cardinality; notifications scale differently.
2. Notification ≠ end-to-end exactly-once; sink and checkpoints matter.
3. NRT buys freshness with always-on compute and ops complexity — economics decide.

## Stretch assessment

Design note quality (latency/cost/complexity/failure/1000×) outweighs a fragile always-on demo.
