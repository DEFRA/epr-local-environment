# Baseline and validation SQL

This area will hold the SQL used to make data generation reflective rather than a one-off seed. The same aggregate checks should be runnable against pre-production and a local generated database, parameterised by POM reporting year `Y` and calculated/PRN year `Y + 1`.

> No SQL is added in this scaffold. The scripts are deliberately deferred until their inputs and generator run marker are implemented, so that they test the actual generated contract rather than an assumed schema variant.

## Planned scripts

- `baseline/common-data-period-profile.sql`
  - SP-relevant accepted POM population, material/type mix, H1/H2 completeness, POM row/weight bands, submitter type and producer/submitter cardinality.
- `baseline/prn-obligation-year-profile.sql`
  - PRNs and active obligation calculations by submitter type, status, material, number of PRNs, quantities and expected GlassRemelt expansion.
- `validation/common-data-year-shape.sql`
  - Local-versus-baseline SP input/output counts and distributions for one generated POM year.
- `validation/prn-year-shape.sql`
  - Local-versus-baseline PRN and recalculated obligation shape for `Y + 1`.
- `validation/relationship-integrity.sql`
  - Identity bridge, H1/H2 continuity, submitter type uniqueness and PRN-to-submitter checks.
- `local/run-scoped-checks.sql`
  - Optional diagnostics using a generated-run manifest/marker. This is local-only; baseline queries must not rely on it.

## Use when refreshing a profile

1. Run baseline SQL against the chosen pre-production snapshot.
2. Retain the anonymous result sets and query revision with a new profile version.
3. Generate a local year using that profile and a fixed random seed.
4. Run the matching validation scripts locally.
5. Compare aggregate counts and buckets, including the Glass/GlassRemelt reconciliation, before accepting the generator change or new profile.

The intended profile contract and the initial 2025/2026 evidence are documented in [the decision record](../docs/first-iteration.md).
