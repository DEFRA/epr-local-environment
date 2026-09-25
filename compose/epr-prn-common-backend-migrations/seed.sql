-- common to all local seed.sql files
declare @organisationExternalId uniqueidentifier
set @organisationExternalId = '94BFC917-B9B6-45D7-847B-E5F500BFE198'

-- common to all local seed.sql files
declare @complianceSchemeExternalId uniqueidentifier
set @complianceSchemeExternalId = 'D93376E3-0681-46BE-AEB4-7450A2E784D8'

insert into ObligationCalculations (OrganisationId, MaterialObligationValue, Year, CalculatedOn, Tonnage, MaterialId, SubmitterId, SubmitterTypeId) values (@organisationExternalId, 100, 2025, '2025-03-01', 100, 3, @complianceSchemeExternalId, 2)
insert into ObligationCalculations (OrganisationId, MaterialObligationValue, Year, CalculatedOn, Tonnage, MaterialId, SubmitterId, SubmitterTypeId) values (@organisationExternalId, 200, 2025, '2025-03-01', 200, 6, @complianceSchemeExternalId, 2)

insert into ObligationCalculations (OrganisationId, MaterialObligationValue, Year, CalculatedOn, Tonnage, MaterialId, SubmitterId, SubmitterTypeId) values (@organisationExternalId, 100, 2026, '2026-03-01', 100, 3, @complianceSchemeExternalId, 2)
insert into ObligationCalculations (OrganisationId, MaterialObligationValue, Year, CalculatedOn, Tonnage, MaterialId, SubmitterId, SubmitterTypeId) values (@organisationExternalId, 200, 2026, '2026-03-01', 200, 6, @complianceSchemeExternalId, 2)

-- all PRN data assumes coverage of 2025, 2026 and 2027 accreditation/obligation years

insert into Prn (PrnNumber, OrganisationId, OrganisationName, ProducerAgency, ReprocessorExporterAgency, PrnStatusId, TonnageValue, MaterialName, IssuerReference, IssueDate, DecemberWaste, IssuedByOrg, AccreditationNumber, AccreditationYear, ObligationYear, PackagingProducer, CreatedOn, LastUpdatedBy, ExternalId, IsExport, LastUpdatedDate, SourceSystemId) values ('PRN-001-NPWD', @complianceSchemeExternalId, 'Organisation Name', 'Producer Agency', 'Reprocessor Exporter Agency', 4, 1, 'Glass Other', 'Issuer Reference', '2025-03-01T00:00:00+00:00', 0, 'Issued By Org', 'Accred Num', '2025', '2025', 'Packaging Producer', '2025-03-01', '00000000-0000-0000-0000-000000000000', NEWID(), 0, '2025-03-01', NULL)
insert into Prn (PrnNumber, OrganisationId, OrganisationName, ProducerAgency, ReprocessorExporterAgency, PrnStatusId, TonnageValue, MaterialName, IssuerReference, IssueDate, DecemberWaste, IssuedByOrg, AccreditationNumber, AccreditationYear, ObligationYear, PackagingProducer, CreatedOn, LastUpdatedBy, ExternalId, IsExport, LastUpdatedDate, SourceSystemId) values ('PRN-002-NPWD-DEC', @complianceSchemeExternalId, 'Organisation Name', 'Producer Agency', 'Reprocessor Exporter Agency', 4, 1, 'Glass Other', 'Issuer Reference', '2025-03-01T00:00:00+00:00', 1, 'Issued By Org', 'Accred Num', '2025', '2025', 'Packaging Producer', '2025-03-01', '00000000-0000-0000-0000-000000000000', NEWID(), 0, '2025-03-01', NULL)

-- a non NULL SourceSystemId field denotes a new RREPW PRN
insert into Prn (PrnNumber, OrganisationId, OrganisationName, ProducerAgency, ReprocessorExporterAgency, PrnStatusId, TonnageValue, MaterialName, IssuerReference, IssueDate, DecemberWaste, IssuedByOrg, AccreditationNumber, AccreditationYear, ObligationYear, PackagingProducer, CreatedOn, LastUpdatedBy, ExternalId, IsExport, LastUpdatedDate, SourceSystemId) values ('PRN-003-RREPW', @complianceSchemeExternalId, 'Organisation Name', 'Producer Agency', 'Reprocessor Exporter Agency', 4, 1, 'Glass Other', 'Issuer Reference', '2026-03-01T00:00:00+00:00', 0, 'Issued By Org', 'Accred Num', '2026', '2026', 'Packaging Producer', '2026-03-01', '00000000-0000-0000-0000-000000000000', NEWID(), 0, '2026-03-01', 'RREPW')
insert into Prn (PrnNumber, OrganisationId, OrganisationName, ProducerAgency, ReprocessorExporterAgency, PrnStatusId, TonnageValue, MaterialName, IssuerReference, IssueDate, DecemberWaste, IssuedByOrg, AccreditationNumber, AccreditationYear, ObligationYear, PackagingProducer, CreatedOn, LastUpdatedBy, ExternalId, IsExport, LastUpdatedDate, SourceSystemId) values ('PRN-004-RREPW-DEC', @complianceSchemeExternalId, 'Organisation Name', 'Producer Agency', 'Reprocessor Exporter Agency', 4, 1, 'Glass Other', 'Issuer Reference', '2026-03-01T00:00:00+00:00', 1, 'Issued By Org', 'Accred Num', '2026', '2026', 'Packaging Producer', '2026-03-01', '00000000-0000-0000-0000-000000000000', NEWID(), 0, '2026-03-01', 'RREPW')
insert into Prn (PrnNumber, OrganisationId, OrganisationName, ProducerAgency, ReprocessorExporterAgency, PrnStatusId, TonnageValue, MaterialName, IssuerReference, IssueDate, DecemberWaste, IssuedByOrg, AccreditationNumber, AccreditationYear, ObligationYear, PackagingProducer, CreatedOn, LastUpdatedBy, ExternalId, IsExport, LastUpdatedDate, SourceSystemId) values ('PRN-009-RREPW', @complianceSchemeExternalId, 'Organisation Name', 'Producer Agency', 'Reprocessor Exporter Agency', 4, 1, 'Glass Other', 'Issuer Reference', '2026-03-01T00:00:00+00:00', 0, 'Issued By Org', 'Accred Num', '2027', '2027', 'Packaging Producer', '2026-03-01', '00000000-0000-0000-0000-000000000000', NEWID(), 0, '2026-03-01', 'RREPW')
insert into Prn (PrnNumber, OrganisationId, OrganisationName, ProducerAgency, ReprocessorExporterAgency, PrnStatusId, TonnageValue, MaterialName, IssuerReference, IssueDate, DecemberWaste, IssuedByOrg, AccreditationNumber, AccreditationYear, ObligationYear, PackagingProducer, CreatedOn, LastUpdatedBy, ExternalId, IsExport, LastUpdatedDate, SourceSystemId) values ('PRN-010-RREPW-DEC', @complianceSchemeExternalId, 'Organisation Name', 'Producer Agency', 'Reprocessor Exporter Agency', 4, 1, 'Glass Other', 'Issuer Reference', '2026-03-01T00:00:00+00:00', 1, 'Issued By Org', 'Accred Num', '2027', '2027', 'Packaging Producer', '2026-03-01', '00000000-0000-0000-0000-000000000000', NEWID(), 0, '2026-03-01', 'RREPW')

