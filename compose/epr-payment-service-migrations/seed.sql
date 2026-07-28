-- Northbridge Compliance Solutions Ltd: PayCal (epr-payment-service) registration fee
-- calculation data for the 2 accepted registration submissions seeded into Cosmos/Synapse
-- (compose/epr-common-data-api-migrations/seed.sql, mocks/CosmosDbInit/Program.cs).
-- SubmissionId values here MUST match those seed files exactly - this is what backs the
-- 'View registration fee' screen (fee-calculation-details lookup by SubmissionId).

-- 2026 Large (SubmissionId 601A176C-B17B-4B6B-B672-D0C61A44E733)
if not exists (select 1 from registration.RegistrationSubmissionData where SubmissionId = N'601A176C-B17B-4B6B-B672-D0C61A44E733')
begin
    insert into registration.RegistrationSubmissionData (Id, SubmissionId, RegistrationBlobName, ComplianceSchemeId, SubmissionDate, CreatedDate, SubmissionPeriodId) values (N'16F8D0A5-535B-43D9-8A47-5F0D9FAD8922', N'601A176C-B17B-4B6B-B672-D0C61A44E733', N'Northbridge_CompanyDetails_2026_Large.csv', N'CAC58048-62A1-4419-9BEE-4B386454D776', N'2026-04-08T09:05:00', SYSDATETIMEOFFSET(), 3);

    insert into registration.RegistrationSubmissionProducer (Id, RegistrationSubmissionDataId, OrganisationId, OrganisationSize, NationId, IsOnlineMarketplace, IsClosedLoopRecycling, IsNewJoiner, CreatedDate) values (N'77715EDE-B8E2-41CE-A1E6-CA866CA5D62D', N'16F8D0A5-535B-43D9-8A47-5F0D9FAD8922', N'11000001', N'Large', 1, 0, 0, 0, SYSDATETIMEOFFSET());
    insert into registration.RegistrationSubmissionSubsidiary (Id, RegistrationSubmissionProducerId, SubsidiaryId, IsOnlineMarketplace, IsClosedLoopRecycling, IsNewJoiner, CreatedDate) values (N'4F90C091-F140-435C-9765-B590ACD3A809', N'77715EDE-B8E2-41CE-A1E6-CA866CA5D62D', N'11000011', 0, 0, 0, SYSDATETIMEOFFSET());
    insert into registration.RegistrationSubmissionSubsidiary (Id, RegistrationSubmissionProducerId, SubsidiaryId, IsOnlineMarketplace, IsClosedLoopRecycling, IsNewJoiner, CreatedDate) values (N'F2E9B9BF-F0E2-4049-8513-304D85633166', N'77715EDE-B8E2-41CE-A1E6-CA866CA5D62D', N'11000012', 0, 0, 0, SYSDATETIMEOFFSET());
    insert into registration.RegistrationSubmissionProducer (Id, RegistrationSubmissionDataId, OrganisationId, OrganisationSize, NationId, IsOnlineMarketplace, IsClosedLoopRecycling, IsNewJoiner, CreatedDate) values (N'BABD8967-0AD0-44B5-8B44-24C0FA3E76CC', N'16F8D0A5-535B-43D9-8A47-5F0D9FAD8922', N'11000002', N'Large', 1, 0, 0, 0, SYSDATETIMEOFFSET());
    insert into registration.RegistrationSubmissionSubsidiary (Id, RegistrationSubmissionProducerId, SubsidiaryId, IsOnlineMarketplace, IsClosedLoopRecycling, IsNewJoiner, CreatedDate) values (N'410F145E-A764-44B0-9737-8C80D18502B5', N'BABD8967-0AD0-44B5-8B44-24C0FA3E76CC', N'11000013', 0, 0, 0, SYSDATETIMEOFFSET());
    insert into registration.RegistrationSubmissionSubsidiary (Id, RegistrationSubmissionProducerId, SubsidiaryId, IsOnlineMarketplace, IsClosedLoopRecycling, IsNewJoiner, CreatedDate) values (N'52534809-1883-4F51-A94B-37E55D9499A3', N'BABD8967-0AD0-44B5-8B44-24C0FA3E76CC', N'11000014', 0, 0, 0, SYSDATETIMEOFFSET());
    insert into registration.RegistrationSubmissionProducer (Id, RegistrationSubmissionDataId, OrganisationId, OrganisationSize, NationId, IsOnlineMarketplace, IsClosedLoopRecycling, IsNewJoiner, CreatedDate) values (N'FB22B24E-7FF1-4AFF-955E-950B99C7056F', N'16F8D0A5-535B-43D9-8A47-5F0D9FAD8922', N'11000003', N'Large', 1, 0, 0, 0, SYSDATETIMEOFFSET());
    insert into registration.RegistrationSubmissionProducer (Id, RegistrationSubmissionDataId, OrganisationId, OrganisationSize, NationId, IsOnlineMarketplace, IsClosedLoopRecycling, IsNewJoiner, CreatedDate) values (N'E25A4363-918F-465A-B185-60A8B17BF9DD', N'16F8D0A5-535B-43D9-8A47-5F0D9FAD8922', N'11000004', N'Large', 1, 0, 0, 0, SYSDATETIMEOFFSET());
    insert into registration.RegistrationSubmissionProducer (Id, RegistrationSubmissionDataId, OrganisationId, OrganisationSize, NationId, IsOnlineMarketplace, IsClosedLoopRecycling, IsNewJoiner, CreatedDate) values (N'A1B4EC5F-A9C1-4E96-9B0F-B84092DCE265', N'16F8D0A5-535B-43D9-8A47-5F0D9FAD8922', N'11000005', N'Large', 1, 0, 0, 0, SYSDATETIMEOFFSET());
