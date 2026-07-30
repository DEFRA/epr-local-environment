-- Local-environment replacement for epr-common-data-api's real
-- [apps].[sp_GetActualSubmissionPeriod], which depends on an `apps` schema
-- (apps.SubmissionsSummaries) that doesn't exist anywhere in this local
-- environment's migrations - only the `rpd` schema is seeded here.
--
-- Without this procedure, SubmissionsService.GetActualSubmissionPeriod's call to
-- RunSpCommandAsync fails against a nonexistent object on every attempt; WebApiGateway's
-- ICommondataClient resilience policy then retries several times before giving up, which is
-- what turns FileUploadCheckFileAndSubmitController's POST (which calls this to build the
-- regulator resubmission email) into a ~40 second hang instead of a fast response. The real
-- proc converts a small producer's stored "July to December" submission period into the
-- "January to December" period actually used for regulator correspondence; this environment
-- has no equivalent apps-schema data to derive that from, so it echoes the input period back
-- unchanged - SubmissionsService already falls back to the input value when no better answer
-- is available, so this is functionally equivalent to that fallback, just without the failed
-- round-trip that caused the hang.
IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[apps].[sp_GetActualSubmissionPeriod]'))
    DROP PROCEDURE [apps].[sp_GetActualSubmissionPeriod];
GO

CREATE PROCEDURE [apps].[sp_GetActualSubmissionPeriod]
    @SubmissionId       NVARCHAR(50),
    @SubmissionPeriod   NVARCHAR(50)
AS
BEGIN
    SELECT @SubmissionPeriod AS ActualSubmissionPeriod
END
GO