-- replicate historic PRNs as seen in prod
insert into Prn (PrnNumber, OrganisationId, OrganisationName, ProducerAgency, ReprocessorExporterAgency, PrnStatusId, TonnageValue, MaterialName, IssuerReference, IssueDate, DecemberWaste, IssuedByOrg, AccreditationNumber, AccreditationYear, ObligationYear, PackagingProducer, CreatedOn, LastUpdatedBy, ExternalId, IsExport, LastUpdatedDate, SourceSystemId) values ('PRN-005-OLD', @complianceSchemeExternalId, 'Organisation Name', 'Producer Agency', 'Reprocessor Exporter Agency', 1, 1, 'Glass Other', 'Issuer Reference', '2025-03-01T00:00:00+00:00', 0, 'Issued By Org', 'Accred Num', '2024', '2025', 'Packaging Producer', '2025-03-01', '00000000-0000-0000-0000-000000000000', NEWID(), 0, '2025-03-01', NULL)
insert into Prn (PrnNumber, OrganisationId, OrganisationName, ProducerAgency, ReprocessorExporterAgency, PrnStatusId, TonnageValue, MaterialName, IssuerReference, IssueDate, DecemberWaste, IssuedByOrg, AccreditationNumber, AccreditationYear, ObligationYear, PackagingProducer, CreatedOn, LastUpdatedBy, ExternalId, IsExport, LastUpdatedDate, SourceSystemId) values ('PRN-006-OLD-DEC', @complianceSchemeExternalId, 'Organisation Name', 'Producer Agency', 'Reprocessor Exporter Agency', 1, 1, 'Glass Other', 'Issuer Reference', '2025-03-01T00:00:00+00:00', 1, 'Issued By Org', 'Accred Num', '2024', '2025', 'Packaging Producer', '2025-03-01', '00000000-0000-0000-0000-000000000000', NEWID(), 0, '2025-03-01', NULL)
insert into Prn (PrnNumber, OrganisationId, OrganisationName, ProducerAgency, ReprocessorExporterAgency, PrnStatusId, TonnageValue, MaterialName, IssuerReference, IssueDate, DecemberWaste, IssuedByOrg, AccreditationNumber, AccreditationYear, ObligationYear, PackagingProducer, CreatedOn, LastUpdatedBy, ExternalId, IsExport, LastUpdatedDate, SourceSystemId) values ('PRN-007-OLD-DEC', @complianceSchemeExternalId, 'Organisation Name', 'Producer Agency', 'Reprocessor Exporter Agency', 1, 1, 'Glass Other', 'Issuer Reference', '2025-03-01T00:00:00+00:00', 1, 'Issued By Org', 'Accred Num', '2025', '2025', 'Packaging Producer', '2025-03-01', '00000000-0000-0000-0000-000000000000', NEWID(), 0, '2025-03-01', NULL)
insert into Prn (PrnNumber, OrganisationId, OrganisationName, ProducerAgency, ReprocessorExporterAgency, PrnStatusId, TonnageValue, MaterialName, IssuerReference, IssueDate, DecemberWaste, IssuedByOrg, AccreditationNumber, AccreditationYear, ObligationYear, PackagingProducer, CreatedOn, LastUpdatedBy, ExternalId, IsExport, LastUpdatedDate, SourceSystemId) values ('PRN-008-CURRENT', @complianceSchemeExternalId, 'Organisation Name', 'Producer Agency', 'Reprocessor Exporter Agency', 1, 1, 'Glass Other', 'Issuer Reference', '2025-03-01T00:00:00+00:00', 0, 'Issued By Org', 'Accred Num', '2026', '2026', 'Packaging Producer', '2025-03-01', '00000000-0000-0000-0000-000000000000', NEWID(), 0, '2025-03-01', NULL)
insert into Prn (PrnNumber, OrganisationId, OrganisationName, ProducerAgency, ReprocessorExporterAgency, PrnStatusId, TonnageValue, MaterialName, IssuerReference, IssueDate, DecemberWaste, IssuedByOrg, AccreditationNumber, AccreditationYear, ObligationYear, PackagingProducer, CreatedOn, LastUpdatedBy, ExternalId, IsExport, LastUpdatedDate, SourceSystemId) values ('PRN-011-OLD-DEC', @complianceSchemeExternalId, 'Organisation Name', 'Producer Agency', 'Reprocessor Exporter Agency', 4, 1, 'Glass Other', 'Issuer Reference', '2025-03-01T00:00:00+00:00', 1, 'Issued By Org', 'Accred Num', '2024', '2025', 'Packaging Producer', '2025-03-01', '00000000-0000-0000-0000-000000000000', NEWID(), 0, '2025-03-01', NULL)