end

-- 2026 Small (SubmissionId ECE0880A-B713-42D4-A018-92FD3D8053C6)
if not exists (select 1 from registration.RegistrationSubmissionData where SubmissionId = N'ECE0880A-B713-42D4-A018-92FD3D8053C6')
begin
    insert into registration.RegistrationSubmissionData (Id, SubmissionId, RegistrationBlobName, ComplianceSchemeId, SubmissionDate, CreatedDate, SubmissionPeriodId) values (N'18AD383A-558B-4135-B628-37B67E890BB2', N'ECE0880A-B713-42D4-A018-92FD3D8053C6', N'Northbridge_CompanyDetails_2026_Small.csv', N'CAC58048-62A1-4419-9BEE-4B386454D776', N'2026-04-09T09:35:00', SYSDATETIMEOFFSET(), 4);

    insert into registration.RegistrationSubmissionProducer (Id, RegistrationSubmissionDataId, OrganisationId, OrganisationSize, NationId, IsOnlineMarketplace, IsClosedLoopRecycling, IsNewJoiner, CreatedDate) values (N'43905980-340B-4710-942A-7ACF0009FB82', N'18AD383A-558B-4135-B628-37B67E890BB2', N'11000006', N'Small', 1, 0, 0, 0, SYSDATETIMEOFFSET());
    insert into registration.RegistrationSubmissionProducer (Id, RegistrationSubmissionDataId, OrganisationId, OrganisationSize, NationId, IsOnlineMarketplace, IsClosedLoopRecycling, IsNewJoiner, CreatedDate) values (N'75493BE3-A34F-4E7F-AD02-0587BAD62D6E', N'18AD383A-558B-4135-B628-37B67E890BB2', N'11000007', N'Small', 1, 0, 0, 0, SYSDATETIMEOFFSET());
    insert into registration.RegistrationSubmissionProducer (Id, RegistrationSubmissionDataId, OrganisationId, OrganisationSize, NationId, IsOnlineMarketplace, IsClosedLoopRecycling, IsNewJoiner, CreatedDate) values (N'02CC5754-3D99-4F07-8492-333483FCDABA', N'18AD383A-558B-4135-B628-37B67E890BB2', N'11000008', N'Small', 1, 0, 0, 0, SYSDATETIMEOFFSET());
    insert into registration.RegistrationSubmissionProducer (Id, RegistrationSubmissionDataId, OrganisationId, OrganisationSize, NationId, IsOnlineMarketplace, IsClosedLoopRecycling, IsNewJoiner, CreatedDate) values (N'5DEFB9E4-DD42-489B-AC87-60AB01D42E41', N'18AD383A-558B-4135-B628-37B67E890BB2', N'11000009', N'Small', 1, 0, 0, 0, SYSDATETIMEOFFSET());
    insert into registration.RegistrationSubmissionProducer (Id, RegistrationSubmissionDataId, OrganisationId, OrganisationSize, NationId, IsOnlineMarketplace, IsClosedLoopRecycling, IsNewJoiner, CreatedDate) values (N'139B8D57-BEEC-4BDF-ABCB-7926939EA6EB', N'18AD383A-558B-4135-B628-37B67E890BB2', N'11000010', N'Small', 1, 0, 0, 0, SYSDATETIMEOFFSET());
end
