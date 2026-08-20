# Baseline and validation SQL

This area holds the SQL used to make data generation reflective rather than a one-off seed. The same aggregate checks should be runnable against pre-production and a local generated database, parameterised by POM reporting year `Y` and calculated/PRN year `Y + 1`.

The first scripts produce aggregate result sets only and do not export organisation or user data.

## Planned scripts

- `baseline/common-data-approved-submissions.sql`
  - SP-relevant accepted POM population, material/type mix, H1/H2 completeness, POM row/weight bands, submitter type and producer/submitter cardinality.
- `baseline/prn-obligation-year-profile.sql`
  - PRNs and active obligation calculations by submitter type, status, material, number of PRNs, quantities and expected GlassRemelt expansion.
- `validation/generated-run-counts.sql`
  - Local run-scoped POM, accepted-decision and PRN counts, plus the stored-procedure material matrix.

## Use when refreshing a profile

1. Run baseline SQL against the chosen pre-production snapshot.
2. Retain the anonymous result sets and query revision with a new profile version.
3. Generate a local year using that profile and a fixed random seed.
4. Run the matching validation scripts locally.
5. Compare aggregate counts and buckets, including the Glass/GlassRemelt reconciliation, before accepting the generator change or new profile.

The intended profile contract and the initial 2025/2026 evidence are documented in [the decision record](../docs/first-iteration.md).
