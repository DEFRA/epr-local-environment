# sp_GetApprovedSubmissionsMyc regression check

Checks that a change to `dbo.sp_GetApprovedSubmissionsMyc` has not altered what it returns, with the
focus on `NumberOfDaysObligated` and the weights that share its `GROUP BY`.

The procedure does not calculate days. It left-joins `dbo.t_producer_obligation_determination`
(filled by the `epr-data` notebook `producer_obligation_determination`, run by `pip_obligation_determination`)
on organisation, subsidiary and submitter, and only for rows with `obligation_status = 'O'` in year
`PeriodYear + 1`. Most regressions will therefore be in that join, the two-period gate, or the grouping.

## Run it

Start the local stack so the `sqledge` container holds a restored `EprCommonData`
(`synapse-sqlserver-restore` completed), then:

```sh
# In your epr-data-sqldb checkout, save the unchanged procedure from main as the baseline
git show main:'dbo/Stored Procedures/sp_GetApprovedSubmissionsMyc.sql' > /tmp/myc-baseline.sql

# From this directory
./run-myc-days-regression.sh \
  --baseline  /tmp/myc-baseline.sql \
  --candidate /path/to/epr-data-sqldb/dbo/Stored\ Procedures/sp_GetApprovedSubmissionsMyc.sql
```

`--baseline` defaults to the restored upstream copy in `.cache/synapse-source`, which is only the right
baseline if you have not edited that cache. Exit code 0 means passed, 1 means findings, 2 means it could not run.

| Setting | Default |
|---|---|
| `MYC_REG_DATABASE` / `--database` | `EprCommonData` |
| `MYC_REG_SQL_PASSWORD` | the local `sa` password from `compose.yml` |
| `MYC_REG_SQL_EXEC` | `docker compose -f ../../../../compose.yml exec -T sqledge` |
| `MYC_REG_SQLCMD` | `/opt/mssql-tools18/bin/sqlcmd` |

## What it does

Everything runs in one transaction that is always rolled back, so no fixture rows or temporary procedures
remain, and it works with the normal local database without touching generated data.

1. Installs the baseline and the candidate as `sp_GetApprovedSubmissionsMyc_regr_baseline` and `_regr_candidate`.
2. Seeds the fixture (`myc-days-fixture.sql`): 21 producers, POM year 2031 and one 2024 producer, organisation
   references 9100001 to 9199999, file names `myc-regression/...`.
3. Runs both procedures for `2031` and `2024`.
4. **L1:** compares the full output of baseline and candidate, including row counts.
5. **L2:** compares baseline and candidate with the hand-written expectations in `myc-days-expectations.sql`.
   A baseline failure in L2 means the expectation (or a characterisation note) is wrong, not the candidate.

Findings are listed by scenario. Columns `A_*` are the baseline (L1) or expected (L2) values and `B_*` are the
candidate (L1) or actual (L2) values.

## Scenarios

| Id | Pins |
|---|---|
| S01 | Partial-year days pass through (joiner 01/07/2032, 184 days) |
| S02 | Obligated with no days returns a row with `NULL` days |
| S03, S04 | Error and Not Obligated determinations give `NULL` days; a stray day count on an `N` row does not leak |
| S05, S06 | Days are matched per submitter: scheme-only member, and one producer submitting directly and through a scheme |
| S07 | Subsidiary matched on `subsidiary_id` |
| S08, S09 | Empty-string and `NULL` subsidiary ids are treated alike on either side |
| S10 | Determination rows for other years are ignored |
| S11, S12 | Characterisation: duplicate determination rows split or double the output |
| S13, S14, S15 | Absent from output: one half-year only, small producer, deleted organisation |
| S16 | Transitional units subtracted before rounding (8.5 becomes 9) |
| S17 | Material and packaging-type filters |
| S18 | Several materials each carry the days |
| S19 | A newer accepted H1 file replaces an older one |
| S20 | The 2024 P1 + P4 period set |

S11 and S12 record current behaviour, not necessarily desired behaviour. If a deliberate change affects them,
update the expectations in the same change.

## Limits

- It covers the procedure's reads, not the pipeline that fills the determination table. Whether the notebook
  produces correct days is a separate check (`epr-data/python/epr-obligation-determination` tests).
- Periods 2024 `P2` and `P3` and their weight scaling are not covered.
- It does not call the Common Data API endpoint or the downstream PRN calculation.
- It was verified by running it against a clean baseline (passes) and against three deliberately broken
  candidates: dropping the submitter condition, dropping the `obligation_status = 'O'` condition, and
  replacing the `COALESCE` on `subsidiary_id` (each fails with the affected scenarios listed). That run used a
  throwaway SQL Server holding only the six tables and one function the procedure needs, built from the upstream
  scripts. It has not yet been run against the full restored `EprCommonData`.