-- Fibre
insert into Prn (PrnNumber, OrganisationId, OrganisationName, ProducerAgency, ReprocessorExporterAgency, PrnStatusId, TonnageValue, MaterialName, IssuerReference, IssueDate, DecemberWaste, IssuedByOrg, AccreditationNumber, AccreditationYear, ObligationYear, PackagingProducer, CreatedOn, LastUpdatedBy, ExternalId, IsExport, LastUpdatedDate, SourceSystemId) values ('PRN-012-RREPW', @complianceSchemeExternalId, 'Organisation Name', 'Producer Agency', 'Reprocessor Exporter Agency', 4, 1, 'Fibre', 'Issuer Reference', '2026-03-01T00:00:00+00:00', 1, 'Issued By Org', 'Accred Num', '2026', '2026', 'Packaging Producer', '2026-03-01', '00000000-0000-0000-0000-000000000000', NEWID(), 0, '2026-03-01', 'RREPW')
insert into Prn (PrnNumber, OrganisationId, OrganisationName, ProducerAgency, ReprocessorExporterAgency, PrnStatusId, TonnageValue, MaterialName, IssuerReference, IssueDate, DecemberWaste, IssuedByOrg, AccreditationNumber, AccreditationYear, ObligationYear, PackagingProducer, CreatedOn, LastUpdatedBy, ExternalId, IsExport, LastUpdatedDate, SourceSystemId) values ('PRN-013-RREPW', @complianceSchemeExternalId, 'Organisation Name', 'Producer Agency', 'Reprocessor Exporter Agency', 4, 1, 'Fibre', 'Issuer Reference', '2026-05-01T00:00:00+00:00', 1, 'Issued By Org', 'Accred Num', '2026', '2026', 'Packaging Producer', '2026-03-01', '00000000-0000-0000-0000-000000000000', NEWID(), 0, '2026-03-01', 'RREPW')

-- Paper/board
insert into Prn (PrnNumber, OrganisationId, OrganisationName, ProducerAgency, ReprocessorExporterAgency, PrnStatusId, TonnageValue, MaterialName, IssuerReference, IssueDate, DecemberWaste, IssuedByOrg, AccreditationNumber, AccreditationYear, ObligationYear, PackagingProducer, CreatedOn, LastUpdatedBy, ExternalId, IsExport, LastUpdatedDate, SourceSystemId) values ('PRN-014-RREPW', @complianceSchemeExternalId, 'Organisation Name', 'Producer Agency', 'Reprocessor Exporter Agency', 4, 1, 'Paper/board', 'Issuer Reference', '2026-04-15T00:00:00+00:00', 1, 'Issued By Org', 'Accred Num', '2026', '2026', 'Packaging Producer', '2026-04-15', '00000000-0000-0000-0000-000000000000', NEWID(), 0, '2026-03-01', 'RREPW')
insert into Prn (PrnNumber, OrganisationId, OrganisationName, ProducerAgency, ReprocessorExporterAgency, PrnStatusId, TonnageValue, MaterialName, IssuerReference, IssueDate, DecemberWaste, IssuedByOrg, AccreditationNumber, AccreditationYear, ObligationYear, PackagingProducer, CreatedOn, LastUpdatedBy, ExternalId, IsExport, LastUpdatedDate, SourceSystemId) values ('PRN-015-RREPW', @complianceSchemeExternalId, 'Organisation Name', 'Producer Agency', 'Reprocessor Exporter Agency', 4, 1, 'Paper/board', 'Issuer Reference', '2026-04-16T00:00:00+00:00', 1, 'Issued By Org', 'Accred Num', '2026', '2026', 'Packaging Producer', '2026-04-16', '00000000-0000-0000-0000-000000000000', NEWID(), 0, '2026-03-01', 'RREPW')
insert into Prn (PrnNumber, OrganisationId, OrganisationName, ProducerAgency, ReprocessorExporterAgency, PrnStatusId, TonnageValue, MaterialName, IssuerReference, IssueDate, DecemberWaste, IssuedByOrg, AccreditationNumber, AccreditationYear, ObligationYear, PackagingProducer, CreatedOn, LastUpdatedBy, ExternalId, IsExport, LastUpdatedDate, SourceSystemId) values ('PRN-016-RREPW', @complianceSchemeExternalId, 'Organisation Name', 'Producer Agency', 'Reprocessor Exporter Agency', 4, 1, 'Paper/board', 'Issuer Reference', '2026-04-15T00:00:00+00:00', 1, 'Issued By Org', 'Accred Num', '2026', '2026', 'Packaging Producer', '2026-04-15', '00000000-0000-0000-0000-000000000000', NEWID(), 0, '2026-03-01', 'RREPW')
insert into Prn (PrnNumber, OrganisationId, OrganisationName, ProducerAgency, ReprocessorExporterAgency, PrnStatusId, TonnageValue, MaterialName, IssuerReference, IssueDate, DecemberWaste, IssuedByOrg, AccreditationNumber, AccreditationYear, ObligationYear, PackagingProducer, CreatedOn, LastUpdatedBy, ExternalId, IsExport, LastUpdatedDate, SourceSystemId) values ('PRN-017-RREPW', @complianceSchemeExternalId, 'Organisation Name', 'Producer Agency', 'Reprocessor Exporter Agency', 4, 1, 'Paper/board', 'Issuer Reference', '2026-04-16T00:00:00+00:00', 1, 'Issued By Org', 'Accred Num', '2026', '2026', 'Packaging Producer', '2026-04-16', '00000000-0000-0000-0000-000000000000', NEWID(), 0, '2026-03-01', 'RREPW')

