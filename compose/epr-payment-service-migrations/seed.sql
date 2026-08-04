-- Northbridge Compliance Solutions Ltd: PayCal (epr-payment-service) registration fee
-- calculation data for the 2 accepted registration submissions seeded into Cosmos/Synapse
-- (compose/epr-common-data-api-migrations/seed.sql, mocks/CosmosDbInit/Program.cs).
-- SubmissionId values here MUST match those seed files exactly - this is what backs the
-- 'View registration fee' screen (fee-calculation-details lookup by SubmissionId).

-- 2026 Large (SubmissionId 601A176C-B17B-4B6B-B672-D0C61A44E733)
if not exists (select 1 from registration.RegistrationSubmissionData where SubmissionId = N'601A176C-B17B-4B6B-B672-D0C61A44E733')
begin
    insert into registration.RegistrationSubmissionData (Id, SubmissionId, RegistrationBlobName, ComplianceSchemeId, SubmissionDate, CreatedDate, SubmissionPeriodId) values (N'16F8D0A5-535B-43D9-8A47-5F0D9FAD8922', N'601A176C-B17B-4B6B-B672-D0C61A44E733', N'Northbridge_CompanyDetails_2026_Large.csv', N'CAC58048-62A1-4419-9BEE-4B386454D776', N'2026-04-08T09:05:00', SYSDATETIMEOFFSET(), 3);

    insert into registration.RegistrationSubmissionProducer (Id, RegistrationSubmissionDataId, OrganisationId, OrganisationSize, NationId, IsOnlineMarketplace, IsClosedLoopRecycling, IsNewJoiner, CreatedDate) values (N'77715EDE-B8E2-41CE-A1E6-CA866CA5D62D', N'16F8D0A5-535B-43D9-8A47-5F0D9FAD8922', N'110001', N'Large', 1, 0, 0, 0, SYSDATETIMEOFFSET());
    insert into registration.RegistrationSubmissionSubsidiary (Id, RegistrationSubmissionProducerId, SubsidiaryId, IsOnlineMarketplace, IsClosedLoopRecycling, IsNewJoiner, CreatedDate) values (N'4F90C091-F140-435C-9765-B590ACD3A809', N'77715EDE-B8E2-41CE-A1E6-CA866CA5D62D', N'110011', 0, 0, 0, SYSDATETIMEOFFSET());
    insert into registration.RegistrationSubmissionSubsidiary (Id, RegistrationSubmissionProducerId, SubsidiaryId, IsOnlineMarketplace, IsClosedLoopRecycling, IsNewJoiner, CreatedDate) values (N'F2E9B9BF-F0E2-4049-8513-304D85633166', N'77715EDE-B8E2-41CE-A1E6-CA866CA5D62D', N'110012', 0, 0, 0, SYSDATETIMEOFFSET());
    insert into registration.RegistrationSubmissionProducer (Id, RegistrationSubmissionDataId, OrganisationId, OrganisationSize, NationId, IsOnlineMarketplace, IsClosedLoopRecycling, IsNewJoiner, CreatedDate) values (N'BABD8967-0AD0-44B5-8B44-24C0FA3E76CC', N'16F8D0A5-535B-43D9-8A47-5F0D9FAD8922', N'110002', N'Large', 1, 0, 0, 0, SYSDATETIMEOFFSET());
    insert into registration.RegistrationSubmissionSubsidiary (Id, RegistrationSubmissionProducerId, SubsidiaryId, IsOnlineMarketplace, IsClosedLoopRecycling, IsNewJoiner, CreatedDate) values (N'410F145E-A764-44B0-9737-8C80D18502B5', N'BABD8967-0AD0-44B5-8B44-24C0FA3E76CC', N'110013', 0, 0, 0, SYSDATETIMEOFFSET());
    insert into registration.RegistrationSubmissionSubsidiary (Id, RegistrationSubmissionProducerId, SubsidiaryId, IsOnlineMarketplace, IsClosedLoopRecycling, IsNewJoiner, CreatedDate) values (N'52534809-1883-4F51-A94B-37E55D9499A3', N'BABD8967-0AD0-44B5-8B44-24C0FA3E76CC', N'110014', 0, 0, 0, SYSDATETIMEOFFSET());
    insert into registration.RegistrationSubmissionProducer (Id, RegistrationSubmissionDataId, OrganisationId, OrganisationSize, NationId, IsOnlineMarketplace, IsClosedLoopRecycling, IsNewJoiner, CreatedDate) values (N'FB22B24E-7FF1-4AFF-955E-950B99C7056F', N'16F8D0A5-535B-43D9-8A47-5F0D9FAD8922', N'110003', N'Large', 1, 0, 0, 0, SYSDATETIMEOFFSET());
    insert into registration.RegistrationSubmissionProducer (Id, RegistrationSubmissionDataId, OrganisationId, OrganisationSize, NationId, IsOnlineMarketplace, IsClosedLoopRecycling, IsNewJoiner, CreatedDate) values (N'E25A4363-918F-465A-B185-60A8B17BF9DD', N'16F8D0A5-535B-43D9-8A47-5F0D9FAD8922', N'110004', N'Large', 1, 0, 0, 0, SYSDATETIMEOFFSET());
    insert into registration.RegistrationSubmissionProducer (Id, RegistrationSubmissionDataId, OrganisationId, OrganisationSize, NationId, IsOnlineMarketplace, IsClosedLoopRecycling, IsNewJoiner, CreatedDate) values (N'A1B4EC5F-A9C1-4E96-9B0F-B84092DCE265', N'16F8D0A5-535B-43D9-8A47-5F0D9FAD8922', N'110005', N'Large', 1, 0, 0, 0, SYSDATETIMEOFFSET());
