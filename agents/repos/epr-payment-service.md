# epr-payment-service (WA 425)

Payment service API - calculates fees and manages payment records.

## Purpose

Core service for fee calculation and payment record management. Owns the `feesPaymentDB` database.

## Entry Points

| File | Purpose |
|------|---------|
| `src/EPR.Payment.Service.Api/Program.cs` | Startup |
| `src/EPR.Payment.Service.Api/Controllers/` | API endpoints |
| `src/EPR.Payment.Service.Core/Services/` | Business logic |
| `src/EPR.Payment.Service.Data/` | Database access |

## Key Endpoints

| Endpoint | Purpose |
|----------|---------|
| `POST /api/fees/calculate` | Calculate fees for submission |
| `GET /api/fees/{referenceNumber}` | Get fee by reference |
| `POST /api/payments` | Record payment |
| `GET /api/payments/{id}` | Get payment status |

## Database

**SQL Server** - `feesPaymentDB`
- Fee lookup tables (rates by material, size, etc.)
- Calculated fee records
- Payment records (linked to GovPay)

## Dependencies (calls)

- **feesPaymentDB** - owns this database

## Consumers (called by)

| Consumer | Purpose |
|----------|---------|
| epr-payment-facade (WA 424) | Fee calculation, payment initiation |
| epr-regulator-service-facade (WA 406) | Fee queries for regulator |
| epr-payment-mopup (FA 409) | Payment status sync |

## Key Patterns

- **Fee calculation rules** - complex business logic for EPR fees
- **Payment integration** - works with GovPay via facade

## Gotchas

- Fee calculation rules are complex - multiple factors (material, tonnage, producer size)
- Payment records link to GovPay references
- Mopup function (FA 409) polls GovPay to sync statuses

## C4 Reference

[model.producer-regulator.c4](https://github.com/DEFRA/extended-producer-responsibility-docs/blob/main/docs/architecture/report-packaging-data/model.producer-regulator.c4) lines 35-48
