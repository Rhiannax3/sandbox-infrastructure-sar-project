#!/usr/bin/env python3
"""
Deterministic SAR seed-data generator for Project B.

Produces JSON/CSV/JSONL files with deliberate anomalies for Silver-layer
data-quality challenges. See docs/mentor/anomaly-map.md.
"""

from __future__ import annotations

import argparse
import csv
import json
import random
from datetime import UTC, datetime, timedelta
from pathlib import Path

DOCUMENT_TYPES = [
    "user_profile_summary",
    "user_activity_report",
    "user_consent_log",
]
PRIORITIES = ["low", "medium", "high", "critical"]
STATUSES = [
    "submitted",
    "in_progress",
    "pending_approval",
    "fulfilled",
    "rejected",
    "cancelled",
]
OFFICERS = [
    {"officer_id": "OFF-001", "name": "Sam Standard", "role": "standard_officer"},
    {"officer_id": "OFF-002", "name": "Alex Senior", "role": "senior_officer"},
    {"officer_id": "OFF-003", "name": "Jordan Lee", "role": "standard_officer"},
    {"officer_id": "OFF-004", "name": "Casey Ng", "role": "senior_officer"},
]


def daterange(rng: random.Random, start: datetime, days: int) -> datetime:
    return start + timedelta(days=rng.randint(0, days), hours=rng.randint(0, 23), minutes=rng.randint(0, 59))