-- PERN (IsExport = 1). The only export note for the compliance scheme: accepted, so it
-- also exercises the accepted-PERN wording. ReprocessingSite is the overseas reprocessor.
insert into Prn (PrnNumber, OrganisationId, OrganisationName, ProducerAgency, ReprocessorExporterAgency, PrnStatusId, TonnageValue, MaterialName, IssuerReference, IssueDate, DecemberWaste, IssuedByOrg, AccreditationNumber, AccreditationYear, ObligationYear, PackagingProducer, CreatedOn, LastUpdatedBy, ExternalId, IsExport, LastUpdatedDate, SourceSystemId, PrnSignatory, PrnSignatoryPosition, ReprocessingSite, ProcessToBeUsed, IssuerNotes) values ('PERN-001-RREPW', @complianceSchemeExternalId, 'Organisation Name', 'EA', 'EA', 1, 60, 'Plastic', 'ECO/2026/EX/0118', '2026-04-20T09:32:00+00:00', 0, 'ECO Plastics Ltd', 'EX262008105', '2026', '2026', 'Packaging Producer', '2026-04-20', '00000000-0000-0000-0000-000000000000', NEWID(), 1, '2026-04-21', 'RREPW', 'Priya Raman', 'Export Compliance Manager', 'Suzhou Huaqiang Plastics Co Ltd, Jiangsu, China', 'R3', 'Consignment exported under Annex VII. Reprocessing confirmed at overseas site.')

-- Rejected and cancelled. The PrnStatus lookup has carried these since the first
-- migration but no row ever used them, so neither status could be seen in the UI or
-- exercised by the status mapper. Issuer detail is backfilled by the update at the end.
insert into Prn (PrnNumber, OrganisationId, OrganisationName, ProducerAgency, ReprocessorExporterAgency, PrnStatusId, TonnageValue, MaterialName, IssuerReference, IssueDate, DecemberWaste, IssuedByOrg, AccreditationNumber, AccreditationYear, ObligationYear, PackagingProducer, CreatedOn, LastUpdatedBy, ExternalId, IsExport, LastUpdatedDate, SourceSystemId) values ('PRN-018-REJECTED', @complianceSchemeExternalId, 'Organisation Name', 'Producer Agency', 'Reprocessor Exporter Agency', 2, 25, 'Glass Other', 'Issuer Reference', '2026-05-06T00:00:00+00:00', 0, 'Issued By Org', 'Accred Num', '2026', '2026', 'Packaging Producer', '2026-05-06', '00000000-0000-0000-0000-000000000000', NEWID(), 0, '2026-05-07', 'RREPW')
insert into Prn (PrnNumber, OrganisationId, OrganisationName, ProducerAgency, ReprocessorExporterAgency, PrnStatusId, TonnageValue, MaterialName, IssuerReference, IssueDate, DecemberWaste, IssuedByOrg, AccreditationNumber, AccreditationYear, ObligationYear, PackagingProducer, CreatedOn, LastUpdatedBy, ExternalId, IsExport, LastUpdatedDate, SourceSystemId) values ('PRN-019-CANCELLED', @complianceSchemeExternalId, 'Organisation Name', 'Producer Agency', 'Reprocessor Exporter Agency', 3, 40, 'Paper/board', 'Issuer Reference', '2026-05-07T00:00:00+00:00', 0, 'Issued By Org', 'Accred Num', '2026', '2026', 'Packaging Producer', '2026-05-07', '00000000-0000-0000-0000-000000000000', NEWID(), 0, '2026-05-10', 'RREPW')

-- =====================================================
-- Direct Producer (DP) seed data: POP QUEST LTD
-- =====================================================

declare @dpOrgExternalId uniqueidentifier
set @dpOrgExternalId = 'e2316c5e-d434-41da-8274-494dc0762d20'

-- DP ObligationCalculations (SubmitterTypeId = 1 for direct producer)
insert into ObligationCalculations (OrganisationId, MaterialObligationValue, Year, CalculatedOn, Tonnage, MaterialId, SubmitterId, SubmitterTypeId) values (@dpOrgExternalId, 100, 2025, '2025-03-01', 100, 3, @dpOrgExternalId, 1)
insert into ObligationCalculations (OrganisationId, MaterialObligationValue, Year, CalculatedOn, Tonnage, MaterialId, SubmitterId, SubmitterTypeId) values (@dpOrgExternalId, 200, 2025, '2025-03-01', 200, 6, @dpOrgExternalId, 1)

insert into ObligationCalculations (OrganisationId, MaterialObligationValue, Year, CalculatedOn, Tonnage, MaterialId, SubmitterId, SubmitterTypeId) values (@dpOrgExternalId, 100, 2026, '2026-03-01', 100, 3, @dpOrgExternalId, 1)
insert into ObligationCalculations (OrganisationId, MaterialObligationValue, Year, CalculatedOn, Tonnage, MaterialId, SubmitterId, SubmitterTypeId) values (@dpOrgExternalId, 200, 2026, '2026-03-01', 200, 6, @dpOrgExternalId, 1)

