/*
  Fixture for the sp_GetApprovedSubmissionsMyc regression check (days obligated).

  Do not run this directly against a database you care about: it is concatenated by
  run-myc-days-regression.sh and executed inside one transaction that is always rolled back.

  Isolation:
    - POM year 2031 (determination year 2032) and one 2024 producer, so no overlap with generated data.
    - Organisation references 9100001-9199999; POM/metadata FileName prefix 'myc-regression/'.
    - GUIDs are derived from fixed keys, so every run produces identical identifiers.

  Determination rows are seeded as INPUT data for the procedure under test (the procedure only
  reads dbo.t_producer_obligation_determination). Their columns and codes follow the output of the notebook
  epr-data/notebook/producer_obligation_determination.json (epr-data commit 8ae21f7); they are not a
  re-implementation of that notebook. Only S01's day count is derived from its joiner date (01/07/2032 in
  a leap year = 184); elsewhere the day counts are distinct marker values and the joiner dates are decorative.
*/
SET NOCOUNT ON;

-- 0. Remove anything a previous aborted run left behind
DELETE FROM rpd.SubmissionEvents WHERE FileId IN (SELECT FileId FROM rpd.cosmos_file_metadata WHERE FileName LIKE 'myc-regression/%');
DELETE FROM rpd.cosmos_file_metadata WHERE FileName LIKE 'myc-regression/%';
DELETE FROM rpd.Pom WHERE FileName LIKE 'myc-regression/%';
DELETE FROM rpd.Organisations WHERE Id BETWEEN 9100001 AND 9199999;
DELETE FROM dbo.t_producer_obligation_determination WHERE organisation_id BETWEEN 9100001 AND 9199999;

-- 1. Organisations (the producer itself, the parent of a subsidiary, a deleted org)
CREATE TABLE #FxOrg (OrgRef int NOT NULL, Scn varchar(10) NOT NULL, IsDeleted bit NOT NULL, ExtGuid uniqueidentifier NOT NULL);
INSERT INTO #FxOrg (OrgRef, Scn, IsDeleted, ExtGuid)
SELECT v.OrgRef, v.Scn, v.IsDeleted, CAST(HASHBYTES('MD5', CONCAT('myc-regression:org:', v.OrgRef)) AS uniqueidentifier)
FROM (VALUES
    (9100001, 'S01', 0), (9100002, 'S02', 0), (9100003, 'S03', 0), (9100004, 'S04', 0),
    (9100005, 'S05', 0), (9100006, 'S06', 0), (9100007, 'S07', 0), (9100008, 'S07', 0),
    (9100009, 'S08', 0), (9100010, 'S09', 0), (9100011, 'S10', 0), (9100012, 'S11', 0),
    (9100013, 'S12', 0), (9100014, 'S13', 0), (9100015, 'S14', 0), (9100016, 'S15', 1),
    (9100017, 'S16', 0), (9100018, 'S17', 0), (9100019, 'S18', 0), (9100020, 'S19', 0),
    (9100021, 'S20', 0)
) AS v (OrgRef, Scn, IsDeleted);

INSERT INTO rpd.Organisations (Id, OrganisationTypeId, CompaniesHouseNumber, Name, TradingName, ReferenceNumber,
    ValidatedWithCompaniesHouse, IsComplianceScheme, NationId, ExternalId, CreatedOn, LastUpdatedOn, IsDeleted, ProducerTypeId, load_ts)
SELECT OrgRef, 1, CONCAT('MYC', OrgRef), CONCAT('MYC Regression ', Scn, ' / ', OrgRef), NULL, CAST(OrgRef AS nvarchar(50)),
    1, 0, 1, LOWER(CONVERT(nvarchar(36), ExtGuid)), CONVERT(nvarchar(30), GETDATE(), 126), CONVERT(nvarchar(30), GETDATE(), 126), IsDeleted, 0, SYSDATETIME()
FROM #FxOrg;

-- 2. POM specification: one row per POM line. A FileKey is one uploaded and accepted POM file.
--    SubRef '' / NULL are deliberately both used (the procedure treats them as "no subsidiary").
CREATE TABLE #PomSpec (
    Scn varchar(10) NOT NULL, FileKey varchar(60) NOT NULL, Period varchar(10) NOT NULL,
    OrgRef int NOT NULL, SubRef nvarchar(50) NULL, CsKey varchar(20) NULL,
    Material nvarchar(10) NOT NULL, PkgType nvarchar(10) NOT NULL, Size nvarchar(1) NOT NULL,
    WeightKg float NOT NULL, TransKg float NULL, Created nvarchar(30) NOT NULL);

