# Generator profiles

Profiles are versioned, anonymous aggregate descriptions of a real environment's data shape. They are input to the generator; they are not production extracts.

The first planned profile name is `preprod-pom-2025-prn-2026`:

- Input POM reporting year: 2025
- Derived obligation/PRN year: 2026
- Observation date: 19 August 2026
- Source: pre-production aggregate query results supplied during discovery

## Content rules

A baseline profile should include only counts, ranges, bucket distributions and aggregate weights, including:

- submitters and producers by type;
- POM reporting-period, packaging-material/type and row/weight distributions;
- producer-to-submitter relationship buckets;
- accepted and awaiting-acceptance PRN distributions and totals;
- active obligation calculation counts, including the expected Glass-to-GlassRemelt expansion;
- profile provenance: target years, snapshot date, query revision and source-environment label.

Never store organisation IDs, company names, people, user details, addresses, emails, phone numbers, submission IDs, PRN numbers, CSV/document content or blobs.

## Planned files

- `baselines/<profile>.json` — anonymous normal-volume aggregate profile.
- `baselines/<profile>.metadata.json` — provenance and reconciliation values.
- `schemas/` — JSON schema and validation constraints for profiles.

Do not overwrite an existing profile after a re-run. Add a new version or observation-date suffix, retain the aggregate evidence and document the difference in the profile metadata.
