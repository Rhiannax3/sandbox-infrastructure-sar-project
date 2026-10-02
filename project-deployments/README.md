# Project deployments

Per-project folders for engineer-built code that is published to the cloud (not the EC2 portal stack).

| Project | Folder | What you edit |
|---------|--------|----------------|
| **A** (AWS Lambda) | [`project-a/`](./project-a/) | Lambda handler, extra modules, shared JSON Schema |
| **B** (Azure Databricks) | [`project-b/notebooks/`](./project-b/notebooks/) | Starter notebooks for medallion exercises (TODO scaffolds) |

Project B infrastructure and seed data remain under `terraform/` and `seed-data/`. Notebooks are imported into the Databricks workspace — see [`project-b/notebooks/README.md`](./project-b/notebooks/README.md).