INSERT INTO #PomSpec (Scn, FileKey, Period, OrgRef, SubRef, CsKey, Material, PkgType, Size, WeightKg, TransKg, Created) VALUES
-- S01 direct producer, partial-year obligation (joiner 01/07/2032 -> 184 days)
('S01','s01-h1','2031-H1',9100001,NULL,NULL,'PL','HH','L',1000,NULL,'2031-07-01T10:00:00'),
('S01','s01-h2','2031-H2',9100001,NULL,NULL,'PL','HH','L',1000,NULL,'2031-07-01T10:00:00'),
-- S02 obligated, full year (days NULL)
('S02','s02-h1','2031-H1',9100002,NULL,NULL,'PL','HH','L',1000,NULL,'2031-07-01T10:00:00'),
('S02','s02-h2','2031-H2',9100002,NULL,NULL,'PL','HH','L',1000,NULL,'2031-07-01T10:00:00'),
-- S03 determination is an error
('S03','s03-h1','2031-H1',9100003,NULL,NULL,'GL','HH','L',3000,NULL,'2031-07-01T10:00:00'),
('S03','s03-h2','2031-H2',9100003,NULL,NULL,'GL','HH','L',3000,NULL,'2031-07-01T10:00:00'),
-- S04 determination is Not Obligated but carries a stray day count that must not leak through
('S04','s04-h1','2031-H1',9100004,NULL,NULL,'AL','HH','L',4000,NULL,'2031-07-01T10:00:00'),
('S04','s04-h2','2031-H2',9100004,NULL,NULL,'AL','HH','L',4000,NULL,'2031-07-01T10:00:00'),
-- S05 member submitted through compliance scheme cs-a only; a decoy direct determination row exists
('S05','s05-cs-h1','2031-H1',9100005,NULL,'cs-a','PL','HH','L',5000,NULL,'2031-07-01T10:00:00'),
('S05','s05-cs-h2','2031-H2',9100005,NULL,'cs-a','PL','HH','L',5000,NULL,'2031-07-01T10:00:00'),
-- S06 same producer submits directly (1 t + 1 t) and through scheme cs-b (3 t + 3 t)
('S06','s06-d-h1','2031-H1',9100006,NULL,NULL,'PL','HH','L',1000,NULL,'2031-07-01T10:00:00'),
('S06','s06-d-h2','2031-H2',9100006,NULL,NULL,'PL','HH','L',1000,NULL,'2031-07-01T10:00:00'),
('S06','s06-cs-h1','2031-H1',9100006,NULL,'cs-b','PL','HH','L',3000,NULL,'2031-07-01T10:00:00'),
('S06','s06-cs-h2','2031-H2',9100006,NULL,'cs-b','PL','HH','L',3000,NULL,'2031-07-01T10:00:00'),
-- S07 subsidiary 9100008 reported under parent 9100007
('S07','s07-h1','2031-H1',9100007,'9100008',NULL,'PL','HH','L',7000,NULL,'2031-07-01T10:00:00'),
('S07','s07-h2','2031-H2',9100007,'9100008',NULL,'PL','HH','L',7000,NULL,'2031-07-01T10:00:00'),
-- S08 POM subsidiary_id is an empty string, determination subsidiary_id is NULL
('S08','s08-h1','2031-H1',9100009,'',NULL,'PL','HH','L',1000,NULL,'2031-07-01T10:00:00'),
('S08','s08-h2','2031-H2',9100009,'',NULL,'PL','HH','L',1000,NULL,'2031-07-01T10:00:00'),
-- S09 POM subsidiary_id is NULL, determination subsidiary_id is an empty string
('S09','s09-h1','2031-H1',9100010,NULL,NULL,'PL','HH','L',1000,NULL,'2031-07-01T10:00:00'),
('S09','s09-h2','2031-H2',9100010,NULL,NULL,'PL','HH','L',1000,NULL,'2031-07-01T10:00:00'),
-- S10 determination rows exist only for other years
('S10','s10-h1','2031-H1',9100011,NULL,NULL,'PL','HH','L',1000,NULL,'2031-07-01T10:00:00'),
('S10','s10-h2','2031-H2',9100011,NULL,NULL,'PL','HH','L',1000,NULL,'2031-07-01T10:00:00'),
-- S11 two obligated determination rows with different days (characterisation)
('S11','s11-h1','2031-H1',9100012,NULL,NULL,'PL','HH','L',1000,NULL,'2031-07-01T10:00:00'),
('S11','s11-h2','2031-H2',9100012,NULL,NULL,'PL','HH','L',1000,NULL,'2031-07-01T10:00:00'),
-- S12 two identical obligated determination rows (characterisation: weight is doubled by the join)
('S12','s12-h1','2031-H1',9100013,NULL,NULL,'PL','HH','L',1000,NULL,'2031-07-01T10:00:00'),
('S12','s12-h2','2031-H2',9100013,NULL,NULL,'PL','HH','L',1000,NULL,'2031-07-01T10:00:00'),
-- S13 only one half-year submitted: must not appear
('S13','s13-h1','2031-H1',9100014,NULL,NULL,'PL','HH','L',1000,NULL,'2031-07-01T10:00:00'),
-- S14 small producer: must not appear
('S14','s14-h1','2031-H1',9100015,NULL,NULL,'PL','HH','S',1000,NULL,'2031-07-01T10:00:00'),
('S14','s14-h2','2031-H2',9100015,NULL,NULL,'PL','HH','S',1000,NULL,'2031-07-01T10:00:00'),
-- S15 soft-deleted organisation: must not appear
('S15','s15-h1','2031-H1',9100016,NULL,NULL,'PL','HH','L',1000,NULL,'2031-07-01T10:00:00'),
('S15','s15-h2','2031-H2',9100016,NULL,NULL,'PL','HH','L',1000,NULL,'2031-07-01T10:00:00'),
-- S16 transitional units are subtracted before rounding: (10000 - 1500) / 1000 = 8.5 -> 9
('S16','s16-h1','2031-H1',9100017,NULL,NULL,'PL','HH','L',5000,1500,'2031-07-01T10:00:00'),
('S16','s16-h2','2031-H2',9100017,NULL,NULL,'PL','HH','L',5000,NULL,'2031-07-01T10:00:00'),
-- S17 material/type filters: only PL + HH counts (OT is not an included material, CW is not an included type)
('S17','s17-h1','2031-H1',9100018,NULL,NULL,'PL','HH','L',1000,NULL,'2031-07-01T10:00:00'),
('S17','s17-h1','2031-H1',9100018,NULL,NULL,'OT','HH','L',5000,NULL,'2031-07-01T10:00:00'),
('S17','s17-h1','2031-H1',9100018,NULL,NULL,'PL','CW','L',7000,NULL,'2031-07-01T10:00:00'),
('S17','s17-h2','2031-H2',9100018,NULL,NULL,'PL','HH','L',1000,NULL,'2031-07-01T10:00:00'),
('S17','s17-h2','2031-H2',9100018,NULL,NULL,'OT','HH','L',5000,NULL,'2031-07-01T10:00:00'),
('S17','s17-h2','2031-H2',9100018,NULL,NULL,'PL','CW','L',7000,NULL,'2031-07-01T10:00:00'),
-- S18 two materials: each output row carries the same days
('S18','s18-h1','2031-H1',9100019,NULL,NULL,'PL','HH','L',1000,NULL,'2031-07-01T10:00:00'),
('S18','s18-h1','2031-H1',9100019,NULL,NULL,'GL','HH','L',2000,NULL,'2031-07-01T10:00:00'),
('S18','s18-h2','2031-H2',9100019,NULL,NULL,'PL','HH','L',1000,NULL,'2031-07-01T10:00:00'),
('S18','s18-h2','2031-H2',9100019,NULL,NULL,'GL','HH','L',2000,NULL,'2031-07-01T10:00:00'),
-- S19 H1 resubmitted: the newer accepted file (4000 kg) replaces the older one (1000 kg)
('S19','s19-h1-v1','2031-H1',9100020,NULL,NULL,'PL','HH','L',1000,NULL,'2031-07-01T10:00:00'),
('S19','s19-h1-v2','2031-H1',9100020,NULL,NULL,'PL','HH','L',4000,NULL,'2031-07-02T10:00:00'),
('S19','s19-h2','2031-H2',9100020,NULL,NULL,'PL','HH','L',1000,NULL,'2031-07-01T10:00:00'),
-- S20 2024 period set (P1 + P4), determination year 2025
('S20','s20-p1','2024-P1',9100021,NULL,NULL,'PL','HH','L',1000,NULL,'2024-07-01T10:00:00'),
('S20','s20-p4','2024-P4',9100021,NULL,NULL,'PL','HH','L',1000,NULL,'2024-07-01T10:00:00');

