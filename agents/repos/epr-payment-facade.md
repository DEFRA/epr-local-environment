# epr-payment-facade (WA 424)

Payment facade - orchestrates payment flows between frontends and payment service/GovPay.

## Purpose

Handles payment initiation workflow:
1. Calculate fees via payment-service
2. Create GovPay payment session
3. Return redirect URL to GovPay
4. Handle callbacks

## Entry Points

| File | Purpose |
|------|---------|
| `src/EPR.Payment.Facade.Api/Program.cs` | Startup |
| `src/EPR.Payment.Facade.Api/Controllers/` | API endpoints |
| `src/EPR.Payment.Facade.Core/Services/` | Payment orchestration |

## Key Endpoints

| Endpoint | Purpose |
|----------|---------|
| `POST /api/payments/initiate` | Start payment, get GovPay redirect |
| `GET /api/payments/complete` | Handle GovPay callback |
| `GET /api/fees/{reference}` | Get calculated fees |

## Dependencies (calls)

| Service | Purpose |
|---------|---------|
| epr-payment-service (WA 425) | Fee calculation, payment records |
| GovPay | Payment gateway |

## Consumers (called by)

| Consumer | Purpose |
|----------|---------|
| epr-packaging-frontend (WA 410) | Producer payments |
| epr-regulator-service (WA 411) | Regulator fee views |
| epr-payment-frontend (WA 423) | Payment UI |

## Key Patterns

### Payment Flow

1. Frontend calls `/api/payments/initiate`
2. Facade calculates fee via payment-service
3. Facade creates GovPay session
4. Returns `NextUrl` (GovPay hosted page)
5. User completes payment on GovPay
6. GovPay redirects to callback
7. Facade updates payment status

## Gotchas

- Returns JS redirect: `window.location.href = '{nextUrl}'`
- Callback handling critical for payment completion
- Payment mopup (FA 409) handles cases where callback fails

## C4 Reference

[model.producer-regulator.c4](https://github.com/DEFRA/extended-producer-responsibility-docs/blob/main/docs/architecture/report-packaging-data/model.producer-regulator.c4) lines 409-433
