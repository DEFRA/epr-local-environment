-- Northbridge Compliance Solutions Ltd: PayCal (epr-payment-service) registration fee
-- calculation data for the 2 accepted registration submissions seeded into Cosmos/Synapse
-- (compose/synapse-sqlserver-restore/seed/baseline.sql, mocks/CosmosDbInit/Program.cs).
-- SubmissionId values here MUST match those seed files exactly - this is what backs the
-- 'View registration fee' screen (fee-calculation-details lookup by SubmissionId).
--
-- RegistrationBlobName MUST additionally be lower case and match the BlobName on the
-- corresponding antivirus events in mocks/CosmosDbInit/Program.cs, which writes every BlobName
-- through ToLowerInvariant(). The frontend fetches the fee snapshot from PayCal and then compares
-- its RegistrationBlobName against LastUploadedValidFiles.CompanyDetailsBlobName from the
-- submission API, which is that lower-cased Cosmos value. The comparison is ordinal and
-- case-sensitive (RegistrationApplicationService.SnapshotIsForExpectedBlob in
-- epr-packaging-frontend), so an upper-case value here is silently discarded as a "stale fee
-- snapshot", the session never gets ReadyToCalculateFees, and 'View registration fee' redirects
-- to the error page.

-- 2026 Large (SubmissionId 601A176C-B17B-4B6B-B672-D0C61A44E733)
if not exists (select 1 from registration.RegistrationSubmissionData where SubmissionId = N'601A176C-B17B-4B6B-B672-D0C61A44E733')
begin
    -- AppReferenceNumber must match the Cosmos seed for this SubmissionId (mocks/CosmosDbInit/Program.cs).
    insert into registration.RegistrationSubmissionData (Id, SubmissionId, RegistrationBlobName, ComplianceSchemeId, SubmissionDate, CreatedDate, SubmissionPeriodId, RegulatorNation, ApplicationReferenceNumber) values (N'16F8D0A5-535B-43D9-8A47-5F0D9FAD8922', N'601A176C-B17B-4B6B-B672-D0C61A44E733', N'7113cc97-a799-48e4-8a5e-f214532c32e4', N'CAC58048-62A1-4419-9BEE-4B386454D776', N'2026-04-08T09:05:00', SYSDATETIMEOFFSET(), 3, N'GB-ENG', N'PEPR11000007226P1');

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
    -- AppReferenceNumber must match the Cosmos seed for this SubmissionId (mocks/CosmosDbInit/Program.cs).
    insert into registration.RegistrationSubmissionData (Id, SubmissionId, RegistrationBlobName, ComplianceSchemeId, SubmissionDate, CreatedDate, SubmissionPeriodId, RegulatorNation, ApplicationReferenceNumber) values (N'18AD383A-558B-4135-B628-37B67E890BB2', N'ECE0880A-B713-42D4-A018-92FD3D8053C6', N'b1df2a8b-5435-47d8-946a-07b5155b3ca4', N'CAC58048-62A1-4419-9BEE-4B386454D776', N'2026-04-09T09:35:00', SYSDATETIMEOFFSET(), 4, N'GB-ENG', N'PEPR11000007226P1S');

    insert into registration.RegistrationSubmissionProducer (Id, RegistrationSubmissionDataId, OrganisationId, OrganisationSize, NationId, IsOnlineMarketplace, IsClosedLoopRecycling, IsNewJoiner, CreatedDate) values (N'43905980-340B-4710-942A-7ACF0009FB82', N'18AD383A-558B-4135-B628-37B67E890BB2', N'110006', N'Small', 1, 0, 0, 0, SYSDATETIMEOFFSET());
    insert into registration.RegistrationSubmissionProducer (Id, RegistrationSubmissionDataId, OrganisationId, OrganisationSize, NationId, IsOnlineMarketplace, IsClosedLoopRecycling, IsNewJoiner, CreatedDate) values (N'75493BE3-A34F-4E7F-AD02-0587BAD62D6E', N'18AD383A-558B-4135-B628-37B67E890BB2', N'110007', N'Small', 1, 0, 0, 0, SYSDATETIMEOFFSET());
    insert into registration.RegistrationSubmissionProducer (Id, RegistrationSubmissionDataId, OrganisationId, OrganisationSize, NationId, IsOnlineMarketplace, IsClosedLoopRecycling, IsNewJoiner, CreatedDate) values (N'02CC5754-3D99-4F07-8492-333483FCDABA', N'18AD383A-558B-4135-B628-37B67E890BB2', N'110008', N'Small', 1, 0, 0, 0, SYSDATETIMEOFFSET());
    insert into registration.RegistrationSubmissionProducer (Id, RegistrationSubmissionDataId, OrganisationId, OrganisationSize, NationId, IsOnlineMarketplace, IsClosedLoopRecycling, IsNewJoiner, CreatedDate) values (N'5DEFB9E4-DD42-489B-AC87-60AB01D42E41', N'18AD383A-558B-4135-B628-37B67E890BB2', N'110009', N'Small', 1, 0, 0, 0, SYSDATETIMEOFFSET());
    insert into registration.RegistrationSubmissionProducer (Id, RegistrationSubmissionDataId, OrganisationId, OrganisationSize, NationId, IsOnlineMarketplace, IsClosedLoopRecycling, IsNewJoiner, CreatedDate) values (N'139B8D57-BEEC-4BDF-ABCB-7926939EA6EB', N'18AD383A-558B-4135-B628-37B67E890BB2', N'110010', N'Small', 1, 0, 0, 0, SYSDATETIMEOFFSET());