-- 3. One accepted file (metadata + regulator decision) per FileKey, then the POM rows
INSERT INTO rpd.cosmos_file_metadata (SubmissionId, FileId, UserId, BlobName, BlobContainerName, FileType, Created, OriginalFileName,
    OrganisationId, DataSourceType, SubmissionPeriod, IsSubmitted, SubmissionType, ComplianceSchemeId, FileName, load_ts)
SELECT
    LOWER(CONVERT(nvarchar(36), CAST(HASHBYTES('MD5', CONCAT('myc-regression:sub:', f.FileKey)) AS uniqueidentifier))),
    LOWER(CONVERT(nvarchar(36), CAST(HASHBYTES('MD5', CONCAT('myc-regression:file:', f.FileKey)) AS uniqueidentifier))),
    LOWER(CONVERT(nvarchar(36), CAST(HASHBYTES('MD5', 'myc-regression:user') AS uniqueidentifier))),
    f.FileKey, 'epr-antivirus-pom', 'Pom', f.Created, CONCAT(f.FileKey, '.csv'),
    LOWER(CONVERT(nvarchar(36), o.ExtGuid)), 'File',
    CASE WHEN RIGHT(f.Period, 2) IN ('H1', 'P1', 'P2') THEN CONCAT('January to June ', LEFT(f.Period, 4))
         ELSE CONCAT('July to December ', LEFT(f.Period, 4)) END,
    1, 'Producer',
    CASE WHEN f.CsKey IS NULL THEN NULL
         ELSE LOWER(CONVERT(nvarchar(36), CAST(HASHBYTES('MD5', CONCAT('myc-regression:cs:', f.CsKey)) AS uniqueidentifier))) END,
    CONCAT('myc-regression/', f.FileKey), SYSDATETIME()
