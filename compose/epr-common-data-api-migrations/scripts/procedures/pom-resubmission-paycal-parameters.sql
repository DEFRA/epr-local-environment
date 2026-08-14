-- Local-environment stand-in for epr-common-data-api's real
-- [dbo].[sp_PomResubmissionPaycalParameters]. This is a STUB, not a port: the real proc's
-- MemberCount branching (compliance-scheme vs. direct-producer, sourced from
-- apps.SubmissionsSummaries / dbo.t_CSO_Pom_resubmitted_ByCSID / sp_DP_Pom_Resubmitted_ByDPID)
-- reads the `apps` schema, which this environment never populates (see
-- ../../../../agents/common-data-api-testing-strategy.md, rule 2 - `apps.*` = stub, don't seed).
--
-- An earlier version of this file tried to answer the question from `rpd` data instead: it
-- computed MemberCount as "producers in the latest uploaded file", which is a different figure
-- from what the real proc means by MemberCount ("existing CS members whose Pom data didn't
-- change between submission cycles"), and it silently dropped the compliance-scheme vs.
-- direct-producer branching entirely. It looked like real data for every submission, which is
-- exactly the anti-pattern rule 3 in the strategy doc warns about.
--
-- This version follows the same pattern already used for apps.sp_GetActualSubmissionPeriod:
-- known seeded scenarios get a literal answer taken straight from their seed rows; every other
-- SubmissionId gets the same "not yet a resubmission" response real production returns for a
-- first-time submission (Reference IS NULL), which
-- SubmissionsController.POMResubmission_PaycalParameters turns into HTTP 428 - a status every
-- known caller (WebApiGateway's CommondataClient.GetPackagingResubmissionMemberDetails) already
-- handles gracefully. That's safer than a plausible-looking number: it never fabricates a
-- MemberCount for a submission nobody deliberately set one up for.
--
-- ReferenceFieldAvailable is always 1: the real proc only sets it to 0 when the
-- apps.SubmissionEvents.PackagingResubmissionReferenceNumber column is missing, which doesn't
-- happen in real production (the column is a stable, long-deployed part of the schema) - so 1 is
-- the faithful answer here too, not a shortcut. (0 would surface as HTTP 412, which
-- CommondataClient does NOT catch and crashes the whole resubmission task-list page on.)
--
-- Two scenarios are wired up: Northbridge Compliance Solutions Ltd's 2025 H2 (compliance scheme)
-- and POP QUEST LTD's 2025 H2 (direct producer, @ComplianceSchemeId NULL).
--
-- To add another real scenario: add an `IF @SubmissionId = N'...'` branch above the ELSE, sourced
-- from the actual seed.sql rows for that SubmissionId (Reference from the
-- PackagingResubmissionReferenceNumberCreated event's PackagingResubmissionReferenceNumber,
-- ResubmissionDate from its Created value) - don't try to compute MemberCount generically.
IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[dbo].[sp_PomResubmissionPaycalParameters]'))
    DROP PROCEDURE [dbo].[sp_PomResubmissionPaycalParameters];
GO

CREATE PROC [dbo].[sp_PomResubmissionPaycalParameters] @SubmissionId [nvarchar](40), @ComplianceSchemeId [nvarchar](40) AS
begin
    IF @SubmissionId = N'C18BF17E-DEC1-434E-A5CA-A37D9811C72D'
    BEGIN
        -- 2025 H2, Northbridge Compliance Solutions Ltd: resubmission in progress, fee viewed
        -- but not yet paid (see seed.sql's rpd.SubmissionEvents rows for this SubmissionId -
        -- PackagingResubmissionReferenceNumberCreated then PackagingResubmissionFeeViewed,
        -- deliberately no payment/final-submit event). MemberCount is illustrative - this proc's
        -- real source for it is apps-schema data that doesn't exist locally - change it if a
        -- specific count matters for what you're testing.
        SELECT
            5 AS MemberCount,
            N'NBCS-2025H2-POM-RESUB-0001' AS Reference,
            CAST(N'2026-01-15T09:00:00' AS DATETIME2) AS ResubmissionDate,
            CAST(1 AS BIT) AS IsResubmission,
            CAST(1 AS BIT) AS ReferenceFieldAvailable,
            N'GB-ENG' AS NationCode;
    END
    ELSE IF @SubmissionId = N'E5F6A7B8-C9D0-4E1F-2A3B-4C5D6E7F8091'
    BEGIN
        -- 2025 H2, POP QUEST LTD (Direct Producer): resubmission in progress, fee viewed but not
        -- yet paid (see seed.sql's rpd.SubmissionEvents rows for this SubmissionId -
        -- PackagingResubmissionReferenceNumberCreated then PackagingResubmissionFeeViewed, and
        -- deliberately no payment/final-submit event).
        --
        -- For a direct producer @ComplianceSchemeId is NULL and the real proc would source
        -- MemberCount from sp_DP_Pom_Resubmitted_ByDPID rather than the compliance-scheme table -
        -- but the parent proc still reads apps.SubmissionsSummaries for IsResubmission, which this
        -- environment never populates, so this stays a literal like the branch above. 3 = the
        -- producer itself plus its 2 subsidiaries, matching the rpd.Pom rows for this file.
        SELECT
            3 AS MemberCount,
            N'PQL-2025H2-POM-RESUB-0001' AS Reference,
            CAST(N'2026-01-20T09:00:00' AS DATETIME2) AS ResubmissionDate,
            CAST(1 AS BIT) AS IsResubmission,
            CAST(1 AS BIT) AS ReferenceFieldAvailable,
            N'GB-ENG' AS NationCode;
    END
    ELSE
    BEGIN
        SELECT
            CAST(NULL AS INT) AS MemberCount,
            CAST(NULL AS NVARCHAR(50)) AS Reference,
            CAST(NULL AS NVARCHAR(50)) AS ResubmissionDate,
            CAST(0 AS BIT) AS IsResubmission,
            CAST(1 AS BIT) AS ReferenceFieldAvailable,
            N'GB-ENG' AS NationCode;
    END
end
GO
