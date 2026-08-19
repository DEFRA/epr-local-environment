/*
   LOCAL ENVIRONMENT ONLY

   epr-data-sqldb models several Synapse text fields as nvarchar(4000). Those
   fields exceed SQL Server's nonclustered-index key limit. These bounded,
   persisted projections are a local SQL Server access layer for the embedded
   recycling-data query; they do not belong in epr-data-sqldb or Synapse.

   The query retains its original full-value comparisons after using these
   projections, so a value longer than the local projection cannot change the
   result set. This script is idempotent and deliberately runs even when the
   optional physical optimisation indexes are disabled.
*/

IF OBJECT_ID(N'rpd.SubmissionEvents', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'rpd.SubmissionEvents') AND name = N'LocalSubmissionId')
        ALTER TABLE rpd.SubmissionEvents ADD LocalSubmissionId AS CONVERT(nvarchar(255), SubmissionId) PERSISTED;
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'rpd.SubmissionEvents') AND name = N'LocalFileId')
        ALTER TABLE rpd.SubmissionEvents ADD LocalFileId AS CONVERT(nvarchar(255), FileId) PERSISTED;
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'rpd.SubmissionEvents') AND name = N'LocalType')
        ALTER TABLE rpd.SubmissionEvents ADD LocalType AS CONVERT(nvarchar(128), Type) PERSISTED;
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'rpd.SubmissionEvents') AND name = N'LocalDecision')
        ALTER TABLE rpd.SubmissionEvents ADD LocalDecision AS CONVERT(nvarchar(128), Decision) PERSISTED;
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'rpd.SubmissionEvents') AND name = N'LocalCreated')
        ALTER TABLE rpd.SubmissionEvents ADD LocalCreated AS CONVERT(nvarchar(64), Created) PERSISTED;
END;
GO

IF OBJECT_ID(N'rpd.cosmos_file_metadata', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'rpd.cosmos_file_metadata') AND name = N'LocalFileName')
        ALTER TABLE rpd.cosmos_file_metadata ADD LocalFileName AS CONVERT(nvarchar(255), FileName) PERSISTED;
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'rpd.cosmos_file_metadata') AND name = N'LocalFileId')
        ALTER TABLE rpd.cosmos_file_metadata ADD LocalFileId AS CONVERT(nvarchar(255), FileId) PERSISTED;
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'rpd.cosmos_file_metadata') AND name = N'LocalComplianceSchemeId')
        ALTER TABLE rpd.cosmos_file_metadata ADD LocalComplianceSchemeId AS CONVERT(nvarchar(255), ComplianceSchemeId) PERSISTED;
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'rpd.cosmos_file_metadata') AND name = N'LocalSubmissionPeriod')
        ALTER TABLE rpd.cosmos_file_metadata ADD LocalSubmissionPeriod AS CONVERT(nvarchar(64), SubmissionPeriod) PERSISTED;
END;
GO

IF OBJECT_ID(N'rpd.Pom', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'rpd.Pom') AND name = N'LocalFileName')
        ALTER TABLE rpd.Pom ADD LocalFileName AS CONVERT(nvarchar(255), FileName) PERSISTED;
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'rpd.Pom') AND name = N'LocalSubmissionPeriod')
        ALTER TABLE rpd.Pom ADD LocalSubmissionPeriod AS CONVERT(nvarchar(64), submission_period) PERSISTED;
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'rpd.Pom') AND name = N'LocalOrganisationSize')
        ALTER TABLE rpd.Pom ADD LocalOrganisationSize AS CONVERT(nvarchar(32), organisation_size) PERSISTED;
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'rpd.Pom') AND name = N'LocalSubsidiaryId')
        ALTER TABLE rpd.Pom ADD LocalSubsidiaryId AS CONVERT(nvarchar(255), subsidiary_id) PERSISTED;
END;
GO

IF OBJECT_ID(N'rpd.Organisations', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'rpd.Organisations') AND name = N'LocalReferenceNumber')
        ALTER TABLE rpd.Organisations ADD LocalReferenceNumber AS CONVERT(nvarchar(255), ReferenceNumber) PERSISTED;
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'rpd.Organisations') AND name = N'LocalExternalId')
        ALTER TABLE rpd.Organisations ADD LocalExternalId AS CONVERT(nvarchar(255), ExternalId) PERSISTED;
END;
GO

IF OBJECT_ID(N'dbo.t_producer_obligation_determination', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.t_producer_obligation_determination') AND name = N'LocalSubsidiaryId')
        ALTER TABLE dbo.t_producer_obligation_determination ADD LocalSubsidiaryId AS CONVERT(nvarchar(255), subsidiary_id) PERSISTED;
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.t_producer_obligation_determination') AND name = N'LocalSubmitterId')
        ALTER TABLE dbo.t_producer_obligation_determination ADD LocalSubmitterId AS CONVERT(nvarchar(255), submitter_id) PERSISTED;
END;
GO