end

-- 2026 Small (SubmissionId ECE0880A-B713-42D4-A018-92FD3D8053C6)
if not exists (select 1 from registration.RegistrationSubmissionData where SubmissionId = N'ECE0880A-B713-42D4-A018-92FD3D8053C6')
begin
    insert into registration.RegistrationSubmissionData (Id, SubmissionId, RegistrationBlobName, ComplianceSchemeId, SubmissionDate, CreatedDate, SubmissionPeriodId) values (N'18AD383A-558B-4135-B628-37B67E890BB2', N'ECE0880A-B713-42D4-A018-92FD3D8053C6', N'Northbridge_CompanyDetails_2026_Small.csv', N'CAC58048-62A1-4419-9BEE-4B386454D776', N'2026-04-09T09:35:00', SYSDATETIMEOFFSET(), 4);

    insert into registration.RegistrationSubmissionProducer (Id, RegistrationSubmissionDataId, OrganisationId, OrganisationSize, NationId, IsOnlineMarketplace, IsClosedLoopRecycling, IsNewJoiner, CreatedDate) values (N'43905980-340B-4710-942A-7ACF0009FB82', N'18AD383A-558B-4135-B628-37B67E890BB2', N'110006', N'Small', 1, 0, 0, 0, SYSDATETIMEOFFSET());
    insert into registration.RegistrationSubmissionProducer (Id, RegistrationSubmissionDataId, OrganisationId, OrganisationSize, NationId, IsOnlineMarketplace, IsClosedLoopRecycling, IsNewJoiner, CreatedDate) values (N'75493BE3-A34F-4E7F-AD02-0587BAD62D6E', N'18AD383A-558B-4135-B628-37B67E890BB2', N'110007', N'Small', 1, 0, 0, 0, SYSDATETIMEOFFSET());
    insert into registration.RegistrationSubmissionProducer (Id, RegistrationSubmissionDataId, OrganisationId, OrganisationSize, NationId, IsOnlineMarketplace, IsClosedLoopRecycling, IsNewJoiner, CreatedDate) values (N'02CC5754-3D99-4F07-8492-333483FCDABA', N'18AD383A-558B-4135-B628-37B67E890BB2', N'110008', N'Small', 1, 0, 0, 0, SYSDATETIMEOFFSET());
    insert into registration.RegistrationSubmissionProducer (Id, RegistrationSubmissionDataId, OrganisationId, OrganisationSize, NationId, IsOnlineMarketplace, IsClosedLoopRecycling, IsNewJoiner, CreatedDate) values (N'5DEFB9E4-DD42-489B-AC87-60AB01D42E41', N'18AD383A-558B-4135-B628-37B67E890BB2', N'110009', N'Small', 1, 0, 0, 0, SYSDATETIMEOFFSET());
    insert into registration.RegistrationSubmissionProducer (Id, RegistrationSubmissionDataId, OrganisationId, OrganisationSize, NationId, IsOnlineMarketplace, IsClosedLoopRecycling, IsNewJoiner, CreatedDate) values (N'139B8D57-BEEC-4BDF-ABCB-7926939EA6EB', N'18AD383A-558B-4135-B628-37B67E890BB2', N'110010', N'Small', 1, 0, 0, 0, SYSDATETIMEOFFSET());
end

-- POP QUEST LTD (Direct Producer, CHN 17121895): PayCal registration fee calculation data for its
-- 2 accepted registration submissions. SubmissionId values MUST match
-- compose/epr-common-data-api-migrations/seed.sql and mocks/CosmosDbInit/Program.cs exactly.
--
-- Two things differ from the Northbridge blocks above because this is a direct producer, not a
-- compliance scheme: ComplianceSchemeId is NULL, and SubmissionPeriodId points at the Direct rows
-- in Lookup.SubmissionPeriod (2 = Direct/2025, 5 = DirectLargeProducer/2026) rather than the Cso
-- ones. OrganisationId/SubsidiaryId use the organisation reference numbers (165282/165283/165284),
-- matching organisation_id/subsidiary_id in this org's rpd.CompanyDetails and rpd.Pom rows.

