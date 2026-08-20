# Generator profiles

Profiles are versioned, anonymous aggregate descriptions of a real environment's data shape. They are input to the generator; they are not production extracts.

The current default profile is `preprod-complete-2025-prn-shape`:

- Input POM reporting year: 2025
- Derived obligation/PRN year: 2026
- POM source: pre-production 2025/2026 baseline
- PRN source: completed pre-production obligation year 2025
- Observation date: 20 August 2026

## Content rules

A baseline profile should include only counts, ranges, bucket distributions and aggregate weights, including:

- submitters and producers by type;
- POM reporting-period, packaging-material/type and row/weight distributions;
- producer-to-submitter relationship buckets;
- accepted and awaiting-acceptance PRN distributions and totals;
- active obligation calculation counts, including the expected Glass-to-GlassRemelt expansion;
- profile provenance: target years, snapshot date, query revision and source-environment label.

Never store organisation IDs, company names, people, user details, addresses, emails, phone numbers, submission IDs, PRN numbers, CSV/document content or blobs.

## Files and current limitations

- `baselines/<profile>.json` — anonymous normal-volume aggregate profile.
- `baselines/<profile>.metadata.json` — provenance and reconciliation values.
- `schemas/` — reserved for JSON schema and validation constraints; no runtime profile-schema
  validator exists in the first iteration.

The checked-in [completed 2025 PRN-shape profile](baselines/preprod-complete-2025-prn-shape.json)
and [its provenance](baselines/preprod-complete-2025-prn-shape.metadata.json) are the current default.

Do not overwrite an existing profile after a re-run. Add a new version or observation-date suffix, retain the aggregate evidence and document the difference in the profile metadata.

The first CLI iteration has one checked-in default profile and does not yet expose profile selection
as a command-line option. Collecting a new profile therefore follows the refresh process, then changes
the reviewed default profile import in the generator until multi-profile selection is added.