-- DP PRN data
insert into Prn (PrnNumber, OrganisationId, OrganisationName, ProducerAgency, ReprocessorExporterAgency, PrnStatusId, TonnageValue, MaterialName, IssuerReference, IssueDate, DecemberWaste, IssuedByOrg, AccreditationNumber, AccreditationYear, ObligationYear, PackagingProducer, CreatedOn, LastUpdatedBy, ExternalId, IsExport, LastUpdatedDate, SourceSystemId) values ('DP-PRN-001-NPWD', @dpOrgExternalId, 'POP QUEST LTD', 'Producer Agency', 'Reprocessor Exporter Agency', 4, 1, 'Glass Other', 'Issuer Reference', '2025-03-01T00:00:00+00:00', 0, 'Issued By Org', 'Accred Num', '2025', '2025', 'Packaging Producer', '2025-03-01', '00000000-0000-0000-0000-000000000000', NEWID(), 0, '2025-03-01', NULL)
insert into Prn (PrnNumber, OrganisationId, OrganisationName, ProducerAgency, ReprocessorExporterAgency, PrnStatusId, TonnageValue, MaterialName, IssuerReference, IssueDate, DecemberWaste, IssuedByOrg, AccreditationNumber, AccreditationYear, ObligationYear, PackagingProducer, CreatedOn, LastUpdatedBy, ExternalId, IsExport, LastUpdatedDate, SourceSystemId) values ('DP-PRN-002-NPWD-DEC', @dpOrgExternalId, 'POP QUEST LTD', 'Producer Agency', 'Reprocessor Exporter Agency', 4, 1, 'Glass Other', 'Issuer Reference', '2025-03-01T00:00:00+00:00', 1, 'Issued By Org', 'Accred Num', '2025', '2025', 'Packaging Producer', '2025-03-01', '00000000-0000-0000-0000-000000000000', NEWID(), 0, '2025-03-01', NULL)

-- RREPW PRNs
insert into Prn (PrnNumber, OrganisationId, OrganisationName, ProducerAgency, ReprocessorExporterAgency, PrnStatusId, TonnageValue, MaterialName, IssuerReference, IssueDate, DecemberWaste, IssuedByOrg, AccreditationNumber, AccreditationYear, ObligationYear, PackagingProducer, CreatedOn, LastUpdatedBy, ExternalId, IsExport, LastUpdatedDate, SourceSystemId) values ('DP-PRN-003-RREPW', @dpOrgExternalId, 'POP QUEST LTD', 'Producer Agency', 'Reprocessor Exporter Agency', 4, 1, 'Glass Other', 'Issuer Reference', '2026-03-01T00:00:00+00:00', 0, 'Issued By Org', 'Accred Num', '2026', '2026', 'Packaging Producer', '2026-03-01', '00000000-0000-0000-0000-000000000000', NEWID(), 0, '2026-03-01', 'RREPW')
insert into Prn (PrnNumber, OrganisationId, OrganisationName, ProducerAgency, ReprocessorExporterAgency, PrnStatusId, TonnageValue, MaterialName, IssuerReference, IssueDate, DecemberWaste, IssuedByOrg, AccreditationNumber, AccreditationYear, ObligationYear, PackagingProducer, CreatedOn, LastUpdatedBy, ExternalId, IsExport, LastUpdatedDate, SourceSystemId) values ('DP-PRN-004-RREPW-DEC', @dpOrgExternalId, 'POP QUEST LTD', 'Producer Agency', 'Reprocessor Exporter Agency', 1, 1, 'Glass Other', 'Issuer Reference', '2026-03-01T00:00:00+00:00', 1, 'Issued By Org', 'Accred Num', '2026', '2026', 'Packaging Producer', '2026-03-01', '00000000-0000-0000-0000-000000000000', NEWID(), 0, '2026-03-01', 'RREPW')
insert into Prn (PrnNumber, OrganisationId, OrganisationName, ProducerAgency, ReprocessorExporterAgency, PrnStatusId, TonnageValue, MaterialName, IssuerReference, IssueDate, DecemberWaste, IssuedByOrg, AccreditationNumber, AccreditationYear, ObligationYear, PackagingProducer, CreatedOn, LastUpdatedBy, ExternalId, IsExport, LastUpdatedDate, SourceSystemId) values ('DP-PRN-005-RREPW', @dpOrgExternalId, 'POP QUEST LTD', 'Producer Agency', 'Reprocessor Exporter Agency', 4, 1, 'Glass Other', 'Issuer Reference', '2026-03-01T00:00:00+00:00', 0, 'Issued By Org', 'Accred Num', '2027', '2027', 'Packaging Producer', '2026-03-01', '00000000-0000-0000-0000-000000000000', NEWID(), 0, '2026-03-01', 'RREPW')

-- Historic PRN
insert into Prn (PrnNumber, OrganisationId, OrganisationName, ProducerAgency, ReprocessorExporterAgency, PrnStatusId, TonnageValue, MaterialName, IssuerReference, IssueDate, DecemberWaste, IssuedByOrg, AccreditationNumber, AccreditationYear, ObligationYear, PackagingProducer, CreatedOn, LastUpdatedBy, ExternalId, IsExport, LastUpdatedDate, SourceSystemId) values ('DP-PRN-006-OLD', @dpOrgExternalId, 'POP QUEST LTD', 'Producer Agency', 'Reprocessor Exporter Agency', 1, 1, 'Glass Other', 'Issuer Reference', '2025-03-01T00:00:00+00:00', 0, 'Issued By Org', 'Accred Num', '2024', '2025', 'Packaging Producer', '2025-03-01', '00000000-0000-0000-0000-000000000000', NEWID(), 0, '2025-03-01', NULL)
insert into Prn (PrnNumber, OrganisationId, OrganisationName, ProducerAgency, ReprocessorExporterAgency, PrnStatusId, TonnageValue, MaterialName, IssuerReference, IssueDate, DecemberWaste, IssuedByOrg, AccreditationNumber, AccreditationYear, ObligationYear, PackagingProducer, CreatedOn, LastUpdatedBy, ExternalId, IsExport, LastUpdatedDate, SourceSystemId) values ('DP-PRN-007-OLD-DEC', @dpOrgExternalId, 'POP QUEST LTD', 'Producer Agency', 'Reprocessor Exporter Agency', 1, 1, 'Glass Other', 'Issuer Reference', '2025-03-01T00:00:00+00:00', 1, 'Issued By Org', 'Accred Num', '2024', '2025', 'Packaging Producer', '2025-03-01', '00000000-0000-0000-0000-000000000000', NEWID(), 0, '2025-03-01', NULL)