-- Registration 2025 (SubmissionId F2A3B4C5-D6E7-4F8A-8B9C-0D1E2F3A4B56)
if not exists (select 1 from registration.RegistrationSubmissionData where SubmissionId = N'F2A3B4C5-D6E7-4F8A-8B9C-0D1E2F3A4B56')
begin
    insert into registration.RegistrationSubmissionData (Id, SubmissionId, RegistrationBlobName, ComplianceSchemeId, SubmissionDate, CreatedDate, SubmissionPeriodId) values (N'0A1B7C3D-5E2F-4A96-9B71-C4D80E2F1A63', N'F2A3B4C5-D6E7-4F8A-8B9C-0D1E2F3A4B56', N'PopQuest_CompanyDetails_2025.csv', null, N'2025-04-01T09:20:00', SYSDATETIMEOFFSET(), 2);

    insert into registration.RegistrationSubmissionProducer (Id, RegistrationSubmissionDataId, OrganisationId, OrganisationSize, NationId, IsOnlineMarketplace, IsClosedLoopRecycling, IsNewJoiner, CreatedDate) values (N'1B2C8D4E-6F3A-4B07-8C82-D5E91F3A2B74', N'0A1B7C3D-5E2F-4A96-9B71-C4D80E2F1A63', N'165282', N'Large', 1, 0, 0, 0, SYSDATETIMEOFFSET());
    insert into registration.RegistrationSubmissionSubsidiary (Id, RegistrationSubmissionProducerId, SubsidiaryId, IsOnlineMarketplace, IsClosedLoopRecycling, IsNewJoiner, CreatedDate) values (N'2C3D9E5F-7A4B-4C18-9D93-E6F02A4B3C85', N'1B2C8D4E-6F3A-4B07-8C82-D5E91F3A2B74', N'165283', 0, 0, 0, SYSDATETIMEOFFSET());
    insert into registration.RegistrationSubmissionSubsidiary (Id, RegistrationSubmissionProducerId, SubsidiaryId, IsOnlineMarketplace, IsClosedLoopRecycling, IsNewJoiner, CreatedDate) values (N'3D4E0F6A-8B5C-4D29-8EA4-F7013B5C4D96', N'1B2C8D4E-6F3A-4B07-8C82-D5E91F3A2B74', N'165284', 0, 0, 0, SYSDATETIMEOFFSET());
end

-- Registration 2026 (SubmissionId C5D6E7F8-A9B0-4C1D-8E2F-3A4B5C6D7E89)
if not exists (select 1 from registration.RegistrationSubmissionData where SubmissionId = N'C5D6E7F8-A9B0-4C1D-8E2F-3A4B5C6D7E89')
begin
    insert into registration.RegistrationSubmissionData (Id, SubmissionId, RegistrationBlobName, ComplianceSchemeId, SubmissionDate, CreatedDate, SubmissionPeriodId) values (N'4E5F1A7B-9C6D-4E3A-9FB5-08124C6D5EA7', N'C5D6E7F8-A9B0-4C1D-8E2F-3A4B5C6D7E89', N'PopQuest_CompanyDetails_2026.csv', null, N'2026-04-01T09:20:00', SYSDATETIMEOFFSET(), 5);

    insert into registration.RegistrationSubmissionProducer (Id, RegistrationSubmissionDataId, OrganisationId, OrganisationSize, NationId, IsOnlineMarketplace, IsClosedLoopRecycling, IsNewJoiner, CreatedDate) values (N'5F6A2B8C-0D7E-4F4B-8AC6-19235D7E6FB8', N'4E5F1A7B-9C6D-4E3A-9FB5-08124C6D5EA7', N'165282', N'Large', 1, 0, 0, 0, SYSDATETIMEOFFSET());
    insert into registration.RegistrationSubmissionSubsidiary (Id, RegistrationSubmissionProducerId, SubsidiaryId, IsOnlineMarketplace, IsClosedLoopRecycling, IsNewJoiner, CreatedDate) values (N'6A7B3C9D-1E8F-4A5C-9BD7-2A346E8F70C9', N'5F6A2B8C-0D7E-4F4B-8AC6-19235D7E6FB8', N'165283', 0, 0, 0, SYSDATETIMEOFFSET());
    insert into registration.RegistrationSubmissionSubsidiary (Id, RegistrationSubmissionProducerId, SubsidiaryId, IsOnlineMarketplace, IsClosedLoopRecycling, IsNewJoiner, CreatedDate) values (N'7B8C4D0E-2F9A-4B6D-8CE8-3B457F9A81DA', N'5F6A2B8C-0D7E-4F4B-8AC6-19235D7E6FB8', N'165284', 0, 0, 0, SYSDATETIMEOFFSET());
end
