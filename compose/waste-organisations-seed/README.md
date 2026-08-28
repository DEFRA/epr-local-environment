# Waste Organisations seed scenarios

`seed.mjs` uploads every payload once for each year from 2025 through 2030.  A
payload only receives a compliance declaration when its id has a matching
directory under `../waste-obligations-seed/payloads/compliance-declarations`.
The scenarios below deliberately have no such directory.

## Expected unsubmitted results

Once Waste Obligations has completed an organisation refresh and its reference
number hydration, a request for a year seeded by this script should include
these declaration-free organisations:

| Request | Organisation | Reference number | Why it is present |
| --- | --- | --- | --- |
| `registrationType=DirectProducer` | BRAMBLEWOOD PACKAGING LTD | `110001` | Its organisation id is an Account service external id. |
| `registrationType=DirectProducer` | SILVERDALE FOODS LTD | `110002` | Its organisation id is an Account service external id. |
| `registrationType=ComplianceScheme` | Northbridge Compliance Solutions Ltd | `110000` | Its Companies House number is an Account service lookup key. |

BRAMBLEWOOD PACKAGING LTD also has 2026 PRN Common Backend seed data. Once the
obligation-hydration worker has completed its first read, it has 75 accepted
tonnes against 300 obligated tonnes and is not meeting its recycling
obligations. Other unsubmitted rows remain at the public contract's default
values until their own hydration read completes.

For example, the two producer rows have the following response shape. They
will appear alongside any other seeded unsubmitted producers:

```json
[
  {
    "organisationId": "3151dbe5-a8ad-4d82-9471-1c469fa13918",
    "registrationType": "DirectProducer",
    "organisationName": "BRAMBLEWOOD PACKAGING LTD",
    "organisationReferenceNumber": "110001",
    "recyclingObligationsMet": false,
    "obligationCoveragePercentage": 25
  },
  {
    "organisationId": "4bdf517c-6270-4660-8b5e-97add9379a2a",
    "registrationType": "DirectProducer",
    "organisationName": "SILVERDALE FOODS LTD",
    "organisationReferenceNumber": "110002",
    "recyclingObligationsMet": null,
    "obligationCoveragePercentage": 0
  }
]
```

The enclosing endpoint response is
`{ "unsubmittedOrganisations": [...], "total": <number>, "page": 1,
"pageSize": 20 }`.

## Deliberately excluded cases

| Organisation | Case exercised | Expected eligibility state | Endpoint result |
| --- | --- | --- | --- |
| Unlinked Producer Ltd | Its id is absent from the Account seed. | `NotFound` after the external-id lookup. | Excluded. |
| Scheme Without Companies House Number Ltd | A compliance scheme has no Companies House lookup key. | `AwaitingLookupKey`; no Account request can be made. | Excluded. |
| Scheme With Unknown Companies House Number Ltd | Its Companies House lookup key has no Account match. | `NotFound` after the Companies House lookup. | Excluded. |
| BRAMBLEWOOD PACKAGING (NORTH) LTD | It has a valid, resolvable Account record (`110011`) but is cancelled. | Reference resolution succeeds; registration is `CANCELLED`. | Excluded. |

This keeps the local data focused on the endpoint contract: returned rows must
be registered, have a resolved reference number, and have no submitted or
accepted declaration for the selected year.
