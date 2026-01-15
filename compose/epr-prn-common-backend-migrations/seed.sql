-- this is used in seed.sql for service epr-backend-account-microservice-migrations
declare @organisationExternalId uniqueidentifier
set @organisationExternalId = '94BFC917-B9B6-45D7-847B-E5F500BFE198'

-- this is used in seed.sql for service epr-backend-account-microservice-migrations
declare @complianceSchemeExternalId uniqueidentifier
set @complianceSchemeExternalId = 'D93376E3-0681-46BE-AEB4-7450A2E784D8'

insert into ObligationCalculations (OrganisationId, MaterialObligationValue, Year, CalculatedOn, Tonnage, MaterialId, SubmitterId, SubmitterTypeId) values (@organisationExternalId, 100, 2025, '2025-03-01', 100, 3, @complianceSchemeExternalId, 2)
insert into ObligationCalculations (OrganisationId, MaterialObligationValue, Year, CalculatedOn, Tonnage, MaterialId, SubmitterId, SubmitterTypeId) values (@organisationExternalId, 200, 2025, '2025-03-01', 200, 6, @complianceSchemeExternalId, 2)

insert into ObligationCalculations (OrganisationId, MaterialObligationValue, Year, CalculatedOn, Tonnage, MaterialId, SubmitterId, SubmitterTypeId) values (@organisationExternalId, 100, 2026, '2026-03-01', 100, 3, @complianceSchemeExternalId, 2)
insert into ObligationCalculations (OrganisationId, MaterialObligationValue, Year, CalculatedOn, Tonnage, MaterialId, SubmitterId, SubmitterTypeId) values (@organisationExternalId, 200, 2026, '2026-03-01', 200, 6, @complianceSchemeExternalId, 2)

insert into Prn (PrnNumber, OrganisationId, OrganisationName, ProducerAgency, ReprocessorExporterAgency, PrnStatusId, TonnageValue, MaterialName, IssuerReference, IssueDate, DecemberWaste, IssuedByOrg, AccreditationNumber, AccreditationYear, ObligationYear, PackagingProducer, CreatedOn, LastUpdatedBy, ExternalId, IsExport, LastUpdatedDate, SourceSystemId) values ('PRN-001-NPWD', @complianceSchemeExternalId, 'Organisation Name', 'Producer Agency', 'Reprocessor Exporter Agency', 4, 1, 'Glass', 'Issuer Reference', '2025-03-01', 0, 'Issued By Org', 'Accred Num', '2025', '2025', 'Packaging Producer', '2025-03-01', '00000000-0000-0000-0000-000000000000', NEWID(), 0, '2025-03-01', NULL)

insert into Prn (PrnNumber, OrganisationId, OrganisationName, ProducerAgency, ReprocessorExporterAgency, PrnStatusId, TonnageValue, MaterialName, IssuerReference, IssueDate, DecemberWaste, IssuedByOrg, AccreditationNumber, AccreditationYear, ObligationYear, PackagingProducer, CreatedOn, LastUpdatedBy, ExternalId, IsExport, LastUpdatedDate, SourceSystemId) values ('PRN-002-NPWD-DEC', @complianceSchemeExternalId, 'Organisation Name', 'Producer Agency', 'Reprocessor Exporter Agency', 4, 1, 'Glass', 'Issuer Reference', '2025-03-01', 1, 'Issued By Org', 'Accred Num', '2025', '2025', 'Packaging Producer', '2025-03-01', '00000000-0000-0000-0000-000000000000', NEWID(), 0, '2025-03-01', NULL)

-- a non NULL SourceSystemId field denotes a new REEPW PRN
insert into Prn (PrnNumber, OrganisationId, OrganisationName, ProducerAgency, ReprocessorExporterAgency, PrnStatusId, TonnageValue, MaterialName, IssuerReference, IssueDate, DecemberWaste, IssuedByOrg, AccreditationNumber, AccreditationYear, ObligationYear, PackagingProducer, CreatedOn, LastUpdatedBy, ExternalId, IsExport, LastUpdatedDate, SourceSystemId) values ('PRN-003-REEPW', @complianceSchemeExternalId, 'Organisation Name', 'Producer Agency', 'Reprocessor Exporter Agency', 4, 1, 'Glass', 'Issuer Reference', '2026-03-01', 0, 'Issued By Org', 'Accred Num', '2026', '2026', 'Packaging Producer', '2026-03-01', '00000000-0000-0000-0000-000000000000', NEWID(), 0, '2026-03-01', 'REEPW')

insert into Prn (PrnNumber, OrganisationId, OrganisationName, ProducerAgency, ReprocessorExporterAgency, PrnStatusId, TonnageValue, MaterialName, IssuerReference, IssueDate, DecemberWaste, IssuedByOrg, AccreditationNumber, AccreditationYear, ObligationYear, PackagingProducer, CreatedOn, LastUpdatedBy, ExternalId, IsExport, LastUpdatedDate, SourceSystemId) values ('PRN-004-REEPW-DEC', @complianceSchemeExternalId, 'Organisation Name', 'Producer Agency', 'Reprocessor Exporter Agency', 4, 1, 'Glass', 'Issuer Reference', '2026-03-01', 1, 'Issued By Org', 'Accred Num', '2026', '2026', 'Packaging Producer', '2026-03-01', '00000000-0000-0000-0000-000000000000', NEWID(), 0, '2026-03-01', 'REEPW')