FROM (SELECT FileKey, MIN(Period) AS Period, MIN(OrgRef) AS OrgRef, MIN(CsKey) AS CsKey, MIN(Created) AS Created
      FROM #PomSpec GROUP BY FileKey) AS f
INNER JOIN #FxOrg o ON o.OrgRef = f.OrgRef;

INSERT INTO rpd.SubmissionEvents (Created, SubmissionEventId, SubmissionId, Decision, FileId, id, Type, load_ts)
SELECT m.Created, e.EventId, m.SubmissionId, 'Accepted', m.FileId, CONCAT('RegulatorPoMDecision|', e.EventId), 'RegulatorPoMDecision', SYSDATETIME()
FROM rpd.cosmos_file_metadata m
CROSS APPLY (SELECT LOWER(CONVERT(nvarchar(36), CAST(HASHBYTES('MD5', CONCAT('myc-regression:event:', m.BlobName)) AS uniqueidentifier))) AS EventId) e
WHERE m.FileName LIKE 'myc-regression/%';

INSERT INTO rpd.Pom (organisation_id, subsidiary_id, organisation_size, submission_period, packaging_activity, packaging_type, packaging_class,
    packaging_material, packaging_material_subtype, from_country, to_country, packaging_material_weight, packaging_material_units,
    transitional_packaging_units, ram_rag_rating, load_ts, FileName)
SELECT OrgRef, SubRef, Size, Period, 'SO', PkgType, 'P1', Material, NULL, NULL, NULL, WeightKg, NULL, TransKg, 'G', SYSDATETIME(), CONCAT('myc-regression/', FileKey)
FROM #PomSpec;

-- Subsidiary 9100008 needs its own organisation row (the procedure resolves the producer by its reference number).
-- It is in #FxOrg above (scenario S07).

-- 4. Determination rows (INPUT to the procedure). Submitter is 'D:<org ref>' for a direct submission or 'C:<scheme key>'.
CREATE TABLE #DetSpec (
    Scn varchar(10) NOT NULL, OrgRef int NOT NULL, SubRef nvarchar(50) NULL, Submitter varchar(30) NOT NULL,
    StatusCode nvarchar(10) NULL, JoinerDate nvarchar(50) NULL, ObligationStatus char(1) NOT NULL,
    Days smallint NULL, ErrorCode nvarchar(256) NULL, YearOfDetermination int NOT NULL);

