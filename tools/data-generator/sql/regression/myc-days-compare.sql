/*
  Runs the baseline and candidate copies of sp_GetApprovedSubmissionsMyc over the fixture and reports:
    L1  baseline vs candidate: any difference in the full output (rows, weights, days, row counts)
    L2  each run vs the hand-written expectations, for the fixture producers only

  Needs, in the same session: #FxOrg (fixture), #Expected (expectations) and the procedures
  dbo.sp_GetApprovedSubmissionsMyc_regr_baseline / _regr_candidate (installed by the runner).
  No findings means everything passed.
*/
SET NOCOUNT ON;

DECLARE @Types varchar(max) = 'HH,NH,PB,HDC,NDC';
DECLARE @Materials varchar(max) = 'AL,FC,GL,PC,PL,ST,WD';

CREATE TABLE #Tmp (
    SubmissionPeriod varchar(4) NOT NULL, SubmitterType varchar(50) NOT NULL, SubmitterId uniqueidentifier NOT NULL,
    OrganisationId uniqueidentifier NOT NULL, PackagingMaterial varchar(50) NOT NULL,
    PackagingMaterialWeight int NOT NULL, NumberOfDaysObligated smallint NULL);

CREATE TABLE #Out (
    RunName varchar(10) NOT NULL, PeriodYear varchar(4) NOT NULL, SubmitterType varchar(50) NOT NULL, SubmitterId uniqueidentifier NOT NULL,
    OrganisationId uniqueidentifier NOT NULL, PackagingMaterial varchar(50) NOT NULL,
    PackagingMaterialWeight int NOT NULL, NumberOfDaysObligated smallint NULL);

-- 2031 exercises the H1/H2 period set, 2024 the P1/P4 period set.
INSERT INTO #Tmp EXEC dbo.sp_GetApprovedSubmissionsMyc_regr_baseline @PeriodYear = '2031', @IncludePackagingTypes = @Types, @IncludePackagingMaterials = @Materials;
INSERT INTO #Out SELECT 'baseline', '2031', SubmitterType, SubmitterId, OrganisationId, PackagingMaterial, PackagingMaterialWeight, NumberOfDaysObligated FROM #Tmp;
DELETE FROM #Tmp;
INSERT INTO #Tmp EXEC dbo.sp_GetApprovedSubmissionsMyc_regr_baseline @PeriodYear = '2024', @IncludePackagingTypes = @Types, @IncludePackagingMaterials = @Materials;
INSERT INTO #Out SELECT 'baseline', '2024', SubmitterType, SubmitterId, OrganisationId, PackagingMaterial, PackagingMaterialWeight, NumberOfDaysObligated FROM #Tmp;
DELETE FROM #Tmp;
INSERT INTO #Tmp EXEC dbo.sp_GetApprovedSubmissionsMyc_regr_candidate @PeriodYear = '2031', @IncludePackagingTypes = @Types, @IncludePackagingMaterials = @Materials;
INSERT INTO #Out SELECT 'candidate', '2031', SubmitterType, SubmitterId, OrganisationId, PackagingMaterial, PackagingMaterialWeight, NumberOfDaysObligated FROM #Tmp;
DELETE FROM #Tmp;
INSERT INTO #Tmp EXEC dbo.sp_GetApprovedSubmissionsMyc_regr_candidate @PeriodYear = '2024', @IncludePackagingTypes = @Types, @IncludePackagingMaterials = @Materials;
INSERT INTO #Out SELECT 'candidate', '2024', SubmitterType, SubmitterId, OrganisationId, PackagingMaterial, PackagingMaterialWeight, NumberOfDaysObligated FROM #Tmp;

