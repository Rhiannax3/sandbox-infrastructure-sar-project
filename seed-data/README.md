# Seed data

Deterministic sample SAR operational data for Project B.

```bash
make seed-data
# or
python3 seed-data/generator/generate.py --out seed-data/out --seed 42
```

The `out/` directory is committed so Terraform `fileset` uploads are stable across applies.

Anomalies are documented for mentors in [docs/mentor/anomaly-map.md](../docs/mentor/anomaly-map.md).
