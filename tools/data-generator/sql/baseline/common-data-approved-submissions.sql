/* Anonymous SP-output baseline. Run unchanged against pre-production or local. */
DECLARE @PomYear varchar(4) = '2025';
DECLARE @PackagingTypes varchar(max) = 'HH,NH,PB,HDC,NDC';
DECLARE @PackagingMaterials varchar(max) = 'AL,FC,GL,PC,PL,ST,WD';

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
    @PeriodYear = @PomYear,
    @IncludePackagingTypes = @PackagingTypes,
    @IncludePackagingMaterials = @PackagingMaterials;

-- Result set 1: material/output size shape. No organisation identifiers are returned.
SELECT
    SubmitterType,
    SubmissionPeriod,
    PackagingMaterial,
    COUNT(*) AS ApiRows,
    COUNT(DISTINCT SubmitterId) AS Submitters,
    COUNT(DISTINCT OrganisationId) AS Producers,
    SUM(PackagingMaterialWeight) AS OutputTonnes,
    SUM(CASE WHEN NumberOfDaysObligated IS NULL THEN 1 ELSE 0 END) AS NullNumberOfDaysObligatedRows
FROM #ApprovedSubmissions
GROUP BY SubmitterType, SubmissionPeriod, PackagingMaterial
ORDER BY SubmitterType, SubmissionPeriod, PackagingMaterial;

-- Result set 2: producer cardinality per submitter, retained only as anonymous bands.
WITH SubmitterProducerCounts AS
(
    SELECT SubmitterType, SubmitterId, COUNT(DISTINCT OrganisationId) AS ProducerCount
    FROM #ApprovedSubmissions
    GROUP BY SubmitterType, SubmitterId
)
SELECT
    SubmitterType,
    CASE
        WHEN ProducerCount = 1 THEN '1 producer'
        WHEN ProducerCount BETWEEN 2 AND 5 THEN '2-5 producers'
        WHEN ProducerCount BETWEEN 6 AND 20 THEN '6-20 producers'
        WHEN ProducerCount BETWEEN 21 AND 100 THEN '21-100 producers'
        WHEN ProducerCount BETWEEN 101 AND 500 THEN '101-500 producers'
        WHEN ProducerCount BETWEEN 501 AND 2000 THEN '501-2,000 producers'
        ELSE '2,001+ producers'
    END AS ProducerBand,
    COUNT(*) AS Submitters
FROM SubmitterProducerCounts
GROUP BY SubmitterType,
    CASE
        WHEN ProducerCount = 1 THEN '1 producer'
        WHEN ProducerCount BETWEEN 2 AND 5 THEN '2-5 producers'
        WHEN ProducerCount BETWEEN 6 AND 20 THEN '6-20 producers'
        WHEN ProducerCount BETWEEN 21 AND 100 THEN '21-100 producers'
        WHEN ProducerCount BETWEEN 101 AND 500 THEN '101-500 producers'
        WHEN ProducerCount BETWEEN 501 AND 2000 THEN '501-2,000 producers'
        ELSE '2,001+ producers'
    END
ORDER BY SubmitterType, ProducerBand;

DROP TABLE #ApprovedSubmissions;
