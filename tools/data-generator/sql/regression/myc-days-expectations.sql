/*
  Expected output of sp_GetApprovedSubmissionsMyc for the fixture in myc-days-fixture.sql.

  Values are written by hand from the rules of the procedure, not read from its output:
    ExpTonnes = round((sum(weight kg) - sum(transitional kg)) / 1000, 0)
    ExpDays   = num_days_obligated of the determination row that matches
                (organisation_id, subsidiary_id, submitter_id) with obligation_status = 'O', for year PeriodYear + 1.
                NULL when there is no such row.

  A scenario with no row here must produce no output at all (S13 one half-year only, S14 small producer,
  S15 deleted organisation). Rows labelled "characterisation" pin current behaviour that may not be what
  you want; if a deliberate change alters them, update the expectation consciously.

  Only S01's days value is derived from its joiner date (01/07/2032 in a leap year = 184 days). In the other
  scenarios the day counts are distinct marker values, chosen so that a wrong join shows up as a wrong number.
*/
SET NOCOUNT ON;

CREATE TABLE #Expected (
    Scn varchar(10) NOT NULL, PeriodYear varchar(4) NOT NULL,
    OrganisationId uniqueidentifier NOT NULL, SubmitterId uniqueidentifier NOT NULL, SubmitterType varchar(50) NOT NULL,
    PackagingMaterial varchar(50) NOT NULL, ExpTonnes int NOT NULL, ExpDays smallint NULL, Note varchar(120) NULL);

-- Submitter is 'D:<org ref of the submitting direct registrant>' or 'C:<compliance scheme key>'.
INSERT INTO #Expected (Scn, PeriodYear, OrganisationId, SubmitterId, SubmitterType, PackagingMaterial, ExpTonnes, ExpDays, Note)
SELECT x.Scn, x.PeriodYear, p.ExtGuid,
    CASE WHEN LEFT(x.Submitter, 2) = 'D:' THEN (SELECT ExtGuid FROM #FxOrg WHERE OrgRef = CAST(SUBSTRING(x.Submitter, 3, 20) AS int))
         ELSE CAST(HASHBYTES('MD5', CONCAT('myc-regression:cs:', SUBSTRING(x.Submitter, 3, 20))) AS uniqueidentifier) END,
    CASE WHEN LEFT(x.Submitter, 2) = 'D:' THEN 'DirectRegistrant' ELSE 'ComplianceScheme' END,
    x.Material, x.ExpTonnes, x.ExpDays, x.Note
FROM (VALUES
    ('S01', '2031', 9100001, 'D:9100001', 'PL', 2,  184,  'partial-year days pass through'),
    ('S02', '2031', 9100002, 'D:9100002', 'PL', 2,  NULL, 'obligated, no days = full year'),
    ('S03', '2031', 9100003, 'D:9100003', 'GL', 6,  NULL, 'error row: no days'),
    ('S04', '2031', 9100004, 'D:9100004', 'AL', 8,  NULL, 'not obligated: stray days must not leak'),
    ('S05', '2031', 9100005, 'C:cs-a',    'PL', 10, 200,  'scheme submission uses the scheme row, not the decoy direct row'),
    ('S06', '2031', 9100006, 'D:9100006', 'PL', 2,  50,   'same producer, direct submission'),
    ('S06', '2031', 9100006, 'C:cs-b',    'PL', 6,  200,  'same producer, scheme submission'),
    ('S07', '2031', 9100008, 'D:9100007', 'PL', 14, 120,  'subsidiary matched on subsidiary_id'),
    ('S08', '2031', 9100009, 'D:9100009', 'PL', 2,  90,   'POM subsidiary_id empty string vs determination NULL'),
    ('S09', '2031', 9100010, 'D:9100010', 'PL', 2,  91,   'POM subsidiary_id NULL vs determination empty string'),
    ('S10', '2031', 9100011, 'D:9100011', 'PL', 2,  NULL, 'determination rows only for other years'),
    ('S11', '2031', 9100012, 'D:9100012', 'PL', 2,  100,  'characterisation: two obligated rows split the output'),
    ('S11', '2031', 9100012, 'D:9100012', 'PL', 2,  150,  'characterisation: two obligated rows split the output'),
    ('S12', '2031', 9100013, 'D:9100013', 'PL', 4,  10,   'characterisation: identical duplicate determination rows double the weight'),
    ('S16', '2031', 9100017, 'D:9100017', 'PL', 9,  10,   'transitional units subtracted, 8.5 rounds to 9'),
    ('S17', '2031', 9100018, 'D:9100018', 'PL', 2,  45,   'material and type filters applied'),
    ('S18', '2031', 9100019, 'D:9100019', 'PL', 2,  60,   'each material row carries the days'),
    ('S18', '2031', 9100019, 'D:9100019', 'GL', 4,  60,   'each material row carries the days'),
    ('S19', '2031', 9100020, 'D:9100020', 'PL', 5,  25,   'newer accepted H1 file replaces the older one'),
    ('S20', '2024', 9100021, 'D:9100021', 'PL', 2,  40,   '2024 P1 + P4 period set')
) AS x (Scn, PeriodYear, ProducerRef, Submitter, Material, ExpTonnes, ExpDays, Note)
INNER JOIN #FxOrg p ON p.OrgRef = x.ProducerRef;
