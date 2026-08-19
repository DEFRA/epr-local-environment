/* Anonymous PRN and active-calculation baseline. @ObligationYear is POM year + 1. */
DECLARE @ObligationYear int = 2026;

-- Result set 1: PRN status/volume shape, with no organisation identifiers.
SELECT
    CASE submitterType.TypeName
        WHEN 'ComplianceScheme' THEN 'ComplianceScheme'
        WHEN 'DirectRegistrant' THEN 'DirectRegistrant'
        ELSE 'No matching calculation submitter'
    END AS SubmitterType,
    status.StatusName AS PrnStatus,
    COUNT(*) AS PrnRows,
    COUNT(DISTINCT prn.OrganisationId) AS Submitters,
    SUM(prn.TonnageValue) AS PrnTonnes
FROM Prn prn
INNER JOIN PrnStatus status ON status.Id = prn.PrnStatusId
LEFT JOIN ObligationCalculationOrganisationSubmitterType submitterType
    ON submitterType.Id = (
        SELECT TOP (1) calculation.SubmitterTypeId
        FROM ObligationCalculations calculation
        WHERE calculation.SubmitterId = prn.OrganisationId
          AND calculation.Year = @ObligationYear
          AND calculation.IsDeleted = 0
    )
WHERE prn.ObligationYear = CONVERT(varchar(4), @ObligationYear)
GROUP BY submitterType.TypeName, status.StatusName
ORDER BY SubmitterType, PrnStatus;

-- Result set 2: GlassRemelt is intentionally included as a downstream GL expansion.
SELECT
    submitterType.TypeName AS SubmitterType,
    material.MaterialCode AS Material,
    COUNT(*) AS ActiveCalculationRows,
    COUNT(DISTINCT calculation.SubmitterId) AS Submitters,
    COUNT(DISTINCT calculation.OrganisationId) AS Producers,
    SUM(calculation.Tonnage) AS InputPomTonnes,
    SUM(calculation.MaterialObligationValue) AS ObligationTonnes
FROM ObligationCalculations calculation
INNER JOIN Material material ON material.Id = calculation.MaterialId
INNER JOIN ObligationCalculationOrganisationSubmitterType submitterType
    ON submitterType.Id = calculation.SubmitterTypeId
WHERE calculation.Year = @ObligationYear
  AND calculation.IsDeleted = 0
GROUP BY submitterType.TypeName, material.MaterialCode
ORDER BY submitterType.TypeName, material.MaterialCode;