end

-- POP QUEST LTD (Direct Producer, CHN 17121895): PayCal registration fee calculation data for its
-- 2 accepted registration submissions. SubmissionId values MUST match
-- compose/synapse-sqlserver-restore/seed/baseline.sql and mocks/CosmosDbInit/Program.cs exactly.
--
-- Two things differ from the Northbridge blocks above because this is a direct producer, not a
-- compliance scheme: ComplianceSchemeId is NULL, and SubmissionPeriodId points at the Direct rows
-- in Lookup.SubmissionPeriod (2 = Direct/2025, 5 = DirectLargeProducer/2026) rather than the Cso
-- ones. OrganisationId/SubsidiaryId use the organisation reference numbers (165282/165283/165284),
-- matching organisation_id/subsidiary_id in this org's rpd.CompanyDetails and rpd.Pom rows.

-- Registration 2026 (SubmissionId C5D6E7F8-A9B0-4C1D-8E2F-3A4B5C6D7E89)
if not exists (select 1 from registration.RegistrationSubmissionData where SubmissionId = N'C5D6E7F8-A9B0-4C1D-8E2F-3A4B5C6D7E89')
begin
    -- AppReferenceNumber must match the Cosmos seed for this SubmissionId (mocks/CosmosDbInit/Program.cs).
    insert into registration.RegistrationSubmissionData (Id, SubmissionId, RegistrationBlobName, ComplianceSchemeId, SubmissionDate, CreatedDate, SubmissionPeriodId, RegulatorNation, ApplicationReferenceNumber) values (N'4E5F1A7B-9C6D-4E3A-9FB5-08124C6D5EA7', N'C5D6E7F8-A9B0-4C1D-8E2F-3A4B5C6D7E89', N'e7f8a9b0-c1d2-4e3f-8a4b-5c6d7e8f9a01', null, N'2026-04-01T09:20:00', SYSDATETIMEOFFSET(), 5, N'GB-ENG', N'PEPR16528226P1');

    insert into registration.RegistrationSubmissionProducer (Id, RegistrationSubmissionDataId, OrganisationId, OrganisationSize, NationId, IsOnlineMarketplace, IsClosedLoopRecycling, IsNewJoiner, CreatedDate) values (N'5F6A2B8C-0D7E-4F4B-8AC6-19235D7E6FB8', N'4E5F1A7B-9C6D-4E3A-9FB5-08124C6D5EA7', N'165282', N'Large', 1, 0, 0, 0, SYSDATETIMEOFFSET());
    insert into registration.RegistrationSubmissionSubsidiary (Id, RegistrationSubmissionProducerId, SubsidiaryId, IsOnlineMarketplace, IsClosedLoopRecycling, IsNewJoiner, CreatedDate) values (N'6A7B3C9D-1E8F-4A5C-9BD7-2A346E8F70C9', N'5F6A2B8C-0D7E-4F4B-8AC6-19235D7E6FB8', N'165283', 0, 0, 0, SYSDATETIMEOFFSET());
    insert into registration.RegistrationSubmissionSubsidiary (Id, RegistrationSubmissionProducerId, SubsidiaryId, IsOnlineMarketplace, IsClosedLoopRecycling, IsNewJoiner, CreatedDate) values (N'7B8C4D0E-2F9A-4B6D-8CE8-3B457F9A81DA', N'5F6A2B8C-0D7E-4F4B-8AC6-19235D7E6FB8', N'165284', 0, 0, 0, SYSDATETIMEOFFSET());
end