-- Fibre
insert into Prn (PrnNumber, OrganisationId, OrganisationName, ProducerAgency, ReprocessorExporterAgency, PrnStatusId, TonnageValue, MaterialName, IssuerReference, IssueDate, DecemberWaste, IssuedByOrg, AccreditationNumber, AccreditationYear, ObligationYear, PackagingProducer, CreatedOn, LastUpdatedBy, ExternalId, IsExport, LastUpdatedDate, SourceSystemId) values ('DP-PRN-008-RREPW', @dpOrgExternalId, 'POP QUEST LTD', 'Producer Agency', 'Reprocessor Exporter Agency', 4, 1, 'Fibre', 'Issuer Reference', '2026-03-01T00:00:00+00:00', 1, 'Issued By Org', 'Accred Num', '2026', '2026', 'Packaging Producer', '2026-03-01', '00000000-0000-0000-0000-000000000000', NEWID(), 0, '2026-03-01', 'RREPW')

-- Paper/board
insert into Prn (PrnNumber, OrganisationId, OrganisationName, ProducerAgency, ReprocessorExporterAgency, PrnStatusId, TonnageValue, MaterialName, IssuerReference, IssueDate, DecemberWaste, IssuedByOrg, AccreditationNumber, AccreditationYear, ObligationYear, PackagingProducer, CreatedOn, LastUpdatedBy, ExternalId, IsExport, LastUpdatedDate, SourceSystemId) values ('DP-PRN-009-RREPW', @dpOrgExternalId, 'POP QUEST LTD', 'Producer Agency', 'Reprocessor Exporter Agency', 4, 1, 'Paper/board', 'Issuer Reference', '2026-04-15T00:00:00+00:00', 0, 'Issued By Org', 'Accred Num', '2026', '2026', 'Packaging Producer', '2026-04-15', '00000000-0000-0000-0000-000000000000', NEWID(), 0, '2026-03-01', 'RREPW')
insert into Prn (PrnNumber, OrganisationId, OrganisationName, ProducerAgency, ReprocessorExporterAgency, PrnStatusId, TonnageValue, MaterialName, IssuerReference, IssueDate, DecemberWaste, IssuedByOrg, AccreditationNumber, AccreditationYear, ObligationYear, PackagingProducer, CreatedOn, LastUpdatedBy, ExternalId, IsExport, LastUpdatedDate, SourceSystemId) values ('DP-PRN-010-RREPW', @dpOrgExternalId, 'POP QUEST LTD', 'Producer Agency', 'Reprocessor Exporter Agency', 4, 1, 'Paper/board', 'Issuer Reference', '2026-04-16T00:00:00+00:00', 1, 'Issued By Org', 'Accred Num', '2026', '2026', 'Packaging Producer', '2026-04-16', '00000000-0000-0000-0000-000000000000', NEWID(), 0, '2026-03-01', 'RREPW')

-- PERN (IsExport = 1). Awaiting acceptance, so the direct-producer accept/reject journey
-- can exercise the PERN wording and the PrnType.Pern mapper branch.
insert into Prn (PrnNumber, OrganisationId, OrganisationName, ProducerAgency, ReprocessorExporterAgency, PrnStatusId, TonnageValue, MaterialName, IssuerReference, IssueDate, DecemberWaste, IssuedByOrg, AccreditationNumber, AccreditationYear, ObligationYear, PackagingProducer, CreatedOn, LastUpdatedBy, ExternalId, IsExport, LastUpdatedDate, SourceSystemId, PrnSignatory, PrnSignatoryPosition, ReprocessingSite, ProcessToBeUsed, IssuerNotes) values ('DP-PERN-001-RREPW', @dpOrgExternalId, 'POP QUEST LTD', 'EA', 'EA', 4, 100, 'Plastic', 'EUR/2026/EX/0473', '2026-04-18T11:05:00+00:00', 0, 'Eurokey Recycling Ltd', 'EX262008125', '2026', '2026', 'Packaging Producer', '2026-04-18', '00000000-0000-0000-0000-000000000000', NEWID(), 1, '2026-04-18', 'RREPW', 'Tomas Lindqvist', 'Head of Export Compliance', 'Reciclaje Iberico SL, Valencia, Spain', 'R3', 'Consignment exported under Annex VII notification GB-EX-2026-11842.')

