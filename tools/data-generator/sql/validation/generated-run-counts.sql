/* Local run-scoped check. Replace @RunId and @PomYear from the run manifest. */
DECLARE @RunId varchar(100) = 'replace-with-manifest-run-id';
DECLARE @PomYear int = 2025;
DECLARE @FilePrefix nvarchar(4000) = CONCAT('data-generator/', @RunId, '/%');
DECLARE @PrnPrefix nvarchar(4000) = CONCAT('DG-', @RunId, '-%');

SELECT
    (SELECT COUNT(*) FROM rpd.Pom WHERE FileName LIKE @FilePrefix) AS PomRows,
    (SELECT COUNT(*) FROM rpd.cosmos_file_metadata WHERE FileName LIKE @FilePrefix) AS MetadataRows,
    (
        SELECT COUNT(*)
        FROM rpd.SubmissionEvents eventRow
        INNER JOIN rpd.cosmos_file_metadata metadata ON metadata.FileId = eventRow.FileId
        WHERE metadata.FileName LIKE @FilePrefix
          AND eventRow.Type = 'RegulatorPoMDecision'
          AND eventRow.Decision = 'Accepted'
    ) AS AcceptedDecisionRows,
    (SELECT COUNT(*) FROM EprPrnBackend.dbo.Prn WHERE PrnNumber LIKE @PrnPrefix) AS PrnRows,
    (SELECT ISNULL(SUM(TonnageValue), 0) FROM EprPrnBackend.dbo.Prn WHERE PrnNumber LIKE @PrnPrefix) AS PrnTonnes;

CREATE TABLE #ApprovedSubmissions
(
    SubmissionPeriod varchar(4) NOT NULL,
    SubmitterType varchar(50) NOT NULL,
    SubmitterId uniqueidentifier NOT NULL,
    OrganisationId uniqueidentifier NOT NULL,
    PackagingMaterial varchar(3) NOT NULL,
    PackagingMaterialWeight int NOT NULL,
    NumberOfDaysObligated smallint NULL
);

INSERT INTO #ApprovedSubmissions
EXEC dbo.sp_GetApprovedSubmissionsMyc
    @PeriodYear = CONVERT(varchar(4), @PomYear),
    @IncludePackagingTypes = 'HH,NH,PB,HDC,NDC',
    @IncludePackagingMaterials = 'AL,FC,GL,PC,PL,ST,WD';

SELECT SubmitterType, PackagingMaterial, COUNT(*) AS ApiRows, SUM(PackagingMaterialWeight) AS OutputTonnes
FROM #ApprovedSubmissions
GROUP BY SubmitterType, PackagingMaterial
ORDER BY SubmitterType, PackagingMaterial;

DROP TABLE #ApprovedSubmissions;