-- PayCal Payment records: one per accepted registration above, both Compliance Scheme
-- (Northbridge) and Direct Producer (PopQuest). Reference matches that registration's own
-- ApplicationReferenceNumber; UserId matches the UserId seeded for that registration in Cosmos
-- (mocks/CosmosDbInit/Program.cs) - csApprovedPersonUserId for the Northbridge/Compliance Scheme
-- registrations, approvedPersonUserId for the PopQuest/Direct Producer one.
-- InternalStatusId 2 = Lookup.PaymentStatus 'Success'. CreatedDate/UpdatedDate reuse each
-- registration's own SubmissionDate so the payment date lines up with the registration date;
-- UpdatedByUserId matches UserId since these are seeded as already-settled, with no subsequent
-- update by anyone else. ExternalPaymentId is left to its own DEFAULT (newid()) - any GUID does.
-- Guarded on Reference since dbo.Payment.Id is an identity int with no other natural business key.

-- Northbridge 2025 Large (matches SubmissionId D05A39BD-EC9B-4D4E-AC19-AC4A7A981DE2 in Cosmos -
-- no registration.RegistrationSubmissionData row for this one in this file, same as PopQuest
-- 2025 below; Payment doesn't require one)
if not exists (select 1 from dbo.Payment where Reference = N'NBCS-2025-L-APP-0001')
begin
    insert into dbo.Payment (UserId, InternalStatusId, Regulator, Reference, Amount, ReasonForPayment, CreatedDate, UpdatedByUserId, UpdatedDate)
    values (N'94BFD894-8F64-4F8D-9975-259D08786C2B', 2, 'GB-ENG', N'NBCS-2025-L-APP-0001', 100000.0000, N'Registration Fee', N'2025-04-01T09:20:00', N'94BFD894-8F64-4F8D-9975-259D08786C2B', N'2025-04-01T09:20:00');
end

-- PopQuest 2025 (Direct Producer, matches SubmissionId F2A3B4C5-D6E7-4F8A-8B9C-0D1E2F3A4B56 in
-- Cosmos - no registration.RegistrationSubmissionData row for this one in this file, deliberately)
if not exists (select 1 from dbo.Payment where Reference = N'PQL-2025-APP-0001')
begin
    insert into dbo.Payment (UserId, InternalStatusId, Regulator, Reference, Amount, ReasonForPayment, CreatedDate, UpdatedByUserId, UpdatedDate)
    values (N'79D0DEAB-C22D-4C30-8082-508FF8DC1BD7', 2, 'GB-ENG', N'PQL-2025-APP-0001', 100000.0000, N'Registration Fee', N'2025-04-01T09:20:00', N'79D0DEAB-C22D-4C30-8082-508FF8DC1BD7', N'2025-04-01T09:20:00');
end

-- Northbridge 2026 Large (matches SubmissionId 601A176C-B17B-4B6B-B672-D0C61A44E733)
if not exists (select 1 from dbo.Payment where Reference = N'PEPR11000007226P1')
begin
    insert into dbo.Payment (UserId, InternalStatusId, Regulator, Reference, Amount, ReasonForPayment, CreatedDate, UpdatedByUserId, UpdatedDate)
    values (N'94BFD894-8F64-4F8D-9975-259D08786C2B', 2, 'GB-ENG', N'PEPR11000007226P1', 100000.0000, N'Registration Fee', N'2026-04-08T09:05:00', N'94BFD894-8F64-4F8D-9975-259D08786C2B', N'2026-04-08T09:05:00');
end

-- Northbridge 2026 Small (matches SubmissionId ECE0880A-B713-42D4-A018-92FD3D8053C6)
if not exists (select 1 from dbo.Payment where Reference = N'PEPR11000007226P1S')
begin
    insert into dbo.Payment (UserId, InternalStatusId, Regulator, Reference, Amount, ReasonForPayment, CreatedDate, UpdatedByUserId, UpdatedDate)
    values (N'94BFD894-8F64-4F8D-9975-259D08786C2B', 2, 'GB-ENG', N'PEPR11000007226P1S', 100000.0000, N'Registration Fee', N'2026-04-09T09:35:00', N'94BFD894-8F64-4F8D-9975-259D08786C2B', N'2026-04-09T09:35:00');
end

-- PopQuest 2026 (Direct Producer, matches SubmissionId C5D6E7F8-A9B0-4C1D-8E2F-3A4B5C6D7E89)
if not exists (select 1 from dbo.Payment where Reference = N'PEPR16528226P1')
begin
    insert into dbo.Payment (UserId, InternalStatusId, Regulator, Reference, Amount, ReasonForPayment, CreatedDate, UpdatedByUserId, UpdatedDate)
    values (N'79D0DEAB-C22D-4C30-8082-508FF8DC1BD7', 2, 'GB-ENG', N'PEPR16528226P1', 100000.0000, N'Registration Fee', N'2026-04-01T09:20:00', N'79D0DEAB-C22D-4C30-8082-508FF8DC1BD7', N'2026-04-01T09:20:00');
end

-- Packaging data resubmission fees for the two completed 2026 H1 resubmission cycles. These mirror
-- the PackagingDataResubmissionFeePayment events in mocks/CosmosDbInit/Program.cs and
-- compose/synapse-sqlserver-restore/seed/baseline.sql; Reference is the cycle's resubmission
-- reference number, not the registration ApplicationReferenceNumber used by the blocks above.
--
-- Amounts come from Lookup.RegistrationFees for 2026/GB-ENG rather than being invented:
--   ComplianceSchemeResubmission base 51200 x 5 changed members = 256000 (Northbridge is a CS, and
--   ComplianceSchemeResubmissionService computes baseFee * MemberCount).
--   ProducerResubmission base 80700 for POP QUEST - ProducerResubmissionService only multiplies by
--   MemberCount when EnableResubmissionProducerMemberCountBaseFeeMultiplication is on, and it is not
--   enabled in this stack.
if not exists (select 1 from dbo.Payment where Reference = N'NBCS-2026H1-POM-RESUB-0001')
begin
    insert into dbo.Payment (UserId, InternalStatusId, Regulator, Reference, Amount, ReasonForPayment, CreatedDate, UpdatedByUserId, UpdatedDate)
    values (N'94BFD894-8F64-4F8D-9975-259D08786C2B', 2, 'GB-ENG', N'NBCS-2026H1-POM-RESUB-0001', 256000.0000, N'Packaging Data Resubmission Fee', N'2026-07-07T09:20:00', N'94BFD894-8F64-4F8D-9975-259D08786C2B', N'2026-07-07T09:20:00');
end

if not exists (select 1 from dbo.Payment where Reference = N'PQL-2026H1-POM-RESUB-0001')
begin
    insert into dbo.Payment (UserId, InternalStatusId, Regulator, Reference, Amount, ReasonForPayment, CreatedDate, UpdatedByUserId, UpdatedDate)
    values (N'79D0DEAB-C22D-4C30-8082-508FF8DC1BD7', 2, 'GB-ENG', N'PQL-2026H1-POM-RESUB-0001', 80700.0000, N'Packaging Data Resubmission Fee', N'2026-07-07T09:20:00', N'79D0DEAB-C22D-4C30-8082-508FF8DC1BD7', N'2026-07-07T09:20:00');
end

-- Packaging data resubmission fees for the two completed 2024-P1 resubmission cycles.
-- Amounts use the 2024-2025 band in Lookup.RegistrationFees for GB-ENG:
--   ComplianceSchemeResubmission base 43000 x 5 changed Large members = 215000 (Northbridge).
--   ProducerResubmission base 71400 for POP QUEST (the member-count multiplier feature is off).
if not exists (select 1 from dbo.Payment where Reference = N'NBCS-2024P1-POM-RESUB-0001')
begin
    insert into dbo.Payment (UserId, InternalStatusId, Regulator, Reference, Amount, ReasonForPayment, CreatedDate, UpdatedByUserId, UpdatedDate)
    values (N'94BFD894-8F64-4F8D-9975-259D08786C2B', 2, 'GB-ENG', N'NBCS-2024P1-POM-RESUB-0001', 215000.0000, N'Packaging Data Resubmission Fee', N'2024-09-10T09:20:00', N'94BFD894-8F64-4F8D-9975-259D08786C2B', N'2024-09-10T09:20:00');
end

if not exists (select 1 from dbo.Payment where Reference = N'PQL-2024P1-POM-RESUB-0001')
begin
    insert into dbo.Payment (UserId, InternalStatusId, Regulator, Reference, Amount, ReasonForPayment, CreatedDate, UpdatedByUserId, UpdatedDate)
    values (N'79D0DEAB-C22D-4C30-8082-508FF8DC1BD7', 2, 'GB-ENG', N'PQL-2024P1-POM-RESUB-0001', 71400.0000, N'Packaging Data Resubmission Fee', N'2024-09-10T09:20:00', N'79D0DEAB-C22D-4C30-8082-508FF8DC1BD7', N'2024-09-10T09:20:00');
end