-- Rejected and cancelled
insert into Prn (PrnNumber, OrganisationId, OrganisationName, ProducerAgency, ReprocessorExporterAgency, PrnStatusId, TonnageValue, MaterialName, IssuerReference, IssueDate, DecemberWaste, IssuedByOrg, AccreditationNumber, AccreditationYear, ObligationYear, PackagingProducer, CreatedOn, LastUpdatedBy, ExternalId, IsExport, LastUpdatedDate, SourceSystemId) values ('DP-PRN-011-REJECTED', @dpOrgExternalId, 'POP QUEST LTD', 'Producer Agency', 'Reprocessor Exporter Agency', 2, 30, 'Paper/board', 'Issuer Reference', '2026-05-06T00:00:00+00:00', 0, 'Issued By Org', 'Accred Num', '2026', '2026', 'Packaging Producer', '2026-05-06', '00000000-0000-0000-0000-000000000000', NEWID(), 0, '2026-05-07', 'RREPW')
insert into Prn (PrnNumber, OrganisationId, OrganisationName, ProducerAgency, ReprocessorExporterAgency, PrnStatusId, TonnageValue, MaterialName, IssuerReference, IssueDate, DecemberWaste, IssuedByOrg, AccreditationNumber, AccreditationYear, ObligationYear, PackagingProducer, CreatedOn, LastUpdatedBy, ExternalId, IsExport, LastUpdatedDate, SourceSystemId) values ('DP-PRN-012-CANCELLED', @dpOrgExternalId, 'POP QUEST LTD', 'Producer Agency', 'Reprocessor Exporter Agency', 3, 15, 'Glass Other', 'Issuer Reference', '2026-05-07T00:00:00+00:00', 0, 'Issued By Org', 'Accred Num', '2026', '2026', 'Packaging Producer', '2026-05-07', '00000000-0000-0000-0000-000000000000', NEWID(), 0, '2026-05-10', 'RREPW')

-- PRN status history
-- The backend records PRNs as awaiting acceptance when issued, then adds a second row when accepted or rejected.
declare @seedPrnUserId uniqueidentifier
set @seedPrnUserId = '00000000-0000-0000-0000-000000000000'

insert into PrnStatusHistory (CreatedOn, CreatedByUser, CreatedByOrganisationId, PrnStatusIdFk, PrnIdFk, Comment, ObligationYear)
select DATEADD(hour, 9, CAST(p.IssueDate as datetime2)), @seedPrnUserId, p.OrganisationId, 4, p.Id, NULL, p.ObligationYear
from Prn p
where p.PrnNumber in (
    'PRN-001-NPWD',
    'PRN-002-NPWD-DEC',
    'PRN-003-RREPW',
    'PRN-004-RREPW-DEC',
    'PRN-005-OLD',
    'PRN-006-OLD-DEC',
    'PRN-007-OLD-DEC',
    'PRN-008-CURRENT',
    'PRN-009-RREPW',
    'PRN-010-RREPW-DEC',
    'PRN-011-OLD-DEC',
    'PRN-012-RREPW',
    'PRN-013-RREPW',
    'PRN-014-RREPW',
    'PRN-015-RREPW',
    'PRN-016-RREPW',
    'PRN-017-RREPW',
    'DP-PRN-001-NPWD',
    'DP-PRN-002-NPWD-DEC',
    'DP-PRN-003-RREPW',
    'DP-PRN-004-RREPW-DEC',
    'DP-PRN-005-RREPW',
    'DP-PRN-006-OLD',
    'DP-PRN-007-OLD-DEC',
    'DP-PRN-008-RREPW',
    'DP-PRN-009-RREPW',
    'DP-PRN-010-RREPW',
    'PERN-001-RREPW',
    'DP-PERN-001-RREPW',
    'PRN-018-REJECTED',
    'PRN-019-CANCELLED',
    'DP-PRN-011-REJECTED',
    'DP-PRN-012-CANCELLED'
)

insert into PrnStatusHistory (CreatedOn, CreatedByUser, CreatedByOrganisationId, PrnStatusIdFk, PrnIdFk, Comment, ObligationYear)
select DATEADD(minute, 75, DATEADD(hour, 10, DATEADD(day, 1, CAST(p.IssueDate as datetime2)))), @seedPrnUserId, '00000000-0000-0000-0000-000000000000', 1, p.Id, NULL, p.ObligationYear
from Prn p
where p.PrnNumber in (
    'PRN-005-OLD',
    'PRN-006-OLD-DEC',
    'PRN-007-OLD-DEC',
    'PRN-008-CURRENT',
    'DP-PRN-004-RREPW-DEC',
    'DP-PRN-006-OLD',
    'DP-PRN-007-OLD-DEC',
    'PERN-001-RREPW'
)

-- Rejected: second row one day after issue, mirroring the accepted transition.
insert into PrnStatusHistory (CreatedOn, CreatedByUser, CreatedByOrganisationId, PrnStatusIdFk, PrnIdFk, Comment, ObligationYear)
select DATEADD(minute, 75, DATEADD(hour, 10, DATEADD(day, 1, CAST(p.IssueDate as datetime2)))), @seedPrnUserId, p.OrganisationId, 2, p.Id, 'Tonnage disputed against contracted volume.', p.ObligationYear
from Prn p
where p.PrnNumber in (
    'PRN-018-REJECTED',
    'DP-PRN-011-REJECTED'
)

-- Cancelled: withdrawn by the issuer three days after issue, so the gap between the two
-- history rows is visibly different from the accept/reject path.
insert into PrnStatusHistory (CreatedOn, CreatedByUser, CreatedByOrganisationId, PrnStatusIdFk, PrnIdFk, Comment, ObligationYear)
select DATEADD(hour, 14, DATEADD(day, 3, CAST(p.IssueDate as datetime2))), @seedPrnUserId, p.OrganisationId, 3, p.Id, 'Cancelled by issuer: duplicate of an earlier note.', p.ObligationYear
from Prn p
where p.PrnNumber in (
    'PRN-019-CANCELLED',
    'DP-PRN-012-CANCELLED'
)

-- =====================================================
-- Unsubmitted direct producer seed data: BRAMBLEWOOD PACKAGING LTD
-- =====================================================
-- This organisation is intentionally declaration-free in waste-obligations-seed.
-- It proves the obligation-hydration worker can enrich a returned unsubmitted row.
declare @bramblewoodExternalId uniqueidentifier
set @bramblewoodExternalId = '3151dbe5-a8ad-4d82-9471-1c469fa13918'

