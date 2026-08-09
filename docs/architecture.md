# Architecture overview

## Build boundary

Foundational infrastructure is provisioned by this repository. Engineers build the learning-objective components themselves.

```mermaid
flowchart TB
  subgraph provisioned [Provisioned by Terraform]
    django[Django SAR portal]
    keycloak[Keycloak]
    iam[IAM baselines + SSM seam]
    adls[ADLS Gen2 + seed data]
    dbx[Databricks workspace + UC catalog]
    wh[SQL warehouse]
  end
  subgraph engineered [Built by juniors]
    lambda[Lambda + API Gateway]
    ddb[DynamoDB]
    jwt[JWT authorizer]
    medallion[Bronze Silver Gold Platinum]
    grants[Layer RBAC grants]
    pbi[Power BI dashboards]
  end
  django --> lambda
  lambda --> ddb
  keycloak -.JWT.-> jwt
  jwt --> lambda
  adls --> medallion
  medallion --> pbi
  dbx --> grants
```

## Cloud split

| Concern | Cloud | Root module |
|---------|-------|-------------|
| Portal, IdP, API sandbox | AWS | `terraform/project-a-aws` |
| UC metastore (once per region) | Azure | `terraform/project-b-azure-shared` |
| Per-engineer lake + workspace | Azure | `terraform/project-b-azure-engineer` |

## Integration seams

1. **Portal ↔ API** — SSM parameter `/sar-sandbox/{engineer}/api-base-url`
2. **Portal ↔ Keycloak** — OIDC (`sar-portal` client, scopes `sar:read|write|approve`)
3. **Project A → Project B** — CloudWatch → S3 log archive (export) + seeded historical SAR files in ADLS landing
4. **Power BI ↔ Databricks** — SQL warehouse JDBC/ODBC (licence assigned manually)
