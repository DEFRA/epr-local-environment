-- Local-environment replacement for epr-common-data-api's real
-- [dbo].[sp_PomResubmissionPaycalParameters], which depends on an `apps` schema
-- (apps.SubmissionsSummaries, apps.SubmissionEvents, t_PomResubmissionPaycalEvents,
-- t_CSO_Pom_resubmitted_ByCSID, sp_DP_Pom_Resubmitted_ByDPID) that doesn't exist anywhere in
-- this local environment's migrations - only the `rpd` schema is seeded here.
--
-- The real proc's own "IF EXISTS (... apps.SubmissionEvents ... PackagingResubmissionReferenceNumber
-- ...)" guard would safely fall through to ReferenceFieldAvailable = 0 in this environment (since
-- that apps table genuinely doesn't exist) - but SubmissionsController.POMResubmission_PaycalParameters
-- turns ReferenceFieldAvailable = 0 into an HTTP 412, and WebApiGateway's CommondataClient
-- (get-packaging-resubmission-application-details) only has a catch for 428 (PreconditionRequired),
-- not 412 (PreconditionFailed) - so it re-throws, crashing the *entire* resubmission task-list
-- page for any submission with a resubmission cycle already started. Rather than replicate the
-- full apps-schema pipeline, this version answers the same question from the `rpd` schema data
-- this environment actually has, and always sets ReferenceFieldAvailable = 1 to avoid that crash.
IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[dbo].[sp_PomResubmissionPaycalParameters]'))
    DROP PROCEDURE [dbo].[sp_PomResubmissionPaycalParameters];
GO

CREATE PROC [dbo].[sp_PomResubmissionPaycalParameters] @SubmissionId [nvarchar](40), @ComplianceSchemeId [nvarchar](40) AS
begin
    DECLARE @IsResubmission BIT = 0;
    DECLARE @ResubmissionDate DATETIME2 = NULL;
    DECLARE @Reference NVARCHAR(50) = NULL;
    DECLARE @MemberCount INT = NULL;
    DECLARE @NationCode NVARCHAR(20) = N'GB-ENG';

    SELECT TOP 1
        @Reference = se.PackagingResubmissionReferenceNumber,
        @ResubmissionDate = TRY_CAST(se.Created AS DATETIME2)
    FROM rpd.SubmissionEvents se
    WHERE se.SubmissionId = @SubmissionId
      AND se.Type = N'PackagingResubmissionReferenceNumberCreated'
    ORDER BY se.Created DESC;

    IF @Reference IS NOT NULL
        SET @IsResubmission = 1;

    -- Count members present in the CURRENT (latest-uploaded) file only, not a union across every
    -- historic cycle - this is what the resubmission fee should be based on. Join is on
    -- cosmos_file_metadata.BlobName, not .FileName: rpd.Pom.FileName actually holds the blob GUID,
    -- while cosmos_file_metadata.FileName holds the human-readable original filename (BlobName is
    -- the column that holds the matching blob GUID there) - joining on FileName=FileName silently
    -- matched zero rows and made every resubmission fee compute as zero.
    DECLARE @LatestBlobName NVARCHAR(4000);

    SELECT TOP 1 @LatestBlobName = cfm.BlobName
    FROM rpd.cosmos_file_metadata cfm
    WHERE cfm.SubmissionId = @SubmissionId
    ORDER BY cfm.Created DESC;

    SELECT @MemberCount = COUNT(DISTINCT p.organisation_id)
    FROM rpd.Pom p
    WHERE p.FileName = @LatestBlobName;

    SELECT
        @MemberCount AS MemberCount,
        @Reference AS Reference,
        @ResubmissionDate AS ResubmissionDate,
        @IsResubmission AS IsResubmission,
        CAST(1 AS BIT) AS ReferenceFieldAvailable,
        @NationCode AS NationCode;
end
GO
