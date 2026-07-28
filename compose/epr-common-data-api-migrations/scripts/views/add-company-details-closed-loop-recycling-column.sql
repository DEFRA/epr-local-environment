-- rpd.CompanyDetails.closed_loop_registration: a real column the baked-in image's
-- rpd.CompanyDetails table (in ./scripts/tables) doesn't have, but several of the baked-in views
-- (in ./scripts/views) and epr-common-data-api's sp_GetRegistrationFeeCalculationDetails read via
-- `UPPER(TRIM(cd.closed_loop_registration)) = 'YES'` - it's a Yes/No string, like this table's
-- other flag columns (e.g. produce_blank_packaging_flag), not a BIT. Missing it caused
-- "Invalid column name 'closed_loop_registration'" during migration (views referencing it) and a
-- silently-swallowed exception in RegistrationFeeCalculationDetailsService (see
-- ./scripts/procedures/get-registration-fee-calculation-details.sql).
--
-- Deliberately placed here rather than in ./scripts/compose/tables or ./scripts/compose/procedures:
-- run-migrations.sh processes Tables, then Views (3 passes), then Functions, then Procedures.
-- ./scripts/compose/tables runs BEFORE the real ./scripts/tables, so rpd.CompanyDetails wouldn't
-- exist yet for an ALTER there. ./scripts/compose/procedures runs AFTER all 3 Views passes, which
-- is too late - the baked-in views that reference this column need it to already exist when they're
-- created. This ./scripts/compose/views file runs after Tables (real CREATE TABLE has already run)
-- but before the baked-in ./scripts/views, which is the only slot that satisfies both orderings.
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'[rpd].[CompanyDetails]') AND name = 'closed_loop_registration'
)
    ALTER TABLE [rpd].[CompanyDetails] ADD [closed_loop_registration] NVARCHAR(10) NOT NULL DEFAULT N'No';
GO