INSERT INTO #DetSpec (Scn, OrgRef, SubRef, Submitter, StatusCode, JoinerDate, ObligationStatus, Days, ErrorCode, YearOfDetermination) VALUES
('S01', 9100001, NULL,      'D:9100001', '02',  '01/07/2032', 'O', 184,  NULL, 2032),
('S02', 9100002, NULL,      'D:9100002', NULL,  NULL,         'O', NULL, NULL, 2032),
('S03', 9100003, NULL,      'D:9100003', '20',  NULL,         'E', NULL, 'Conflicting Obligations (Leaver Codes)', 2032),
('S04', 9100004, NULL,      'D:9100004', '21',  NULL,         'N', 100,  NULL, 2032),
('S05', 9100005, NULL,      'C:cs-a',    '02',  '01/05/2032', 'O', 200,  NULL, 2032),
('S05', 9100005, NULL,      'D:9100005', '02',  '01/11/2032', 'O', 50,   NULL, 2032),   -- decoy: no POM under this submitter
('S06', 9100006, NULL,      'D:9100006', '02',  '12/11/2032', 'O', 50,   NULL, 2032),
('S06', 9100006, NULL,      'C:cs-b',    '03',  '01/05/2032', 'O', 200,  NULL, 2032),
('S07', 9100007, '9100008', 'D:9100007', '03',  '01/09/2032', 'O', 120,  NULL, 2032),
('S07', 9100007, NULL,      'D:9100007', NULL,  NULL,         'O', NULL, NULL, 2032),
('S08', 9100009, NULL,      'D:9100009', '02',  '01/10/2032', 'O', 90,   NULL, 2032),
('S09', 9100010, '',        'D:9100010', '02',  '01/10/2032', 'O', 91,   NULL, 2032),
('S10', 9100011, NULL,      'D:9100011', '02',  '01/06/2031', 'O', 77,   NULL, 2031),
('S10', 9100011, NULL,      'D:9100011', '02',  '01/06/2033', 'O', 88,   NULL, 2033),
('S11', 9100012, NULL,      'D:9100012', '02',  '01/10/2032', 'O', 100,  NULL, 2032),
('S11', 9100012, NULL,      'D:9100012', '03',  '01/08/2032', 'O', 150,  NULL, 2032),
('S12', 9100013, NULL,      'D:9100013', '02',  '01/12/2032', 'O', 10,   NULL, 2032),
('S12', 9100013, NULL,      'D:9100013', '02',  '01/12/2032', 'O', 10,   NULL, 2032),
('S13', 9100014, NULL,      'D:9100014', '02',  '01/12/2032', 'O', 30,   NULL, 2032),
('S14', 9100015, NULL,      'D:9100015', '02',  '01/12/2032', 'O', 30,   NULL, 2032),
('S15', 9100016, NULL,      'D:9100016', '02',  '01/12/2032', 'O', 30,   NULL, 2032),
('S16', 9100017, NULL,      'D:9100017', '02',  '22/12/2032', 'O', 10,   NULL, 2032),
('S17', 9100018, NULL,      'D:9100018', '02',  '17/11/2032', 'O', 45,   NULL, 2032),
('S18', 9100019, NULL,      'D:9100019', '02',  '01/11/2032', 'O', 60,   NULL, 2032),
('S19', 9100020, NULL,      'D:9100020', '02',  '06/12/2032', 'O', 25,   NULL, 2032),
('S20', 9100021, NULL,      'D:9100021', '02',  '21/11/2025', 'O', 40,   NULL, 2025);

INSERT INTO dbo.t_producer_obligation_determination (organisation_id, subsidiary_id, submitter_id, organisation_name, trading_name,
    status_code, leaver_date, joiner_date, obligation_status, num_days_obligated, error_code, submission_period_year)
SELECT d.OrgRef, d.SubRef,
    CASE WHEN LEFT(d.Submitter, 2) = 'D:'
         THEN LOWER(CONVERT(nvarchar(36), (SELECT ExtGuid FROM #FxOrg WHERE OrgRef = CAST(SUBSTRING(d.Submitter, 3, 20) AS int))))
         ELSE LOWER(CONVERT(nvarchar(36), CAST(HASHBYTES('MD5', CONCAT('myc-regression:cs:', SUBSTRING(d.Submitter, 3, 20))) AS uniqueidentifier))) END,
    CONCAT('MYC Regression ', d.Scn), NULL, d.StatusCode, NULL, d.JoinerDate, d.ObligationStatus, d.Days, d.ErrorCode, d.YearOfDetermination
FROM #DetSpec d;
