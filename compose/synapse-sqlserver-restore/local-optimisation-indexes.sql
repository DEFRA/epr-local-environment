/*
   LOCAL ENVIRONMENT ONLY — OPTIONAL PERFORMANCE OPTIMISATION

   These nonclustered indexes are not part of epr-data-sqldb and must never be
   treated as a Synapse schema change. They make the SQL Server representation
   practical for the future-state Record Waste Packaging query and other local queries
   that explicitly use the local access projections. The restore script runs
   this file only when
   APPLY_LOCAL_OPTIMISATION_INDEXES=true.

   Each index is idempotent. Setting the environment variable to false prevents
   future creation; it intentionally does not drop indexes already created in a
   local database.
*/

IF OBJECT_ID(N'rpd.SubmissionEvents', N'U') IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'rpd.SubmissionEvents') AND name = N'IX_Local_SubmissionEvents_ApprovedPom')
    CREATE NONCLUSTERED INDEX IX_Local_SubmissionEvents_ApprovedPom
        ON rpd.SubmissionEvents (LocalType, LocalDecision, LocalSubmissionId, LocalCreated DESC)
        INCLUDE (LocalFileId);
GO

IF OBJECT_ID(N'rpd.cosmos_file_metadata', N'U') IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'rpd.cosmos_file_metadata') AND name = N'IX_Local_CosmosFileMetadata_FileId')
    CREATE NONCLUSTERED INDEX IX_Local_CosmosFileMetadata_FileId
        ON rpd.cosmos_file_metadata (LocalFileId)
        INCLUDE (LocalFileName, LocalComplianceSchemeId, LocalSubmissionPeriod);
GO

IF OBJECT_ID(N'rpd.cosmos_file_metadata', N'U') IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'rpd.cosmos_file_metadata') AND name = N'IX_Local_CosmosFileMetadata_Submitter')
    CREATE NONCLUSTERED INDEX IX_Local_CosmosFileMetadata_Submitter
        ON rpd.cosmos_file_metadata (LocalComplianceSchemeId)
        INCLUDE (LocalFileId, LocalFileName, LocalSubmissionPeriod);
GO

IF OBJECT_ID(N'rpd.Pom', N'U') IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'rpd.Pom') AND name = N'IX_Local_Pom_FilePeriodSizeOrganisation')
    CREATE NONCLUSTERED INDEX IX_Local_Pom_FilePeriodSizeOrganisation
        ON rpd.Pom (LocalFileName, LocalSubmissionPeriod, LocalOrganisationSize, organisation_id)
        INCLUDE (LocalSubsidiaryId);
GO

IF OBJECT_ID(N'rpd.Pom', N'U') IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'rpd.Pom') AND name = N'IX_Local_Pom_FileOrganisationSubsidiary')
    CREATE NONCLUSTERED INDEX IX_Local_Pom_FileOrganisationSubsidiary
        ON rpd.Pom (LocalFileName, organisation_id, LocalSubsidiaryId);
GO

IF OBJECT_ID(N'rpd.Organisations', N'U') IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'rpd.Organisations') AND name = N'IX_Local_Organisations_ReferenceNumber')
    CREATE NONCLUSTERED INDEX IX_Local_Organisations_ReferenceNumber
        ON rpd.Organisations (LocalReferenceNumber)
        INCLUDE (LocalExternalId, IsDeleted);
GO

IF OBJECT_ID(N'dbo.t_producer_obligation_determination', N'U') IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.t_producer_obligation_determination') AND name = N'IX_Local_ProducerObligationDetermination_YearStatusSubmitter')
    CREATE NONCLUSTERED INDEX IX_Local_ProducerObligationDetermination_YearStatusSubmitter
        ON dbo.t_producer_obligation_determination (submission_period_year, obligation_status, LocalSubmitterId, organisation_id, LocalSubsidiaryId)
        INCLUDE (num_days_obligated);
GO
