-- Local-environment addition of epr-common-data-api's
-- src/EPR.CommonDataService.Data/Scripts/Stored Procedures/get-registration-fee-calculation-details.sql
-- Not a Synapse-incompatibility rewrite (unlike sp_PomResubmissionPaycalParameters) - the real
-- proc only ever queries rpd.cosmos_file_metadata and rpd.CompanyDetails, both of which already
-- exist and are seeded locally. It was simply never baked into this environment's migrations
-- image (only get-approved-submissions_myc.sql is), so RegistrationApplicationController.
-- RegistrationFeeCalculations's session.RegistrationFeeCalculationDetails hydration
-- (RegistrationFeeCalculationDetailsService.GetRegistrationFeeCalculationDetails) silently caught
-- "Could not find stored procedure" and returned null for every submission, relying entirely on
-- epr-payment-service's fee-calculation-details snapshot to paper over the gap.
--
-- Logic and output columns match the current real proc exactly (as of epr-common-data-api commit
-- efb3b94, "PR - trim rather than ltrim(rtim())"): OrganisationId, OrganisationSize,
-- NumberOfSubsidiaries, NumberOfSubsidiariesBeingOnlineMarketPlace,
-- NumberOfSubsidiariesBeingClosedLoopRecycling, IsOnlineMarketPlace, IsClosedLoopRecycling,
-- IsNewJoiner, NationId - must match RegistrationFeeCalculationDetailsModel's property names,
-- since EF Core's FromSqlRaw keyless-entity mapping is by column name. The only structural change
-- from the real proc: replacing its ";WITH OrganisationDetails AS (...), SubsidiaryCount AS (...)"
-- CTE with a #SubsidiaryCount temp table + derived table, matching the no-CTE convention already
-- used by this directory's other local-replacement procs.
--
-- closed_loop_registration: rpd.CompanyDetails column the real proc reads via
-- `UPPER(TRIM(cd.closed_loop_registration)) = 'YES'` (a Yes/No string, like this table's other
-- flag columns such as produce_blank_packaging_flag - not a BIT). It's added to the local
-- rpd.CompanyDetails table by
-- ./scripts/compose/views/add-company-details-closed-loop-recycling-column.sql, which runs before
-- this file (see that file's header for why it isn't added here directly - ordering relative to
-- run-migrations.sh's Views passes matters).
IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[dbo].[sp_GetRegistrationFeeCalculationDetails]'))
    DROP PROCEDURE [dbo].[sp_GetRegistrationFeeCalculationDetails];
GO

CREATE PROC [dbo].[sp_GetRegistrationFeeCalculationDetails] @fileId [varchar](40) AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @fileName AS VARCHAR(4000);

    SELECT @fileName = metadata.[FileName]
    FROM rpd.cosmos_file_metadata metadata
    WHERE FileId = @fileId;

    SELECT
        cd.organisation_id AS OrganisationId,
        CASE WHEN cd.packaging_activity_om IN ('Primary', 'Secondary') THEN 1 ELSE 0 END AS IsOnlineMarketPlace,
        CASE WHEN UPPER(TRIM(cd.closed_loop_registration)) = 'YES' THEN 1 ELSE 0 END AS IsClosedLoopRecycling,
        cd.organisation_size AS OrganisationSize,
        CASE UPPER(cd.home_nation_code)
            WHEN 'EN' THEN 1
            WHEN 'NI' THEN 2
            WHEN 'SC' THEN 3
            WHEN 'WS' THEN 4
            WHEN 'WA' THEN 4
        END AS NationId,
        CASE WHEN cd.joiner_date IS NOT NULL THEN 1 ELSE 0 END AS IsNewJoiner,
        cd.subsidiary_id AS SubsidiaryId,
        cd.packaging_activity_om AS Packaging_Activity_OM,
        cd.closed_loop_registration AS closed_loop_registration
    INTO #OrganisationDetails
    FROM rpd.CompanyDetails cd
    WHERE TRIM(cd.FileName) = @fileName;

    SELECT
        OrganisationId,
        COUNT(*) AS SubsidiaryCounter,
        COUNT(CASE WHEN Packaging_Activity_OM IN ('Primary', 'Secondary') THEN 1 END) AS OnlineMarketPlaceSubsidiaries,
        COUNT(CASE WHEN UPPER(TRIM(closed_loop_registration)) = 'YES' THEN 1 END) AS ClosedLoopRecyclingSubsidiaries
    INTO #SubsidiaryCount
    FROM #OrganisationDetails
    WHERE SubsidiaryId IS NOT NULL
    GROUP BY OrganisationId;

    SELECT
        od.OrganisationId AS OrganisationId,
        od.OrganisationSize AS OrganisationSize,
        ISNULL(sc.SubsidiaryCounter, 0) AS NumberOfSubsidiaries,
        ISNULL(sc.OnlineMarketPlaceSubsidiaries, 0) AS NumberOfSubsidiariesBeingOnlineMarketPlace,
        ISNULL(sc.ClosedLoopRecyclingSubsidiaries, 0) AS NumberOfSubsidiariesBeingClosedLoopRecycling,
        CAST(od.IsOnlineMarketPlace AS BIT) AS IsOnlineMarketPlace,
        CAST(od.IsClosedLoopRecycling AS BIT) AS IsClosedLoopRecycling,
        CAST(od.IsNewJoiner AS BIT) AS IsNewJoiner,
        od.NationId
    FROM #OrganisationDetails od
    LEFT JOIN #SubsidiaryCount sc ON od.OrganisationId = sc.OrganisationId
    WHERE od.SubsidiaryId IS NULL;

    DROP TABLE #OrganisationDetails;
    DROP TABLE #SubsidiaryCount;
END;
GO
