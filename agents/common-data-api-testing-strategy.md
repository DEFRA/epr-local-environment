# Testing strategy: common-data-api / Synapse data locally

`epr-common-data-api` sits in front of two different kinds of data (see
[repos/epr-common-data-api.md](repos/epr-common-data-api.md)): ordinary relational tables
(`rpd.*`, `dbo.*`) and a Synapse-native analytics schema (`apps.*`) populated in production by
a 958-line merge ETL, not by anything a local SQL Server container can replicate. This repo has
already handled that split three different ways for three different endpoints — one clean stub,
one faithful seed, and one dangerous half-measure. This doc makes the choice repeatable instead
of ad hoc.

## The rule

1. **Proc only reads `rpd.*`/`dbo.*`, and you can port its logic exactly?** → **Seed.** Add real
   rows to `compose/epr-common-data-api-migrations/seed.sql` and port the stored procedure
   verbatim into `compose/epr-common-data-api-migrations/scripts/procedures/`.
2. **Proc reads `apps.*`?** → **Stub.** Don't attempt to create the tables — `apps.sql` here is
   deliberately just `CREATE SCHEMA [apps] AUTHORIZATION [dbo]`, because the real DDL
   (`DISTRIBUTION = HASH(...)`, `CLUSTERED COLUMNSTORE INDEX`) is Synapse-dedicated-pool syntax
   that plain SQL Server rejects outright. Add a static mapping under
   `compose/wiremock/mappings/` instead.
3. **Can't fully understand the proc's branching well enough to port it exactly?** → **Stub, don't
   simplify.** A "ported" procedure that quietly drops a branch is worse than an honest stub: it
   looks like real data, so nobody re-verifies it, and it fails silently instead of loudly.

If you're not sure which bucket an endpoint falls into, grep the `.sql` file in
`epr-common-data-api`'s `src/EPR.CommonDataService.Data/Scripts/Stored Procedures/` for `apps\.` —
that's the fork in the road.

## Why: three case studies already in this repo

| Endpoint | Choice made | Outcome |
|---|---|---|
| `get-registration-fee-calculation-details` | Seeded — real proc ported verbatim against seeded `rpd.CompanyDetails` rows | Correct. The one to copy. |
| `apps.sp_GetActualSubmissionPeriod` | Stubbed — echoes the input period back | Honest and documented (`scripts/procedures/get-actual-submission-period.sql`). The real period-correction logic is untestable here, but nobody is fooled into thinking it works. |
| `sp_PomResubmissionPaycalParameters` | Was a half-measure — ported, but the compliance-scheme branching (~150 lines the original authors themselves described as reverse-engineered) was dropped, and the replacement `MemberCount` was quietly a different metric | **Fixed** by converting it to a scenario-keyed stub (rule 3): a literal `IF @SubmissionId = '...'` lookup returning the exact values from that submission's seed rows, falling through to the same "not yet a resubmission" response real production gives a first-time submission for anything else. See `scripts/procedures/pom-resubmission-paycal-parameters.sql`. |

**Existing precedent for the stub side**: `epr-regulator-service-facade`'s `src/MockCommonData` is
a standalone WireMock.Net server with static JSON fixtures for exactly the hardest endpoints
(`pom-resubmission-paycal-parameters`, `organisation-registrations`, `registrations/summary`).
It isn't wired into this repo's compose stack, but its fixture-per-scenario structure is worth
copying when adding wiremock mappings here.

## How to do each

### Seeding

1. Confirm the proc doesn't touch `apps.*` (see rule above).
2. Copy the stored procedure into `compose/epr-common-data-api-migrations/scripts/procedures/`,
   adjusting only genuinely Synapse-only syntax (e.g. `GREATEST(...)` → `CASE WHEN`, as already
   done in `get-registration-fee-calculation-details.sql`). Don't drop or simplify branches — if a
   branch can't be ported faithfully, that's a signal to stub instead (rule 3).
3. Add representative rows to `seed.sql` using real column semantics, not placeholder values —
   check `gotchas.md` for known real-vs-placeholder ID schemes already living in this repo's seed
   data before inventing new ones.
4. Note in a header comment which upstream version/PR the procedure was ported from, so drift is
   traceable later (see the Maintenance section).

### Stubbing

1. Add a static mapping under `compose/wiremock/mappings/`, and document it in
   `compose/wiremock/mappings/README.md` following the existing entries' format: what it stubs,
   which service calls it, and why it isn't seeded.
2. Prefer one named fixture per scenario (approved / pending / rejected / partial-period, etc.)
   over a single hardcoded happy path, mirroring the `MockCommonData` precedent above.
3. Wiremock only loads static mappings at container startup (`--ReadStaticMappings true`) — restart
   the `wiremock` service after adding a file.

**Wiremock isn't always reachable for this**: check where the calling service's `*BaseUrl` config
actually points before assuming a wiremock mapping will be hit. `epr-pom-api-web`,
`epr-prn-obligationcalculations-function`, and `epr-regulator-facade` all point their
`CommonDataApi(Config)?__BaseUrl` straight at the real `epr-common-data-api` container, not at
wiremock — there's no proxy/passthrough set up in front of it. If the consumer you're dealing with
does this, get the same effect *inside* the stored procedure instead: a literal
`IF @SubmissionId = N'...'` lookup returning canned values for known seeded scenarios, falling
through to a safe generic default (see `pom-resubmission-paycal-parameters.sql` for a worked
example). Same rule, same "don't fake a computation" spirit, just applied at the SQL layer instead
of the HTTP layer. Repointing a consumer's `BaseUrl` at wiremock with a catch-all
proxy-to-the-real-container mapping is the more general fix if this pattern needs to cover many
endpoints — worth doing as a deliberate, separate change, not as a side effect of stubbing one
endpoint.

## A code bug this doesn't fix either way

`RegistrationFeeCalculationDetailsService` in `epr-common-data-api` swallows all SQL exceptions to
a silent `null` → HTTP 204, indistinguishable from "genuinely no data." Neither a stub nor a seed
row surfaces this — it needs a fix in that service itself before this endpoint's negative-path
behavior is really testable.

## Maintenance

Upstream `epr-common-data-api` stored procedures change roughly weekly. Any procedure ported or
stubbed here is a standing liability without an owner — periodically diff the local `.sql` files
in `scripts/procedures/` against current upstream to catch silent drift before it becomes a real
gap (this is exactly how `get-registration-fee-calculation-details` was found missing in the first
place).