insert into ObligationCalculations (OrganisationId, MaterialObligationValue, Year, CalculatedOn, Tonnage, MaterialId, SubmitterId, SubmitterTypeId) values (@bramblewoodExternalId, 100, 2026, '2026-03-01', 100, 3, @bramblewoodExternalId, 1)
insert into ObligationCalculations (OrganisationId, MaterialObligationValue, Year, CalculatedOn, Tonnage, MaterialId, SubmitterId, SubmitterTypeId) values (@bramblewoodExternalId, 200, 2026, '2026-03-01', 200, 6, @bramblewoodExternalId, 1)

insert into Prn (PrnNumber, OrganisationId, OrganisationName, ProducerAgency, ReprocessorExporterAgency, PrnStatusId, TonnageValue, MaterialName, IssuerReference, IssueDate, DecemberWaste, IssuedByOrg, AccreditationNumber, AccreditationYear, ObligationYear, PackagingProducer, CreatedOn, LastUpdatedBy, ExternalId, IsExport, LastUpdatedDate, SourceSystemId) values ('BRAMBLEWOOD-PRN-001', @bramblewoodExternalId, 'BRAMBLEWOOD PACKAGING LTD', 'Producer Agency', 'Reprocessor Exporter Agency', 1, 25, 'Glass Other', 'Issuer Reference', '2026-03-01T00:00:00+00:00', 0, 'Issued By Org', 'Accred Num', '2026', '2026', 'Packaging Producer', '2026-03-01', '00000000-0000-0000-0000-000000000000', NEWID(), 0, '2026-03-01', 'RREPW')
insert into Prn (PrnNumber, OrganisationId, OrganisationName, ProducerAgency, ReprocessorExporterAgency, PrnStatusId, TonnageValue, MaterialName, IssuerReference, IssueDate, DecemberWaste, IssuedByOrg, AccreditationNumber, AccreditationYear, ObligationYear, PackagingProducer, CreatedOn, LastUpdatedBy, ExternalId, IsExport, LastUpdatedDate, SourceSystemId) values ('BRAMBLEWOOD-PRN-002', @bramblewoodExternalId, 'BRAMBLEWOOD PACKAGING LTD', 'Producer Agency', 'Reprocessor Exporter Agency', 1, 50, 'Paper/board', 'Issuer Reference', '2026-03-01T00:00:00+00:00', 0, 'Issued By Org', 'Accred Num', '2026', '2026', 'Packaging Producer', '2026-03-01', '00000000-0000-0000-0000-000000000000', NEWID(), 0, '2026-03-01', 'RREPW')

-- =====================================================
-- Realistic issuer, site and signatory detail
-- =====================================================
-- PrnSignatory, PrnSignatoryPosition, ReprocessingSite, ProcessToBeUsed and IssuerNotes
-- are otherwise never populated, so every PRN detail page renders "Not provided" for
-- Authorised by, Position, Reprocessing site, Recycling process and Issuer note.
-- Applied as an update so the inserts above stay readable and diff cleanly.
--
-- Conventions follow the NPWD public register: accreditation numbers are
-- <ER|EX><accreditation year><serial>, ER for EA and NRW reprocessors, EX for exporters,
-- and the agency is recorded as the short regulator token. Company names are
-- public-register entries; signatory names are invented and site addresses are plausible
-- rather than register data. See onboarding/prn-pern-field-data.md.
--
-- Export notes set these inline at insert, so they are excluded here.
update Prn
set ProducerAgency = 'EA',
    ReprocessorExporterAgency = 'EA',
    IssuedByOrg = case MaterialName
        when 'Paper/board' then 'DS Smith Paper Limited'
        when 'Glass Other' then 'Ardagh Glass Limited'
        when 'Fibre'       then 'Sonoco Cores and Paper Ltd'
    end,
    AccreditationNumber = case MaterialName
        when 'Paper/board' then 'ER26199864'
        when 'Glass Other' then 'ER261998132'
        when 'Fibre'       then 'ER26199890'
    end,
    ReprocessingSite = case MaterialName
        when 'Paper/board' then 'Kemsley Mill, Sittingbourne, Kent'
        when 'Glass Other' then 'Knottingley Works, Knottingley, West Yorkshire'
        when 'Fibre'       then 'Stainland Mill, Halifax, West Yorkshire'
    end,
    ProcessToBeUsed = case MaterialName
        when 'Glass Other' then 'R5'
        else 'R3'
    end,
    PrnSignatory = case MaterialName
        when 'Paper/board' then 'Alison Brackley'
        when 'Glass Other' then 'Douglas Fairlie'
        when 'Fibre'       then 'Marcus Ellery'
    end,
    PrnSignatoryPosition = case MaterialName
        when 'Paper/board' then 'Accreditation Manager'
        when 'Glass Other' then 'Site Operations Manager'
        when 'Fibre'       then 'Technical Compliance Manager'
    end,
    IssuerReference = case MaterialName
        when 'Paper/board' then 'DSS/2026/Q1/0412'
        when 'Glass Other' then 'AGL/2026/Q1/0887'
        when 'Fibre'       then 'SON/2026/Q1/0231'
    end,
    IssuerNotes = case MaterialName
        when 'Paper/board' then 'Evidence issued against material received at Kemsley Mill during Q1 2026.'
        when 'Glass Other' then 'Evidence issued against cullet received at Knottingley Works during Q1 2026.'
        when 'Fibre'       then 'Evidence issued against material received at Stainland Mill during Q1 2026.'
    end
where IsExport = 0
  and MaterialName in ('Paper/board', 'Glass Other', 'Fibre')
