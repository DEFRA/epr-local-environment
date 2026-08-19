# Data generator

This directory is the home for a local synthetic-data generator for the EPR obligations journey. Its first target is a connected, realistic year of POM, PRN and obligation-calculation data.

> Status: design scaffold only. No generator executable, compose service, database migration, or seed data is introduced by this change.

## Intended command contract

```text
data-generator generate-year 2025
data-generator generate-year 2025 --increase 25%
data-generator generate-year 2025 --link-local-accounts
```

`2025` is the POM reporting year. The resulting determination, PRN and obligation-calculation year is therefore `2026`. The default command will reproduce the selected baseline's normal volume and shape; `--increase` scales connected entities and their data proportionally rather than merely increasing weights.

The generator will run against an already running local stack. It will be exposed from a CLI-only compose file (`compose.cli.yml`) and will connect through the database endpoints already provided by that stack. It does not need a separate Docker project name or bespoke network.

## First-iteration outcome

- Generate only data which materially reaches `dbo.sp_GetApprovedSubmissionsMyc`.
- Generate matching accepted/awaiting PRNs for the same submitter identities.
- Re-run the existing PRN obligation calculation path, rather than directly inserting final calculation rows.
- Preserve a realistic compliance-scheme/direct-registrant mix, material mix, producer associations, POM rows and PRN volume.
- Optionally attach a small, representative part of the generated data to the existing local Northbridge and Pop Quest account/organisation fixtures, so normal login can show it.

The detailed decision record, source-repository trace, snapshot figures, identity contract and repeatable refresh process are in [first-iteration.md](docs/first-iteration.md). The intended profile and SQL-checking conventions are in [profiles/README.md](profiles/README.md) and [sql/README.md](sql/README.md).

## Directory layout

```text
tools/data-generator/
├── docs/                 Design, data-flow and refresh records
├── manifests/            Generated-run manifests (kept out of source control when populated)
├── profiles/
│   ├── baselines/        Versioned anonymous aggregate profiles
│   └── schemas/          Profile file schemas and validation rules
├── sql/
│   ├── baseline/         Queries used to collect a pre-production baseline
│   ├── validation/       Comparable local/pre-production shape checks
│   └── local/            Local-only, run-scoped diagnostics
├── src/                  Future CLI implementation
└── tests/                Future generator and integration tests
```

## Guardrails

- Store aggregate, anonymous statistics only in `profiles/`; never copy production organisation, user, address, submission, PRN or file data.
- Resolve lookup IDs by name in the target database. Do not copy local seed IDs into generated PRN data.
- Maintain the identifier relationships described in the decision record exactly, especially across both POM half-year submissions.
- A generated run must record its baseline version, seed, scale, POM year, resulting obligation year and generated identifiers in a manifest.
- Do not modify unrelated payment, waste-obligations or legacy calculator fixtures as part of the initial data path.