CREATE TABLE #Findings (
    Layer char(2) NOT NULL, RunName varchar(10) NOT NULL, Scn varchar(10) NULL, Problem varchar(40) NOT NULL,
    PeriodYear varchar(4) NULL, OrgRef int NULL, SubmitterType varchar(50) NULL, PackagingMaterial varchar(50) NULL,
    A_Tonnes int NULL, A_Days smallint NULL, A_Rows int NULL, B_Tonnes int NULL, B_Days smallint NULL, B_Rows int NULL,
    Meaning varchar(160) NULL);

-- L1: baseline (A) vs candidate (B) over everything the procedure returns
WITH b AS (
    SELECT PeriodYear, SubmitterType, SubmitterId, OrganisationId, PackagingMaterial, PackagingMaterialWeight, NumberOfDaysObligated, COUNT(*) AS n
    FROM #Out WHERE RunName = 'baseline'
    GROUP BY PeriodYear, SubmitterType, SubmitterId, OrganisationId, PackagingMaterial, PackagingMaterialWeight, NumberOfDaysObligated),
c AS (
    SELECT PeriodYear, SubmitterType, SubmitterId, OrganisationId, PackagingMaterial, PackagingMaterialWeight, NumberOfDaysObligated, COUNT(*) AS n
    FROM #Out WHERE RunName = 'candidate'
    GROUP BY PeriodYear, SubmitterType, SubmitterId, OrganisationId, PackagingMaterial, PackagingMaterialWeight, NumberOfDaysObligated)
INSERT INTO #Findings (Layer, RunName, Scn, Problem, PeriodYear, OrgRef, SubmitterType, PackagingMaterial, A_Tonnes, A_Days, A_Rows, B_Tonnes, B_Days, B_Rows, Meaning)
SELECT 'L1', 'candidate', fx.Scn,
    CASE WHEN c.n IS NULL THEN 'row missing from candidate' WHEN b.n IS NULL THEN 'row only in candidate' ELSE 'row count differs' END,
    COALESCE(b.PeriodYear, c.PeriodYear), fx.OrgRef, COALESCE(b.SubmitterType, c.SubmitterType), COALESCE(b.PackagingMaterial, c.PackagingMaterial),
    b.PackagingMaterialWeight, b.NumberOfDaysObligated, b.n, c.PackagingMaterialWeight, c.NumberOfDaysObligated, c.n,
    'A = baseline, B = candidate'
FROM b FULL OUTER JOIN c
    ON  b.PeriodYear = c.PeriodYear AND b.SubmitterType = c.SubmitterType AND b.SubmitterId = c.SubmitterId
    AND b.OrganisationId = c.OrganisationId AND b.PackagingMaterial = c.PackagingMaterial
    AND b.PackagingMaterialWeight = c.PackagingMaterialWeight
    AND (b.NumberOfDaysObligated = c.NumberOfDaysObligated OR (b.NumberOfDaysObligated IS NULL AND c.NumberOfDaysObligated IS NULL))
LEFT JOIN #FxOrg fx ON fx.ExtGuid = COALESCE(b.OrganisationId, c.OrganisationId)
WHERE b.n IS NULL OR c.n IS NULL OR b.n <> c.n;

