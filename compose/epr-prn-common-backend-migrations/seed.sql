-- this is used in seed.sql for service epr-backend-account-microservice-migrations
declare @organisationExternalId uniqueidentifier
set @organisationExternalId = '94BFC917-B9B6-45D7-847B-E5F500BFE198'

-- this is used in seed.sql for service epr-backend-account-microservice-migrations
declare @complianceSchemeExternalId uniqueidentifier
set @complianceSchemeExternalId = 'D93376E3-0681-46BE-AEB4-7450A2E784D8'

insert into ObligationCalculations (OrganisationId, MaterialObligationValue, Year, CalculatedOn, Tonnage, MaterialId, SubmitterId, SubmitterTypeId) values (@organisationExternalId, 2025, 2025, '2025-03-01', 2025, 3, @complianceSchemeExternalId, 2)
insert into ObligationCalculations (OrganisationId, MaterialObligationValue, Year, CalculatedOn, Tonnage, MaterialId, SubmitterId, SubmitterTypeId) values (@organisationExternalId, 2025, 2025, '2025-03-01', 2025, 6, @complianceSchemeExternalId, 2)

insert into ObligationCalculations (OrganisationId, MaterialObligationValue, Year, CalculatedOn, Tonnage, MaterialId, SubmitterId, SubmitterTypeId) values (@organisationExternalId, 2026, 2026, '2026-03-01', 2026, 3, @complianceSchemeExternalId, 2)
insert into ObligationCalculations (OrganisationId, MaterialObligationValue, Year, CalculatedOn, Tonnage, MaterialId, SubmitterId, SubmitterTypeId) values (@organisationExternalId, 2026, 2026, '2026-03-01', 2026, 6, @complianceSchemeExternalId, 2)

-- question: where is obligation year set as acceptance should denote what year it goes under?
insert into Prn (PrnNumber, OrganisationId, OrganisationName, ProducerAgency, ReprocessorExporterAgency, PrnStatusId, TonnageValue, MaterialName, IssuerReference, IssueDate, DecemberWaste, IssuedByOrg, AccreditationNumber, AccreditationYear, ObligationYear, PackagingProducer, CreatedOn, LastUpdatedBy, ExternalId, IsExport, LastUpdatedDate) values ('PRN-001', @complianceSchemeExternalId, 'Organisation Name', 'Producer Agency', 'Reprocessor Exporter Agency', 4, 1, 'Glass', 'Issuer Reference', '2025-03-01', 0, 'Issued By Org', 'Accred Num', '2025', '2025', 'Packaging Producer', '2025-03-01', '00000000-0000-0000-0000-000000000000', NEWID(), 0, '2025-03-01')