def write_json(path: Path, rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(rows, handle, indent=2, ensure_ascii=False)
        handle.write("\n")


def write_jsonl(path: Path, rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        for row in rows:
            handle.write(json.dumps(row, ensure_ascii=False) + "\n")


def write_csv(path: Path, rows: list[dict], fieldnames: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def generate(out: Path, seed: int = 42) -> None:
    rng = random.Random(seed)
    start = datetime(2024, 1, 1, 9, 0, 0)

    # --- Officers (clean reference) ----------------------------------------
    write_csv(
        out / "reference" / "officers.csv",
        OFFICERS,
        ["officer_id", "name", "role"],
    )

    # --- SAR requests (JSON) with anomalies --------------------------------
    requests: list[dict] = []
    request_ids: list[str] = []

    for i in range(1, 121):
        req_id = f"SAR-2024-{i:04d}"
        request_ids.append(req_id)
        created = daterange(rng, start, 400)
        status = rng.choice(STATUSES)
        completed = None
        if status in {"fulfilled", "rejected", "cancelled"}:
            completed = (created + timedelta(days=rng.randint(1, 45))).isoformat()

        officer = rng.choice(OFFICERS)
        doc_type = rng.choice(DOCUMENT_TYPES)

        record = {
            "request_id": req_id,
            "document_type": doc_type,
            "requestor_id": officer["officer_id"],  # will drift later
            "subject_id": f"SUBJ-{rng.randint(10000, 99999)}",
            "priority": rng.choice(PRIORITIES),
            "status": status,
            "sla_days": rng.choice([7, 14, 30]),
            "created_at": created.isoformat(),
            "completed_at": completed,
            "channel": rng.choice(["portal", "email", "phone"]),
        }

        # --- Inject anomalies on selected rows -----------------------------
        if i == 10:
            # Exact duplicate of previous shape (same request_id later)
            pass
        if i == 11:
            record["request_id"] = "SAR-2024-0010"  # exact duplicate ID
        if i == 12:
            record["request_id"] = "SAR-2024-0010 "  # near-duplicate (trailing space)
        if i == 20:
            record["subject_id"] = None  # null mandatory field
        if i == 21:
            record["priority"] = "HIGH"  # enum casing drift
        if i == 22:
            record["status"] = "In_Progress"  # enum casing drift
        if i == 30:
            # Mixed date format (date only)
            record["created_at"] = created.strftime("%Y-%m-%d")
        if i == 31:
            record["created_at"] = created.strftime("%d/%m/%Y %H:%M")
        if i == 40:
            record["sla_days"] = "thirty"  # type drift
        if i == 50:
            # completed_at before created_at
            record["completed_at"] = (created - timedelta(days=3)).isoformat()
            record["status"] = "fulfilled"
        if i == 60:
            record["requestor_id"] = "OFF-999"  # orphan officer
        if i >= 80:
            # Schema drift mid-timeline: priority retained, rename requestor_id
            record["priority"] = record.get("priority", "medium")
            record["requester_id"] = record.pop("requestor_id")
        if i == 90:
            record["subject_name"] = "José García".encode("latin-1").decode("latin-1")
            # Force a name that often breaks naïve UTF-8 assumptions when re-encoded
            record["subject_name_raw"] = "Jos\xe9 Garc\xeda"

        requests.append(record)

    # Truncated / malformed JSON record written as a separate broken file
    write_json(out / "sar_requests" / "requests_2024.json", requests)

    broken = out / "sar_requests" / "requests_2024_tail_truncated.json"
    broken.parent.mkdir(parents=True, exist_ok=True)
    with broken.open("w", encoding="utf-8") as handle:
        handle.write('[{"request_id":"SAR-2024-BROKEN","document_type":"user_profile_summary","status":"submitted"')
        # deliberately not closed

    # --- Status events (CSV) -----------------------------------------------
    events = []
    for req_id in request_ids[:100]:
        base = daterange(rng, start, 400)
        events.append(
            {
                "event_id": f"EVT-{rng.randint(100000, 999999)}",
                "request_id": req_id,
                "from_status": "submitted",
                "to_status": rng.choice(STATUSES),
                "changed_at": base.isoformat(),
                "changed_by": rng.choice(OFFICERS)["officer_id"],
            }
        )
    # Duplicate event
    events.append(dict(events[0]))
    # Null changed_by
    events.append(
        {
            "event_id": "EVT-NULL-ACTOR",
            "request_id": request_ids[5],
            "from_status": "submitted",
            "to_status": "in_progress",
            "changed_at": start.isoformat(),
            "changed_by": "",
        }
    )
    write_csv(
        out / "events" / "status_events.csv",
        events,
        ["event_id", "request_id", "from_status", "to_status", "changed_at", "changed_by"],
    )

    # --- API / system logs (JSONL) -----------------------------------------
    logs = []
    for i in range(200):
        ts = daterange(rng, start, 400)
        status_code = rng.choices([200, 201, 400, 401, 403, 404, 500, 503], weights=[50, 10, 8, 5, 5, 7, 10, 5])[0]
        logs.append(
            {
                "timestamp": ts.isoformat(),
                "request_id": rng.choice(request_ids + [None, ""]),
                "method": rng.choice(["GET", "POST", "PUT", "DELETE"]),
                "path": rng.choice(["/requests", "/requests/{id}", "/health", "/approve"]),
                "status_code": status_code,
                "latency_ms": rng.randint(20, 5000),
                "error_code": None if status_code < 400 else rng.choice(["VALIDATION", "AUTH", "TIMEOUT", "INTERNAL"]),
            }
        )
    # One log with mixed timestamp format
    logs[3]["timestamp"] = datetime(2024, 6, 1, 12, 0, 0).strftime("%d-%m-%Y %H:%M:%S")
    write_jsonl(out / "logs" / "api_access.jsonl", logs)

    # Manifest for mentors / ingestion
    manifest = {
        "generator": "seed-data/generator/generate.py",
        "seed": seed,
        "generated_at": datetime.now(UTC).isoformat().replace("+00:00", "Z"),
        "files": sorted(str(p.relative_to(out)) for p in out.rglob("*") if p.is_file() and p.name != "manifest.json"),
        "record_counts": {
            "requests": len(requests),
            "events": len(events),
            "logs": len(logs),
            "officers": len(OFFICERS),
        },
    }
    with (out / "manifest.json").open("w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2)
        handle.write("\n")

    print(f"Wrote seed data to {out} (seed={seed})")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()
    generate(args.out, args.seed)


if __name__ == "__main__":
    main()