-- L2: each run (B = actual) vs expectations (A = expected), restricted to the fixture producers
DECLARE @run varchar(10);
DECLARE run_cursor CURSOR LOCAL FAST_FORWARD FOR SELECT 'baseline' UNION ALL SELECT 'candidate';
OPEN run_cursor;
FETCH NEXT FROM run_cursor INTO @run;
WHILE @@FETCH_STATUS = 0
BEGIN
    WITH e AS (
        SELECT PeriodYear, SubmitterType, SubmitterId, OrganisationId, PackagingMaterial, ExpTonnes, ExpDays, COUNT(*) AS n
        FROM #Expected GROUP BY PeriodYear, SubmitterType, SubmitterId, OrganisationId, PackagingMaterial, ExpTonnes, ExpDays),
    a AS (
        SELECT PeriodYear, SubmitterType, SubmitterId, OrganisationId, PackagingMaterial, PackagingMaterialWeight, NumberOfDaysObligated, COUNT(*) AS n
        FROM #Out
        WHERE RunName = @run AND OrganisationId IN (SELECT ExtGuid FROM #FxOrg)
        GROUP BY PeriodYear, SubmitterType, SubmitterId, OrganisationId, PackagingMaterial, PackagingMaterialWeight, NumberOfDaysObligated)
    INSERT INTO #Findings (Layer, RunName, Scn, Problem, PeriodYear, OrgRef, SubmitterType, PackagingMaterial, A_Tonnes, A_Days, A_Rows, B_Tonnes, B_Days, B_Rows, Meaning)
    SELECT 'L2', @run, fx.Scn,
        CASE WHEN a.n IS NULL THEN 'expected row not returned' WHEN e.n IS NULL THEN 'unexpected row returned' ELSE 'row count differs' END,
        COALESCE(e.PeriodYear, a.PeriodYear), fx.OrgRef, COALESCE(e.SubmitterType, a.SubmitterType), COALESCE(e.PackagingMaterial, a.PackagingMaterial),
        e.ExpTonnes, e.ExpDays, e.n, a.PackagingMaterialWeight, a.NumberOfDaysObligated, a.n,
        'A = expected, B = actual'
    FROM e FULL OUTER JOIN a
        ON  e.PeriodYear = a.PeriodYear AND e.SubmitterType = a.SubmitterType AND e.SubmitterId = a.SubmitterId
        AND e.OrganisationId = a.OrganisationId AND e.PackagingMaterial = a.PackagingMaterial
        AND e.ExpTonnes = a.PackagingMaterialWeight
        AND (e.ExpDays = a.NumberOfDaysObligated OR (e.ExpDays IS NULL AND a.NumberOfDaysObligated IS NULL))
    LEFT JOIN #FxOrg fx ON fx.ExtGuid = COALESCE(e.OrganisationId, a.OrganisationId)
    WHERE e.n IS NULL OR a.n IS NULL OR e.n <> a.n;

    FETCH NEXT FROM run_cursor INTO @run;
END
CLOSE run_cursor;
DEALLOCATE run_cursor;

-- Report
SELECT 'Rows returned' AS Metric, RunName, PeriodYear, COUNT(*) AS Value FROM #Out GROUP BY RunName, PeriodYear ORDER BY RunName, PeriodYear;
SELECT 'Fixture rows expected' AS Metric, COUNT(*) AS Value FROM #Expected;

IF EXISTS (SELECT 1 FROM #Findings)
    SELECT Layer, RunName, Scn, Problem, PeriodYear, OrgRef, SubmitterType, PackagingMaterial,
           A_Tonnes, A_Days, A_Rows, B_Tonnes, B_Days, B_Rows, Meaning
    FROM #Findings ORDER BY Layer, RunName, Scn, PeriodYear, OrgRef, PackagingMaterial;

DECLARE @l1 int = (SELECT COUNT(*) FROM #Findings WHERE Layer = 'L1');
DECLARE @l2c int = (SELECT COUNT(*) FROM #Findings WHERE Layer = 'L2' AND RunName = 'candidate');
DECLARE @l2b int = (SELECT COUNT(*) FROM #Findings WHERE Layer = 'L2' AND RunName = 'baseline');
PRINT CONCAT('L1 baseline vs candidate differences: ', @l1);
PRINT CONCAT('L2 candidate vs expectations mismatches: ', @l2c);
PRINT CONCAT('L2 baseline vs expectations mismatches: ', @l2b, CASE WHEN @l2b > 0 THEN '  (expectations or characterisation notes need review)' ELSE '' END);

-- Leave nothing behind, then fail the run if anything was found.
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
IF @l1 + @l2c + @l2b > 0
    RAISERROR('sp_GetApprovedSubmissionsMyc regression check FAILED', 16, 1);
ELSE
    PRINT 'sp_GetApprovedSubmissionsMyc regression check PASSED';
