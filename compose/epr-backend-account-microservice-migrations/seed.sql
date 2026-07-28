declare @userId uniqueidentifier
declare @email nvarchar(255)
set @userId = '579C319D-D552-47A2-BF4C-5A125A3183BC'
set @email = 'test+17122025143216@ee.com'

if not exists (select 1 from Users where UserId = @userId)
    insert into Users (UserId, Email) values (@userId, @email)

if not exists (select 1 from Persons where Email = @email)
    insert into Persons (FirstName, LastName, Email, Telephone, UserId) values ('First name', 'Last Name', @email, '07123456789', (select Id from Users where Email = @email))

-- common to all local seed.sql files
declare @organisationExternalId uniqueidentifier
set @organisationExternalId = '94BFC917-B9B6-45D7-847B-E5F500BFE198'

if not exists (select 1 from Organisations where ExternalId = @organisationExternalId)
    insert into Organisations (OrganisationTypeId, CompaniesHouseNumber, Name, TradingName, ValidatedWithCompaniesHouse, IsComplianceScheme, NationId, ExternalId) values (1, '12345678', 'Organisation Name', 'Trading Name', 1, 1, 1, @organisationExternalId)

declare @organisationId int
set @organisationId = (select Id from Organisations where ExternalId = @organisationExternalId)

if not exists (select 1 from PersonOrganisationConnections where OrganisationId = @organisationId and PersonId = (select Id from Users where Email = @email))
    insert into PersonOrganisationConnections (JobTitle, OrganisationId, OrganisationRoleId, PersonId, PersonRoleId) values ('Director', @organisationId, 1, (select Id from Users where Email = @email), 1)

declare @connectionId int
set @connectionId = (select top 1 Id from PersonOrganisationConnections where OrganisationId = @organisationId and PersonId = (select Id from Users where Email = @email))

if not exists (select 1 from Enrolments where ConnectionId = @connectionId)
    insert into Enrolments (ConnectionId, ServiceRoleId, EnrolmentStatusId) values (@connectionId, 1, 3)

-- common to all local seed.sql files
declare @complianceSchemeExternalId uniqueidentifier
set @complianceSchemeExternalId = 'D93376E3-0681-46BE-AEB4-7450A2E784D8'

if not exists (select 1 from ComplianceSchemes where ExternalId = @complianceSchemeExternalId)
    insert into ComplianceSchemes (Name, ExternalId, CompaniesHouseNumber, NationId) values ('Compliance Scheme Name', @complianceSchemeExternalId,'12345678', 1)

-- Direct Producer user
declare @dpUserId uniqueidentifier
declare @dpEmail nvarchar(255)
set @dpUserId = '79d0deab-c22d-4c30-8082-508ff8dc1bd7'
set @dpEmail = 'test+directproducer@ee.com'

if not exists (select 1 from Users where UserId = @dpUserId)
    insert into Users (UserId, Email) values (@dpUserId, @dpEmail)

if not exists (select 1 from Persons where Email = @dpEmail)
    insert into Persons (FirstName, LastName, Email, Telephone, UserId)
    values ('Direct', 'Producer', @dpEmail, '07123456780',
        (select Id from Users where Email = @dpEmail))

declare @dpOrgExternalId uniqueidentifier
set @dpOrgExternalId = 'e2316c5e-d434-41da-8274-494dc0762d20'

if not exists (select 1 from Organisations where ExternalId = @dpOrgExternalId)
    insert into Organisations (OrganisationTypeId, CompaniesHouseNumber, Name, TradingName,
        ValidatedWithCompaniesHouse, IsComplianceScheme, NationId, ExternalId)
    values (1, '17121895', 'POP QUEST LTD', '', 1, 0, 1, @dpOrgExternalId)

declare @dpOrgId int
set @dpOrgId = (select Id from Organisations where ExternalId = @dpOrgExternalId)

if not exists (select 1 from PersonOrganisationConnections where OrganisationId = @dpOrgId and PersonId = (select Id from Users where Email = @dpEmail))
    insert into PersonOrganisationConnections (JobTitle, OrganisationId, OrganisationRoleId, PersonId, PersonRoleId)
    values ('Director', @dpOrgId, 1,
        (select Id from Users where Email = @dpEmail), 1)

declare @dpConnectionId int
set @dpConnectionId = (select top 1 Id from PersonOrganisationConnections where OrganisationId = @dpOrgId and PersonId = (select Id from Users where Email = @dpEmail))

if not exists (select 1 from Enrolments where ConnectionId = @dpConnectionId)
    insert into Enrolments (ConnectionId, ServiceRoleId, EnrolmentStatusId)
    values (@dpConnectionId, 1, 3)

-- Delegated user for POP QUEST LTD (DP org)
declare @dpDelegatedUserId uniqueidentifier
declare @dpDelegatedEmail nvarchar(255)
set @dpDelegatedUserId = '513a78ee-d5bf-4fa4-9d8f-136550ea6072'
set @dpDelegatedEmail = 'bmmmdmgz@sharklasers.com'

if not exists (select 1 from Users where UserId = @dpDelegatedUserId)
    insert into Users (UserId, Email) values (@dpDelegatedUserId, @dpDelegatedEmail)

if not exists (select 1 from Persons where Email = @dpDelegatedEmail)
    insert into Persons (FirstName, LastName, Email, Telephone, UserId)
    values ('SB FirstName', 'SB LastName', @dpDelegatedEmail, '00441234567890',
        (select Id from Users where Email = @dpDelegatedEmail))

if not exists (select 1 from PersonOrganisationConnections where OrganisationId = @dpOrgId and PersonId = (select Id from Users where Email = @dpDelegatedEmail))
    insert into PersonOrganisationConnections (JobTitle, OrganisationId, OrganisationRoleId, PersonId, PersonRoleId)
    values ('Director', @dpOrgId, 1,
        (select Id from Users where Email = @dpDelegatedEmail), 1)

declare @dpDelegatedConnectionId int
set @dpDelegatedConnectionId = (select top 1 Id from PersonOrganisationConnections where OrganisationId = @dpOrgId and PersonId = (select Id from Users where Email = @dpDelegatedEmail))

if not exists (select 1 from Enrolments where ConnectionId = @dpDelegatedConnectionId)
    insert into Enrolments (ConnectionId, ServiceRoleId, EnrolmentStatusId)
    values (@dpDelegatedConnectionId, 2, 3)

declare @dpDelegatedEnrolmentId int
set @dpDelegatedEnrolmentId = (select top 1 Id from Enrolments where ConnectionId = @dpDelegatedConnectionId)

-- @dpConnectionId is the Approved Person's (test+directproducer@ee.com) connection
declare @nominatorEnrolmentId int
set @nominatorEnrolmentId = (select top 1 Id from Enrolments where ConnectionId = @dpConnectionId)

if not exists (select 1 from DelegatedPersonEnrolments where EnrolmentId = @dpDelegatedEnrolmentId)
    insert into DelegatedPersonEnrolments (EnrolmentId, NominatorEnrolmentId, RelationshipType, NominatorDeclaration, NominatorDeclarationTime, NomineeDeclaration, NomineeDeclarationTime)
    values (@dpDelegatedEnrolmentId, @nominatorEnrolmentId, 'Employment', 'Declaration', GETUTCDATE(), 'Declaration', GETUTCDATE())

-- Basic user for POP QUEST LTD
declare @dpBasicUserId uniqueidentifier
declare @dpBasicEmail nvarchar(255)
set @dpBasicUserId = 'd062d4fe-34f8-468e-ada8-d950cc9a3c2a'
set @dpBasicEmail = 'francis.chelladurai+31032026@equalexperts.com'

if not exists (select 1 from Users where UserId = @dpBasicUserId)
    insert into Users (UserId, Email) values (@dpBasicUserId, @dpBasicEmail)

if not exists (select 1 from Persons where Email = @dpBasicEmail)
    insert into Persons (FirstName, LastName, Email, Telephone, UserId)
    values ('Francis', 'Chelladurai', @dpBasicEmail, '00441234567891',
        (select Id from Users where Email = @dpBasicEmail))

if not exists (select 1 from PersonOrganisationConnections where OrganisationId = @dpOrgId and PersonId = (select Id from Users where Email = @dpBasicEmail))
    insert into PersonOrganisationConnections (JobTitle, OrganisationId, OrganisationRoleId, PersonId, PersonRoleId)
    values ('Director', @dpOrgId, 1,
        (select Id from Users where Email = @dpBasicEmail), 1)

declare @dpBasicConnectionId int
set @dpBasicConnectionId = (select top 1 Id from PersonOrganisationConnections where OrganisationId = @dpOrgId and PersonId = (select Id from Users where Email = @dpBasicEmail))

if not exists (select 1 from Enrolments where ConnectionId = @dpBasicConnectionId)
    insert into Enrolments (ConnectionId, ServiceRoleId, EnrolmentStatusId)
    values (@dpBasicConnectionId, 3, 3)

-- Delegated user for Compliance Scheme org
declare @csDelegatedUserId uniqueidentifier
declare @csDelegatedEmail nvarchar(255)
set @csDelegatedUserId = 'ef2fd2a5-24bf-4b22-89a0-17a0367aee1c'
set @csDelegatedEmail = 'francis.chelladurai+07042026@equalexperts.com'

if not exists (select 1 from Users where UserId = @csDelegatedUserId)
    insert into Users (UserId, Email) values (@csDelegatedUserId, @csDelegatedEmail)

if not exists (select 1 from Persons where Email = @csDelegatedEmail)
    insert into Persons (FirstName, LastName, Email, Telephone, UserId)
    values ('Francis', 'Delegated', @csDelegatedEmail, '00441234567892',
        (select Id from Users where Email = @csDelegatedEmail))

if not exists (select 1 from PersonOrganisationConnections where OrganisationId = @organisationId and PersonId = (select Id from Users where Email = @csDelegatedEmail))
    insert into PersonOrganisationConnections (JobTitle, OrganisationId, OrganisationRoleId, PersonId, PersonRoleId)
    values ('Director', @organisationId, 1,
        (select Id from Users where Email = @csDelegatedEmail), 1)

declare @csDelegatedConnectionId int
set @csDelegatedConnectionId = (select top 1 Id from PersonOrganisationConnections where OrganisationId = @organisationId and PersonId = (select Id from Users where Email = @csDelegatedEmail))

if not exists (select 1 from Enrolments where ConnectionId = @csDelegatedConnectionId)
    insert into Enrolments (ConnectionId, ServiceRoleId, EnrolmentStatusId)
    values (@csDelegatedConnectionId, 2, 3)

declare @csDelegatedEnrolmentId int
set @csDelegatedEnrolmentId = (select top 1 Id from Enrolments where ConnectionId = @csDelegatedConnectionId)

-- @connectionId is the Approved Person's (test+17122025143216@ee.com) connection on the compliance scheme org
declare @csNominatorEnrolmentId int
set @csNominatorEnrolmentId = (select top 1 Id from Enrolments where ConnectionId = @connectionId)

if not exists (select 1 from DelegatedPersonEnrolments where EnrolmentId = @csDelegatedEnrolmentId)
    insert into DelegatedPersonEnrolments (EnrolmentId, NominatorEnrolmentId, RelationshipType, NominatorDeclaration, NominatorDeclarationTime, NomineeDeclaration, NomineeDeclarationTime)
    values (@csDelegatedEnrolmentId, @csNominatorEnrolmentId, 'Employment', 'Declaration', GETUTCDATE(), 'Declaration', GETUTCDATE())

-- Basic user for Compliance Scheme org
declare @csBasicUserId uniqueidentifier
declare @csBasicEmail nvarchar(255)
set @csBasicUserId = '13e26b8a-e2b2-4870-b040-d6bdf5d689fa'
set @csBasicEmail = 'francis.chelladurai+260407@equalexperts.com'

if not exists (select 1 from Users where UserId = @csBasicUserId)
    insert into Users (UserId, Email) values (@csBasicUserId, @csBasicEmail)

if not exists (select 1 from Persons where Email = @csBasicEmail)
    insert into Persons (FirstName, LastName, Email, Telephone, UserId)
    values ('Francis', 'Basic', @csBasicEmail, '00441234567893',
        (select Id from Users where Email = @csBasicEmail))

if not exists (select 1 from PersonOrganisationConnections where OrganisationId = @organisationId and PersonId = (select Id from Users where Email = @csBasicEmail))
    insert into PersonOrganisationConnections (JobTitle, OrganisationId, OrganisationRoleId, PersonId, PersonRoleId)
    values ('Director', @organisationId, 1,
        (select Id from Users where Email = @csBasicEmail), 1)

declare @csBasicConnectionId int
set @csBasicConnectionId = (select top 1 Id from PersonOrganisationConnections where OrganisationId = @organisationId and PersonId = (select Id from Users where Email = @csBasicEmail))

if not exists (select 1 from Enrolments where ConnectionId = @csBasicConnectionId)
    insert into Enrolments (ConnectionId, ServiceRoleId, EnrolmentStatusId)
    values (@csBasicConnectionId, 3, 3)

-- Mirror the waste-organisations Mongo fixtures so /api/organisations/organisations-by-externalIds
-- returns reference numbers for the compliance-scheme and direct-producer orgs that show up in the
-- certificates-of-compliance "not-submitted" tabs.
merge Organisations as tgt
using (values
    ('07D0A580-AB20-4EE2-BD78-702A793B4D34', N'EcoCircle Holdings',      1),
    ('34341291-B377-4047-AD96-93DDB0A1C469', N'ZESTY GOODS LTD',         0),
    ('42D6A04F-41DC-4E54-8A90-A4B662E5F6EF', N'GADGET CO LTD',           0),
    ('51478EFF-46C5-4387-9E95-AD8DD1E6B20E', N'BIG BOX RETAIL LTD',      0),
    ('7F72952A-1AAF-4D04-BD9B-146C04AA207D', N'WastePartners Group',     1),
    ('8947D193-F977-46BD-8BEB-52D55C4ECA69', N'ReClaim Partners Ltd',    1),
    ('8C910C57-4231-465D-905F-0E20CC083566', N'GreenWaste Operator Ltd', 1),
    ('C5C102BB-11F2-4662-BB77-D724F736F80B', N'CRAFTY THINGS LTD',       0),
    ('CCB3F815-7E75-4DFB-B52A-869D9E7A22C0', N'CleanLoop Operator Ltd',  1),
    ('D0AB1AED-D4FC-4A88-98F0-B8BAE048F170', N'PARCEL PROS LTD',         0),
    ('D93376E3-0681-46BE-AEB4-7450A2E784D8', N'Organisation Name',       1)
) as src (ExternalId, Name, IsComplianceScheme)
on tgt.ExternalId = src.ExternalId
when not matched then
    insert (OrganisationTypeId, Name, ValidatedWithCompaniesHouse, IsComplianceScheme, NationId, ExternalId)
    values (1, src.Name, 1, src.IsComplianceScheme, 1, src.ExternalId);

-- ============================================================
-- New Compliance Scheme: Northbridge Compliance Solutions Ltd
-- with an Approved/Delegated/Basic user, 10 member organisations,
-- and 4 subsidiary companies attached to two of those members
-- ============================================================

-- Compliance Scheme organisation + scheme record
declare @csNewOrgExternalId uniqueidentifier
set @csNewOrgExternalId = '0BB650B9-125E-4D64-B1D0-06B9E167B2D4'

if not exists (select 1 from Organisations where ExternalId = @csNewOrgExternalId)
    insert into Organisations (OrganisationTypeId, CompaniesHouseNumber, Name, TradingName, ValidatedWithCompaniesHouse, IsComplianceScheme, NationId, ExternalId)
    values (1, '11000000', 'Northbridge Compliance Solutions Ltd', '', 1, 1, 1, @csNewOrgExternalId)

declare @csNewOrgId int
set @csNewOrgId = (select Id from Organisations where ExternalId = @csNewOrgExternalId)

declare @csNewSchemeExternalId uniqueidentifier
set @csNewSchemeExternalId = 'CAC58048-62A1-4419-9BEE-4B386454D776'

if not exists (select 1 from ComplianceSchemes where ExternalId = @csNewSchemeExternalId)
    insert into ComplianceSchemes (Name, ExternalId, CompaniesHouseNumber, NationId)
    values ('Northbridge Compliance Solutions Ltd', @csNewSchemeExternalId, '11000000', 1)

declare @csNewSchemeId int
set @csNewSchemeId = (select Id from ComplianceSchemes where ExternalId = @csNewSchemeExternalId)

-- Approved user for Northbridge Compliance Solutions Ltd
declare @csNewApprovedUserId uniqueidentifier
declare @csNewApprovedEmail nvarchar(255)
set @csNewApprovedUserId = '94BFD894-8F64-4F8D-9975-259D08786C2B'
set @csNewApprovedEmail = 'ahmed.hussein+dev9+1784615966009+09640-DONT_USE@equalexperts.com'

if not exists (select 1 from Users where UserId = @csNewApprovedUserId)
    insert into Users (UserId, Email) values (@csNewApprovedUserId, @csNewApprovedEmail)

if not exists (select 1 from Persons where Email = @csNewApprovedEmail)
    insert into Persons (FirstName, LastName, Email, Telephone, UserId)
    values ('Olivia', 'Bennett', @csNewApprovedEmail, '07700900101',
        (select Id from Users where Email = @csNewApprovedEmail))

if not exists (select 1 from PersonOrganisationConnections where OrganisationId = @csNewOrgId and PersonId = (select Id from Users where Email = @csNewApprovedEmail))
    insert into PersonOrganisationConnections (JobTitle, OrganisationId, OrganisationRoleId, PersonId, PersonRoleId)
    values ('Director', @csNewOrgId, 1,
        (select Id from Users where Email = @csNewApprovedEmail), 1)

declare @csNewApprovedConnectionId int
set @csNewApprovedConnectionId = (select top 1 Id from PersonOrganisationConnections where OrganisationId = @csNewOrgId and PersonId = (select Id from Users where Email = @csNewApprovedEmail))

if not exists (select 1 from Enrolments where ConnectionId = @csNewApprovedConnectionId)
    insert into Enrolments (ConnectionId, ServiceRoleId, EnrolmentStatusId)
    values (@csNewApprovedConnectionId, 1, 3)

declare @csNewApprovedEnrolmentId int
set @csNewApprovedEnrolmentId = (select top 1 Id from Enrolments where ConnectionId = @csNewApprovedConnectionId)

-- Delegated user for Northbridge Compliance Solutions Ltd
declare @csNewDelegatedUserId uniqueidentifier
declare @csNewDelegatedEmail nvarchar(255)
set @csNewDelegatedUserId = 'F0CA633F-C62F-4DDB-8009-893C1DF9EBC3'
set @csNewDelegatedEmail = 'ahmed.hussein+dev9+1784616197060+61532-DONT_USE@equalexperts.com'

if not exists (select 1 from Users where UserId = @csNewDelegatedUserId)
    insert into Users (UserId, Email) values (@csNewDelegatedUserId, @csNewDelegatedEmail)

if not exists (select 1 from Persons where Email = @csNewDelegatedEmail)
    insert into Persons (FirstName, LastName, Email, Telephone, UserId)
    values ('Thomas', 'Wright', @csNewDelegatedEmail, '07700900102',
        (select Id from Users where Email = @csNewDelegatedEmail))

if not exists (select 1 from PersonOrganisationConnections where OrganisationId = @csNewOrgId and PersonId = (select Id from Users where Email = @csNewDelegatedEmail))
    insert into PersonOrganisationConnections (JobTitle, OrganisationId, OrganisationRoleId, PersonId, PersonRoleId)
    values ('Director', @csNewOrgId, 1,
        (select Id from Users where Email = @csNewDelegatedEmail), 1)

declare @csNewDelegatedConnectionId int
set @csNewDelegatedConnectionId = (select top 1 Id from PersonOrganisationConnections where OrganisationId = @csNewOrgId and PersonId = (select Id from Users where Email = @csNewDelegatedEmail))

if not exists (select 1 from Enrolments where ConnectionId = @csNewDelegatedConnectionId)
    insert into Enrolments (ConnectionId, ServiceRoleId, EnrolmentStatusId)
    values (@csNewDelegatedConnectionId, 2, 3)

declare @csNewDelegatedEnrolmentId int
set @csNewDelegatedEnrolmentId = (select top 1 Id from Enrolments where ConnectionId = @csNewDelegatedConnectionId)

-- @csNewApprovedConnectionId is the Approved Person's connection on the new compliance scheme org
if not exists (select 1 from DelegatedPersonEnrolments where EnrolmentId = @csNewDelegatedEnrolmentId)
    insert into DelegatedPersonEnrolments (EnrolmentId, NominatorEnrolmentId, RelationshipType, NominatorDeclaration, NominatorDeclarationTime, NomineeDeclaration, NomineeDeclarationTime)
    values (@csNewDelegatedEnrolmentId, @csNewApprovedEnrolmentId, 'Employment', 'Declaration', GETUTCDATE(), 'Declaration', GETUTCDATE())

-- Basic user for Northbridge Compliance Solutions Ltd
declare @csNewBasicUserId uniqueidentifier
declare @csNewBasicEmail nvarchar(255)
set @csNewBasicUserId = '637B0DEA-83FA-49CE-AFD9-C5527A820CE1'
set @csNewBasicEmail = 'ahmed.hussein+dev9+1784616229626+56548-DONT_USE@equalexperts.com'

if not exists (select 1 from Users where UserId = @csNewBasicUserId)
    insert into Users (UserId, Email) values (@csNewBasicUserId, @csNewBasicEmail)

if not exists (select 1 from Persons where Email = @csNewBasicEmail)
    insert into Persons (FirstName, LastName, Email, Telephone, UserId)
    values ('Grace', 'Mitchell', @csNewBasicEmail, '07700900103',
        (select Id from Users where Email = @csNewBasicEmail))

if not exists (select 1 from PersonOrganisationConnections where OrganisationId = @csNewOrgId and PersonId = (select Id from Users where Email = @csNewBasicEmail))
    insert into PersonOrganisationConnections (JobTitle, OrganisationId, OrganisationRoleId, PersonId, PersonRoleId)
    values ('Director', @csNewOrgId, 1,
        (select Id from Users where Email = @csNewBasicEmail), 1)

declare @csNewBasicConnectionId int
set @csNewBasicConnectionId = (select top 1 Id from PersonOrganisationConnections where OrganisationId = @csNewOrgId and PersonId = (select Id from Users where Email = @csNewBasicEmail))

if not exists (select 1 from Enrolments where ConnectionId = @csNewBasicConnectionId)
    insert into Enrolments (ConnectionId, ServiceRoleId, EnrolmentStatusId)
    values (@csNewBasicConnectionId, 3, 3)

-- ============================================================
-- Member organisation 1 of 10: BRAMBLEWOOD PACKAGING LTD
-- ============================================================
declare @m1OrgExternalId uniqueidentifier
set @m1OrgExternalId = '3151DBE5-A8AD-4D82-9471-1C469FA13918'

if not exists (select 1 from Organisations where ExternalId = @m1OrgExternalId)
    insert into Organisations (OrganisationTypeId, CompaniesHouseNumber, Name, TradingName, ValidatedWithCompaniesHouse, IsComplianceScheme, NationId, ExternalId)
    values (1, '11000001', 'BRAMBLEWOOD PACKAGING LTD', '', 1, 0, 1, @m1OrgExternalId)

declare @m1OrgId int
set @m1OrgId = (select Id from Organisations where ExternalId = @m1OrgExternalId)

declare @m1UserId uniqueidentifier
declare @m1Email nvarchar(255)
set @m1UserId = 'A16AE06C-3629-4F04-89A6-B8D1912C99FE'
set @m1Email = 'ahmed.hussein+dev9+1782714701839+98807-DONT_USE@equalexperts.com'

if not exists (select 1 from Users where UserId = @m1UserId)
    insert into Users (UserId, Email) values (@m1UserId, @m1Email)

if not exists (select 1 from Persons where Email = @m1Email)
    insert into Persons (FirstName, LastName, Email, Telephone, UserId)
    values ('James', 'Carter', @m1Email, '07700900201',
        (select Id from Users where Email = @m1Email))

if not exists (select 1 from PersonOrganisationConnections where OrganisationId = @m1OrgId and PersonId = (select Id from Users where Email = @m1Email))
    insert into PersonOrganisationConnections (JobTitle, OrganisationId, OrganisationRoleId, PersonId, PersonRoleId)
    values ('Director', @m1OrgId, 1,
        (select Id from Users where Email = @m1Email), 1)

declare @m1ConnectionId int
set @m1ConnectionId = (select top 1 Id from PersonOrganisationConnections where OrganisationId = @m1OrgId and PersonId = (select Id from Users where Email = @m1Email))

if not exists (select 1 from Enrolments where ConnectionId = @m1ConnectionId)
    insert into Enrolments (ConnectionId, ServiceRoleId, EnrolmentStatusId)
    values (@m1ConnectionId, 1, 3)

if not exists (select 1 from OrganisationsConnections where FromOrganisationId = @m1OrgId and ToOrganisationId = @csNewOrgId)
    insert into OrganisationsConnections (FromOrganisationId, FromOrganisationRoleId, ToOrganisationId, ToOrganisationRoleId)
    values (@m1OrgId, 1, @csNewOrgId, 2)

declare @m1OrgConnectionId int
set @m1OrgConnectionId = (select top 1 Id from OrganisationsConnections where FromOrganisationId = @m1OrgId and ToOrganisationId = @csNewOrgId)

if not exists (select 1 from SelectedSchemes where OrganisationConnectionId = @m1OrgConnectionId and ComplianceSchemeId = @csNewSchemeId)
    insert into SelectedSchemes (OrganisationConnectionId, ComplianceSchemeId)
    values (@m1OrgConnectionId, @csNewSchemeId)

-- ============================================================
-- Member organisation 2 of 10: SILVERDALE FOODS LTD
-- ============================================================
declare @m2OrgExternalId uniqueidentifier
set @m2OrgExternalId = '4BDF517C-6270-4660-8B5E-97ADD9379A2A'

if not exists (select 1 from Organisations where ExternalId = @m2OrgExternalId)
    insert into Organisations (OrganisationTypeId, CompaniesHouseNumber, Name, TradingName, ValidatedWithCompaniesHouse, IsComplianceScheme, NationId, ExternalId)
    values (1, '11000002', 'SILVERDALE FOODS LTD', '', 1, 0, 1, @m2OrgExternalId)

declare @m2OrgId int
set @m2OrgId = (select Id from Organisations where ExternalId = @m2OrgExternalId)

declare @m2UserId uniqueidentifier
declare @m2Email nvarchar(255)
set @m2UserId = '972111C5-42D1-4AAA-A076-BD61098A75C7'
set @m2Email = 'ahmed.hussein+dev9+1782714726947+48306-DONT_USE@equalexperts.com'

if not exists (select 1 from Users where UserId = @m2UserId)
    insert into Users (UserId, Email) values (@m2UserId, @m2Email)

if not exists (select 1 from Persons where Email = @m2Email)
    insert into Persons (FirstName, LastName, Email, Telephone, UserId)
    values ('Sophie', 'Turner', @m2Email, '07700900202',
        (select Id from Users where Email = @m2Email))

if not exists (select 1 from PersonOrganisationConnections where OrganisationId = @m2OrgId and PersonId = (select Id from Users where Email = @m2Email))
    insert into PersonOrganisationConnections (JobTitle, OrganisationId, OrganisationRoleId, PersonId, PersonRoleId)
    values ('Director', @m2OrgId, 1,
        (select Id from Users where Email = @m2Email), 1)

declare @m2ConnectionId int
set @m2ConnectionId = (select top 1 Id from PersonOrganisationConnections where OrganisationId = @m2OrgId and PersonId = (select Id from Users where Email = @m2Email))

if not exists (select 1 from Enrolments where ConnectionId = @m2ConnectionId)
    insert into Enrolments (ConnectionId, ServiceRoleId, EnrolmentStatusId)
    values (@m2ConnectionId, 1, 3)

if not exists (select 1 from OrganisationsConnections where FromOrganisationId = @m2OrgId and ToOrganisationId = @csNewOrgId)
    insert into OrganisationsConnections (FromOrganisationId, FromOrganisationRoleId, ToOrganisationId, ToOrganisationRoleId)
    values (@m2OrgId, 1, @csNewOrgId, 2)

declare @m2OrgConnectionId int
set @m2OrgConnectionId = (select top 1 Id from OrganisationsConnections where FromOrganisationId = @m2OrgId and ToOrganisationId = @csNewOrgId)

if not exists (select 1 from SelectedSchemes where OrganisationConnectionId = @m2OrgConnectionId and ComplianceSchemeId = @csNewSchemeId)
    insert into SelectedSchemes (OrganisationConnectionId, ComplianceSchemeId)
    values (@m2OrgConnectionId, @csNewSchemeId)

-- ============================================================
-- Member organisation 3 of 10: TIDELINE BEVERAGES LTD
-- ============================================================
declare @m3OrgExternalId uniqueidentifier
set @m3OrgExternalId = '1E7967C2-56DB-4686-8E3E-0815B86A6530'

if not exists (select 1 from Organisations where ExternalId = @m3OrgExternalId)
    insert into Organisations (OrganisationTypeId, CompaniesHouseNumber, Name, TradingName, ValidatedWithCompaniesHouse, IsComplianceScheme, NationId, ExternalId)
    values (1, '11000003', 'TIDELINE BEVERAGES LTD', '', 1, 0, 1, @m3OrgExternalId)

declare @m3OrgId int
set @m3OrgId = (select Id from Organisations where ExternalId = @m3OrgExternalId)

declare @m3UserId uniqueidentifier
declare @m3Email nvarchar(255)
set @m3UserId = '8CE8A6C7-16E6-412F-ABBE-036C2DD7E11A'
set @m3Email = 'ahmed.hussein+dev9+1782714740443+61628-DONT_USE@equalexperts.com'

if not exists (select 1 from Users where UserId = @m3UserId)
    insert into Users (UserId, Email) values (@m3UserId, @m3Email)

if not exists (select 1 from Persons where Email = @m3Email)
    insert into Persons (FirstName, LastName, Email, Telephone, UserId)
    values ('Daniel', 'Clarke', @m3Email, '07700900203',
        (select Id from Users where Email = @m3Email))

if not exists (select 1 from PersonOrganisationConnections where OrganisationId = @m3OrgId and PersonId = (select Id from Users where Email = @m3Email))
    insert into PersonOrganisationConnections (JobTitle, OrganisationId, OrganisationRoleId, PersonId, PersonRoleId)
    values ('Director', @m3OrgId, 1,
        (select Id from Users where Email = @m3Email), 1)

declare @m3ConnectionId int
set @m3ConnectionId = (select top 1 Id from PersonOrganisationConnections where OrganisationId = @m3OrgId and PersonId = (select Id from Users where Email = @m3Email))

if not exists (select 1 from Enrolments where ConnectionId = @m3ConnectionId)
    insert into Enrolments (ConnectionId, ServiceRoleId, EnrolmentStatusId)
    values (@m3ConnectionId, 1, 3)

if not exists (select 1 from OrganisationsConnections where FromOrganisationId = @m3OrgId and ToOrganisationId = @csNewOrgId)
    insert into OrganisationsConnections (FromOrganisationId, FromOrganisationRoleId, ToOrganisationId, ToOrganisationRoleId)
    values (@m3OrgId, 1, @csNewOrgId, 2)

declare @m3OrgConnectionId int
set @m3OrgConnectionId = (select top 1 Id from OrganisationsConnections where FromOrganisationId = @m3OrgId and ToOrganisationId = @csNewOrgId)

if not exists (select 1 from SelectedSchemes where OrganisationConnectionId = @m3OrgConnectionId and ComplianceSchemeId = @csNewSchemeId)
    insert into SelectedSchemes (OrganisationConnectionId, ComplianceSchemeId)
    values (@m3OrgConnectionId, @csNewSchemeId)

-- ============================================================
-- Member organisation 4 of 10: COPPERGATE HOMEWARES LTD
-- ============================================================
declare @m4OrgExternalId uniqueidentifier
set @m4OrgExternalId = '6F9EDECE-A5A4-4446-8A59-709BA6A251BF'

if not exists (select 1 from Organisations where ExternalId = @m4OrgExternalId)
    insert into Organisations (OrganisationTypeId, CompaniesHouseNumber, Name, TradingName, ValidatedWithCompaniesHouse, IsComplianceScheme, NationId, ExternalId)
    values (1, '11000004', 'COPPERGATE HOMEWARES LTD', '', 1, 0, 1, @m4OrgExternalId)

declare @m4OrgId int
set @m4OrgId = (select Id from Organisations where ExternalId = @m4OrgExternalId)

declare @m4UserId uniqueidentifier
declare @m4Email nvarchar(255)
set @m4UserId = '410953E4-5D24-4A3C-95F6-E38E8E6802A1'
set @m4Email = 'ahmed.hussein+dev9+1782714811219+93870-DONT_USE@equalexperts.com'

if not exists (select 1 from Users where UserId = @m4UserId)
    insert into Users (UserId, Email) values (@m4UserId, @m4Email)

if not exists (select 1 from Persons where Email = @m4Email)
    insert into Persons (FirstName, LastName, Email, Telephone, UserId)
    values ('Emily', 'Foster', @m4Email, '07700900204',
        (select Id from Users where Email = @m4Email))

if not exists (select 1 from PersonOrganisationConnections where OrganisationId = @m4OrgId and PersonId = (select Id from Users where Email = @m4Email))
    insert into PersonOrganisationConnections (JobTitle, OrganisationId, OrganisationRoleId, PersonId, PersonRoleId)
    values ('Director', @m4OrgId, 1,
        (select Id from Users where Email = @m4Email), 1)

declare @m4ConnectionId int
set @m4ConnectionId = (select top 1 Id from PersonOrganisationConnections where OrganisationId = @m4OrgId and PersonId = (select Id from Users where Email = @m4Email))

if not exists (select 1 from Enrolments where ConnectionId = @m4ConnectionId)
    insert into Enrolments (ConnectionId, ServiceRoleId, EnrolmentStatusId)
    values (@m4ConnectionId, 1, 3)

if not exists (select 1 from OrganisationsConnections where FromOrganisationId = @m4OrgId and ToOrganisationId = @csNewOrgId)
    insert into OrganisationsConnections (FromOrganisationId, FromOrganisationRoleId, ToOrganisationId, ToOrganisationRoleId)
    values (@m4OrgId, 1, @csNewOrgId, 2)

declare @m4OrgConnectionId int
set @m4OrgConnectionId = (select top 1 Id from OrganisationsConnections where FromOrganisationId = @m4OrgId and ToOrganisationId = @csNewOrgId)

if not exists (select 1 from SelectedSchemes where OrganisationConnectionId = @m4OrgConnectionId and ComplianceSchemeId = @csNewSchemeId)
    insert into SelectedSchemes (OrganisationConnectionId, ComplianceSchemeId)
    values (@m4OrgConnectionId, @csNewSchemeId)

-- ============================================================
-- Member organisation 5 of 10: FERNLEIGH COSMETICS LTD
-- ============================================================
declare @m5OrgExternalId uniqueidentifier
set @m5OrgExternalId = '7E3FB4D2-6F42-4B29-A9EB-4E742E6188F7'

if not exists (select 1 from Organisations where ExternalId = @m5OrgExternalId)
    insert into Organisations (OrganisationTypeId, CompaniesHouseNumber, Name, TradingName, ValidatedWithCompaniesHouse, IsComplianceScheme, NationId, ExternalId)
    values (1, '11000005', 'FERNLEIGH COSMETICS LTD', '', 1, 0, 1, @m5OrgExternalId)

declare @m5OrgId int
set @m5OrgId = (select Id from Organisations where ExternalId = @m5OrgExternalId)

declare @m5UserId uniqueidentifier
declare @m5Email nvarchar(255)
set @m5UserId = '575067A3-F25E-4B5A-91BC-5BC763BF7556'
set @m5Email = 'ahmed.hussein+dev9+1782714821734+90170-DONT_USE@equalexperts.com'

if not exists (select 1 from Users where UserId = @m5UserId)
    insert into Users (UserId, Email) values (@m5UserId, @m5Email)

if not exists (select 1 from Persons where Email = @m5Email)
    insert into Persons (FirstName, LastName, Email, Telephone, UserId)
    values ('Michael', 'Reid', @m5Email, '07700900205',
        (select Id from Users where Email = @m5Email))

if not exists (select 1 from PersonOrganisationConnections where OrganisationId = @m5OrgId and PersonId = (select Id from Users where Email = @m5Email))
    insert into PersonOrganisationConnections (JobTitle, OrganisationId, OrganisationRoleId, PersonId, PersonRoleId)
    values ('Director', @m5OrgId, 1,
        (select Id from Users where Email = @m5Email), 1)

declare @m5ConnectionId int
set @m5ConnectionId = (select top 1 Id from PersonOrganisationConnections where OrganisationId = @m5OrgId and PersonId = (select Id from Users where Email = @m5Email))

if not exists (select 1 from Enrolments where ConnectionId = @m5ConnectionId)
    insert into Enrolments (ConnectionId, ServiceRoleId, EnrolmentStatusId)
    values (@m5ConnectionId, 1, 3)

if not exists (select 1 from OrganisationsConnections where FromOrganisationId = @m5OrgId and ToOrganisationId = @csNewOrgId)
    insert into OrganisationsConnections (FromOrganisationId, FromOrganisationRoleId, ToOrganisationId, ToOrganisationRoleId)
    values (@m5OrgId, 1, @csNewOrgId, 2)

declare @m5OrgConnectionId int
set @m5OrgConnectionId = (select top 1 Id from OrganisationsConnections where FromOrganisationId = @m5OrgId and ToOrganisationId = @csNewOrgId)

if not exists (select 1 from SelectedSchemes where OrganisationConnectionId = @m5OrgConnectionId and ComplianceSchemeId = @csNewSchemeId)
    insert into SelectedSchemes (OrganisationConnectionId, ComplianceSchemeId)
    values (@m5OrgConnectionId, @csNewSchemeId)

-- ============================================================
-- Member organisation 6 of 10: QUARRYSTONE HARDWARE LTD
-- ============================================================
declare @m6OrgExternalId uniqueidentifier
set @m6OrgExternalId = '21476EDE-69EC-4DEE-A9BC-1EB1E17770FD'

if not exists (select 1 from Organisations where ExternalId = @m6OrgExternalId)
    insert into Organisations (OrganisationTypeId, CompaniesHouseNumber, Name, TradingName, ValidatedWithCompaniesHouse, IsComplianceScheme, NationId, ExternalId)
    values (1, '11000006', 'QUARRYSTONE HARDWARE LTD', '', 1, 0, 1, @m6OrgExternalId)

declare @m6OrgId int
set @m6OrgId = (select Id from Organisations where ExternalId = @m6OrgExternalId)

declare @m6UserId uniqueidentifier
declare @m6Email nvarchar(255)
set @m6UserId = '9ECC9140-47E7-4E5E-9B71-1FF3129C5EB5'
set @m6Email = 'ahmed.hussein+dev9+1782714833475+55076-DONT_USE@equalexperts.com'

if not exists (select 1 from Users where UserId = @m6UserId)
    insert into Users (UserId, Email) values (@m6UserId, @m6Email)

if not exists (select 1 from Persons where Email = @m6Email)
    insert into Persons (FirstName, LastName, Email, Telephone, UserId)
    values ('Charlotte', 'Hughes', @m6Email, '07700900206',
        (select Id from Users where Email = @m6Email))

if not exists (select 1 from PersonOrganisationConnections where OrganisationId = @m6OrgId and PersonId = (select Id from Users where Email = @m6Email))
    insert into PersonOrganisationConnections (JobTitle, OrganisationId, OrganisationRoleId, PersonId, PersonRoleId)
    values ('Director', @m6OrgId, 1,
        (select Id from Users where Email = @m6Email), 1)

declare @m6ConnectionId int
set @m6ConnectionId = (select top 1 Id from PersonOrganisationConnections where OrganisationId = @m6OrgId and PersonId = (select Id from Users where Email = @m6Email))

if not exists (select 1 from Enrolments where ConnectionId = @m6ConnectionId)
    insert into Enrolments (ConnectionId, ServiceRoleId, EnrolmentStatusId)
    values (@m6ConnectionId, 1, 3)

if not exists (select 1 from OrganisationsConnections where FromOrganisationId = @m6OrgId and ToOrganisationId = @csNewOrgId)
    insert into OrganisationsConnections (FromOrganisationId, FromOrganisationRoleId, ToOrganisationId, ToOrganisationRoleId)
    values (@m6OrgId, 1, @csNewOrgId, 2)

declare @m6OrgConnectionId int
set @m6OrgConnectionId = (select top 1 Id from OrganisationsConnections where FromOrganisationId = @m6OrgId and ToOrganisationId = @csNewOrgId)

if not exists (select 1 from SelectedSchemes where OrganisationConnectionId = @m6OrgConnectionId and ComplianceSchemeId = @csNewSchemeId)
    insert into SelectedSchemes (OrganisationConnectionId, ComplianceSchemeId)
    values (@m6OrgConnectionId, @csNewSchemeId)

-- ============================================================
-- Member organisation 7 of 10: MAPLECROFT STATIONERY LTD
-- ============================================================
declare @m7OrgExternalId uniqueidentifier
set @m7OrgExternalId = 'FF2991E2-442E-4582-8357-1F99149A05EC'

if not exists (select 1 from Organisations where ExternalId = @m7OrgExternalId)
    insert into Organisations (OrganisationTypeId, CompaniesHouseNumber, Name, TradingName, ValidatedWithCompaniesHouse, IsComplianceScheme, NationId, ExternalId)
    values (1, '11000007', 'MAPLECROFT STATIONERY LTD', '', 1, 0, 1, @m7OrgExternalId)

declare @m7OrgId int
set @m7OrgId = (select Id from Organisations where ExternalId = @m7OrgExternalId)

declare @m7UserId uniqueidentifier
declare @m7Email nvarchar(255)
set @m7UserId = '103B8411-58F4-4B71-B985-B3A4450B32B3'
set @m7Email = 'ahmed.hussein+dev9+1782714878221+10813-DONT_USE@equalexperts.com'

if not exists (select 1 from Users where UserId = @m7UserId)
    insert into Users (UserId, Email) values (@m7UserId, @m7Email)

if not exists (select 1 from Persons where Email = @m7Email)
    insert into Persons (FirstName, LastName, Email, Telephone, UserId)
    values ('Benjamin', 'Cole', @m7Email, '07700900207',
        (select Id from Users where Email = @m7Email))

if not exists (select 1 from PersonOrganisationConnections where OrganisationId = @m7OrgId and PersonId = (select Id from Users where Email = @m7Email))
    insert into PersonOrganisationConnections (JobTitle, OrganisationId, OrganisationRoleId, PersonId, PersonRoleId)
    values ('Director', @m7OrgId, 1,
        (select Id from Users where Email = @m7Email), 1)

declare @m7ConnectionId int
set @m7ConnectionId = (select top 1 Id from PersonOrganisationConnections where OrganisationId = @m7OrgId and PersonId = (select Id from Users where Email = @m7Email))

if not exists (select 1 from Enrolments where ConnectionId = @m7ConnectionId)
    insert into Enrolments (ConnectionId, ServiceRoleId, EnrolmentStatusId)
    values (@m7ConnectionId, 1, 3)

if not exists (select 1 from OrganisationsConnections where FromOrganisationId = @m7OrgId and ToOrganisationId = @csNewOrgId)
    insert into OrganisationsConnections (FromOrganisationId, FromOrganisationRoleId, ToOrganisationId, ToOrganisationRoleId)
    values (@m7OrgId, 1, @csNewOrgId, 2)

declare @m7OrgConnectionId int
set @m7OrgConnectionId = (select top 1 Id from OrganisationsConnections where FromOrganisationId = @m7OrgId and ToOrganisationId = @csNewOrgId)

if not exists (select 1 from SelectedSchemes where OrganisationConnectionId = @m7OrgConnectionId and ComplianceSchemeId = @csNewSchemeId)
    insert into SelectedSchemes (OrganisationConnectionId, ComplianceSchemeId)
    values (@m7OrgConnectionId, @csNewSchemeId)

-- ============================================================
-- Member organisation 8 of 10: HARBOURVIEW TEXTILES LTD
-- ============================================================
declare @m8OrgExternalId uniqueidentifier
set @m8OrgExternalId = '7C24CCF3-3B59-475C-9292-2102ADD4E40A'

if not exists (select 1 from Organisations where ExternalId = @m8OrgExternalId)
    insert into Organisations (OrganisationTypeId, CompaniesHouseNumber, Name, TradingName, ValidatedWithCompaniesHouse, IsComplianceScheme, NationId, ExternalId)
    values (1, '11000008', 'HARBOURVIEW TEXTILES LTD', '', 1, 0, 1, @m8OrgExternalId)

declare @m8OrgId int
set @m8OrgId = (select Id from Organisations where ExternalId = @m8OrgExternalId)

declare @m8UserId uniqueidentifier
declare @m8Email nvarchar(255)
set @m8UserId = 'FFD8A042-7BFB-4CE6-BC3A-3BD2E6CDEFE9'
set @m8Email = 'ahmed.hussein+dev9+1782714888354+70374-DONT_USE@equalexperts.com'

if not exists (select 1 from Users where UserId = @m8UserId)
    insert into Users (UserId, Email) values (@m8UserId, @m8Email)

if not exists (select 1 from Persons where Email = @m8Email)
    insert into Persons (FirstName, LastName, Email, Telephone, UserId)
    values ('Isabella', 'Grant', @m8Email, '07700900208',
        (select Id from Users where Email = @m8Email))

if not exists (select 1 from PersonOrganisationConnections where OrganisationId = @m8OrgId and PersonId = (select Id from Users where Email = @m8Email))
    insert into PersonOrganisationConnections (JobTitle, OrganisationId, OrganisationRoleId, PersonId, PersonRoleId)
    values ('Director', @m8OrgId, 1,
        (select Id from Users where Email = @m8Email), 1)

declare @m8ConnectionId int
set @m8ConnectionId = (select top 1 Id from PersonOrganisationConnections where OrganisationId = @m8OrgId and PersonId = (select Id from Users where Email = @m8Email))

if not exists (select 1 from Enrolments where ConnectionId = @m8ConnectionId)
    insert into Enrolments (ConnectionId, ServiceRoleId, EnrolmentStatusId)
    values (@m8ConnectionId, 1, 3)

if not exists (select 1 from OrganisationsConnections where FromOrganisationId = @m8OrgId and ToOrganisationId = @csNewOrgId)
    insert into OrganisationsConnections (FromOrganisationId, FromOrganisationRoleId, ToOrganisationId, ToOrganisationRoleId)
    values (@m8OrgId, 1, @csNewOrgId, 2)

declare @m8OrgConnectionId int
set @m8OrgConnectionId = (select top 1 Id from OrganisationsConnections where FromOrganisationId = @m8OrgId and ToOrganisationId = @csNewOrgId)

if not exists (select 1 from SelectedSchemes where OrganisationConnectionId = @m8OrgConnectionId and ComplianceSchemeId = @csNewSchemeId)
    insert into SelectedSchemes (OrganisationConnectionId, ComplianceSchemeId)
    values (@m8OrgConnectionId, @csNewSchemeId)

-- ============================================================
-- Member organisation 9 of 10: GREENFIELD DAIRY LTD
-- ============================================================
declare @m9OrgExternalId uniqueidentifier
set @m9OrgExternalId = '3AD56639-56C4-47B3-AECF-8290D022478E'

if not exists (select 1 from Organisations where ExternalId = @m9OrgExternalId)
    insert into Organisations (OrganisationTypeId, CompaniesHouseNumber, Name, TradingName, ValidatedWithCompaniesHouse, IsComplianceScheme, NationId, ExternalId)
    values (1, '11000009', 'GREENFIELD DAIRY LTD', '', 1, 0, 1, @m9OrgExternalId)

declare @m9OrgId int
set @m9OrgId = (select Id from Organisations where ExternalId = @m9OrgExternalId)

declare @m9UserId uniqueidentifier
declare @m9Email nvarchar(255)
set @m9UserId = '296C40CC-6694-4E42-95C3-DFD1C0F9692C'
set @m9Email = 'ahmed.hussein+dev9+1782714921449+05316-DONT_USE@equalexperts.com'

if not exists (select 1 from Users where UserId = @m9UserId)
    insert into Users (UserId, Email) values (@m9UserId, @m9Email)

if not exists (select 1 from Persons where Email = @m9Email)
    insert into Persons (FirstName, LastName, Email, Telephone, UserId)
    values ('Oliver', 'Marsh', @m9Email, '07700900209',
        (select Id from Users where Email = @m9Email))

if not exists (select 1 from PersonOrganisationConnections where OrganisationId = @m9OrgId and PersonId = (select Id from Users where Email = @m9Email))
    insert into PersonOrganisationConnections (JobTitle, OrganisationId, OrganisationRoleId, PersonId, PersonRoleId)
    values ('Director', @m9OrgId, 1,
        (select Id from Users where Email = @m9Email), 1)

declare @m9ConnectionId int
set @m9ConnectionId = (select top 1 Id from PersonOrganisationConnections where OrganisationId = @m9OrgId and PersonId = (select Id from Users where Email = @m9Email))

if not exists (select 1 from Enrolments where ConnectionId = @m9ConnectionId)
    insert into Enrolments (ConnectionId, ServiceRoleId, EnrolmentStatusId)
    values (@m9ConnectionId, 1, 3)

if not exists (select 1 from OrganisationsConnections where FromOrganisationId = @m9OrgId and ToOrganisationId = @csNewOrgId)
    insert into OrganisationsConnections (FromOrganisationId, FromOrganisationRoleId, ToOrganisationId, ToOrganisationRoleId)
    values (@m9OrgId, 1, @csNewOrgId, 2)

declare @m9OrgConnectionId int
set @m9OrgConnectionId = (select top 1 Id from OrganisationsConnections where FromOrganisationId = @m9OrgId and ToOrganisationId = @csNewOrgId)

if not exists (select 1 from SelectedSchemes where OrganisationConnectionId = @m9OrgConnectionId and ComplianceSchemeId = @csNewSchemeId)
    insert into SelectedSchemes (OrganisationConnectionId, ComplianceSchemeId)
    values (@m9OrgConnectionId, @csNewSchemeId)

-- ============================================================
-- Member organisation 10 of 10: STONEBRIDGE ELECTRONICS LTD
-- ============================================================
declare @m10OrgExternalId uniqueidentifier
set @m10OrgExternalId = '6C65994D-2144-49E7-8992-D87EA65C918E'

if not exists (select 1 from Organisations where ExternalId = @m10OrgExternalId)
    insert into Organisations (OrganisationTypeId, CompaniesHouseNumber, Name, TradingName, ValidatedWithCompaniesHouse, IsComplianceScheme, NationId, ExternalId)
    values (1, '11000010', 'STONEBRIDGE ELECTRONICS LTD', '', 1, 0, 1, @m10OrgExternalId)

declare @m10OrgId int
set @m10OrgId = (select Id from Organisations where ExternalId = @m10OrgExternalId)

declare @m10UserId uniqueidentifier
declare @m10Email nvarchar(255)
set @m10UserId = 'F3F0C069-B981-44CE-946C-484B943B763A'
set @m10Email = 'ahmed.hussein+dev9+1782715019923+87659-DONT_USE@equalexperts.com'

if not exists (select 1 from Users where UserId = @m10UserId)
    insert into Users (UserId, Email) values (@m10UserId, @m10Email)

if not exists (select 1 from Persons where Email = @m10Email)
    insert into Persons (FirstName, LastName, Email, Telephone, UserId)
    values ('Amelia', 'Doyle', @m10Email, '07700900210',
        (select Id from Users where Email = @m10Email))

if not exists (select 1 from PersonOrganisationConnections where OrganisationId = @m10OrgId and PersonId = (select Id from Users where Email = @m10Email))
    insert into PersonOrganisationConnections (JobTitle, OrganisationId, OrganisationRoleId, PersonId, PersonRoleId)
    values ('Director', @m10OrgId, 1,
        (select Id from Users where Email = @m10Email), 1)

declare @m10ConnectionId int
set @m10ConnectionId = (select top 1 Id from PersonOrganisationConnections where OrganisationId = @m10OrgId and PersonId = (select Id from Users where Email = @m10Email))

if not exists (select 1 from Enrolments where ConnectionId = @m10ConnectionId)
    insert into Enrolments (ConnectionId, ServiceRoleId, EnrolmentStatusId)
    values (@m10ConnectionId, 1, 3)

if not exists (select 1 from OrganisationsConnections where FromOrganisationId = @m10OrgId and ToOrganisationId = @csNewOrgId)
    insert into OrganisationsConnections (FromOrganisationId, FromOrganisationRoleId, ToOrganisationId, ToOrganisationRoleId)
    values (@m10OrgId, 1, @csNewOrgId, 2)

declare @m10OrgConnectionId int
set @m10OrgConnectionId = (select top 1 Id from OrganisationsConnections where FromOrganisationId = @m10OrgId and ToOrganisationId = @csNewOrgId)

if not exists (select 1 from SelectedSchemes where OrganisationConnectionId = @m10OrgConnectionId and ComplianceSchemeId = @csNewSchemeId)
    insert into SelectedSchemes (OrganisationConnectionId, ComplianceSchemeId)
    values (@m10OrgConnectionId, @csNewSchemeId)

-- ============================================================
-- 4 subsidiary companies: 2 attached to BRAMBLEWOOD PACKAGING LTD (member 1),
-- 2 attached to SILVERDALE FOODS LTD (member 2)
-- ============================================================

-- Subsidiary 1: BRAMBLEWOOD PACKAGING (NORTH) LTD, subsidiary of BRAMBLEWOOD PACKAGING LTD
declare @sub1ExternalId uniqueidentifier
set @sub1ExternalId = 'AE4E52DB-074F-4BBF-8A00-36C8EF9F226F'

if not exists (select 1 from Organisations where ExternalId = @sub1ExternalId)
    insert into Organisations (OrganisationTypeId, CompaniesHouseNumber, Name, TradingName, ValidatedWithCompaniesHouse, IsComplianceScheme, NationId, ExternalId)
    values (1, '11000011', 'BRAMBLEWOOD PACKAGING (NORTH) LTD', '', 1, 0, 1, @sub1ExternalId)

declare @sub1OrgId int
set @sub1OrgId = (select Id from Organisations where ExternalId = @sub1ExternalId)

if not exists (select 1 from OrganisationRelationships where FirstOrganisationId = @m1OrgId and SecondOrganisationId = @sub1OrgId)
    insert into OrganisationRelationships (FirstOrganisationId, SecondOrganisationId, OrganisationRelationshipTypeId, LastUpdatedById, LastUpdatedByOrganisationId)
    values (@m1OrgId, @sub1OrgId, 1, (select Id from Users where Email = 'system@dummy.com'), 1)

if not exists (select 1 from SubsidiaryOrganisations where OrganisationId = @sub1OrgId)
    insert into SubsidiaryOrganisations (OrganisationId, SubsidiaryId)
    values (@sub1OrgId, (select ReferenceNumber from Organisations where Id = @sub1OrgId))

-- Subsidiary 2: BRAMBLEWOOD PACKAGING (SOUTH) LTD, subsidiary of BRAMBLEWOOD PACKAGING LTD
declare @sub2ExternalId uniqueidentifier
set @sub2ExternalId = '8CF2EDC6-496A-4A2B-B54D-4676AADC86AE'

if not exists (select 1 from Organisations where ExternalId = @sub2ExternalId)
    insert into Organisations (OrganisationTypeId, CompaniesHouseNumber, Name, TradingName, ValidatedWithCompaniesHouse, IsComplianceScheme, NationId, ExternalId)
    values (1, '11000012', 'BRAMBLEWOOD PACKAGING (SOUTH) LTD', '', 1, 0, 1, @sub2ExternalId)

declare @sub2OrgId int
set @sub2OrgId = (select Id from Organisations where ExternalId = @sub2ExternalId)

if not exists (select 1 from OrganisationRelationships where FirstOrganisationId = @m1OrgId and SecondOrganisationId = @sub2OrgId)
    insert into OrganisationRelationships (FirstOrganisationId, SecondOrganisationId, OrganisationRelationshipTypeId, LastUpdatedById, LastUpdatedByOrganisationId)
    values (@m1OrgId, @sub2OrgId, 1, (select Id from Users where Email = 'system@dummy.com'), 1)

if not exists (select 1 from SubsidiaryOrganisations where OrganisationId = @sub2OrgId)
    insert into SubsidiaryOrganisations (OrganisationId, SubsidiaryId)
    values (@sub2OrgId, (select ReferenceNumber from Organisations where Id = @sub2OrgId))

-- Subsidiary 3: SILVERDALE FOODS DISTRIBUTION LTD, subsidiary of SILVERDALE FOODS LTD
declare @sub3ExternalId uniqueidentifier
set @sub3ExternalId = '60B825FA-939A-418C-ADE3-21451DFD2431'

if not exists (select 1 from Organisations where ExternalId = @sub3ExternalId)
    insert into Organisations (OrganisationTypeId, CompaniesHouseNumber, Name, TradingName, ValidatedWithCompaniesHouse, IsComplianceScheme, NationId, ExternalId)
    values (1, '11000013', 'SILVERDALE FOODS DISTRIBUTION LTD', '', 1, 0, 1, @sub3ExternalId)

declare @sub3OrgId int
set @sub3OrgId = (select Id from Organisations where ExternalId = @sub3ExternalId)

if not exists (select 1 from OrganisationRelationships where FirstOrganisationId = @m2OrgId and SecondOrganisationId = @sub3OrgId)
    insert into OrganisationRelationships (FirstOrganisationId, SecondOrganisationId, OrganisationRelationshipTypeId, LastUpdatedById, LastUpdatedByOrganisationId)
    values (@m2OrgId, @sub3OrgId, 1, (select Id from Users where Email = 'system@dummy.com'), 1)

if not exists (select 1 from SubsidiaryOrganisations where OrganisationId = @sub3OrgId)
    insert into SubsidiaryOrganisations (OrganisationId, SubsidiaryId)
    values (@sub3OrgId, (select ReferenceNumber from Organisations where Id = @sub3OrgId))

-- Subsidiary 4: SILVERDALE FOODS RETAIL LTD, subsidiary of SILVERDALE FOODS LTD
declare @sub4ExternalId uniqueidentifier
set @sub4ExternalId = 'F28905E3-6419-45BD-9256-EED4B49E8B9D'

if not exists (select 1 from Organisations where ExternalId = @sub4ExternalId)
    insert into Organisations (OrganisationTypeId, CompaniesHouseNumber, Name, TradingName, ValidatedWithCompaniesHouse, IsComplianceScheme, NationId, ExternalId)
    values (1, '11000014', 'SILVERDALE FOODS RETAIL LTD', '', 1, 0, 1, @sub4ExternalId)

declare @sub4OrgId int
set @sub4OrgId = (select Id from Organisations where ExternalId = @sub4ExternalId)

if not exists (select 1 from OrganisationRelationships where FirstOrganisationId = @m2OrgId and SecondOrganisationId = @sub4OrgId)
    insert into OrganisationRelationships (FirstOrganisationId, SecondOrganisationId, OrganisationRelationshipTypeId, LastUpdatedById, LastUpdatedByOrganisationId)
    values (@m2OrgId, @sub4OrgId, 1, (select Id from Users where Email = 'system@dummy.com'), 1)

if not exists (select 1 from SubsidiaryOrganisations where OrganisationId = @sub4OrgId)
    insert into SubsidiaryOrganisations (OrganisationId, SubsidiaryId)
    values (@sub4OrgId, (select ReferenceNumber from Organisations where Id = @sub4OrgId))

-- Regulator organisations (OrganisationTypeId 6 = "Regulators"), one per nation. Needed by
-- FacadeAccountCreation's RegulatorController/OrganisationService.GetRegulatorOrganisationByNationAsync,
-- which epr-packaging-frontend's resubmission "submit to regulator" journey calls (via
-- RegulatorService.SendRegulatorResubmissionEmail -> POST regulators/resubmission-notify/) to look
-- up which regulator organisation to notify - with none seeded, that lookup throws
-- "Could not retrieve Regulator Data for NationId:X" and 500s the whole submit action.
if not exists (select 1 from Organisations where ExternalId = N'A832837D-42A4-4F3B-966A-CFE95070A95A')
    insert into Organisations (OrganisationTypeId, Name, ValidatedWithCompaniesHouse, IsComplianceScheme, NationId, ExternalId)
    values (6, N'Environment Agency', 0, 0, 1, N'A832837D-42A4-4F3B-966A-CFE95070A95A')

if not exists (select 1 from Organisations where ExternalId = N'8CD213F5-3E3B-41D3-A933-1EFC134ED573')
    insert into Organisations (OrganisationTypeId, Name, ValidatedWithCompaniesHouse, IsComplianceScheme, NationId, ExternalId)
    values (6, N'Northern Ireland Environment Agency', 0, 0, 2, N'8CD213F5-3E3B-41D3-A933-1EFC134ED573')

if not exists (select 1 from Organisations where ExternalId = N'7F46CC8D-AEE8-46AC-A38C-9098F656B257')
    insert into Organisations (OrganisationTypeId, Name, ValidatedWithCompaniesHouse, IsComplianceScheme, NationId, ExternalId)
    values (6, N'Scottish Environment Protection Agency', 0, 0, 3, N'7F46CC8D-AEE8-46AC-A38C-9098F656B257')

if not exists (select 1 from Organisations where ExternalId = N'DC8A6533-031D-4D65-BF2F-45953CF05266')
    insert into Organisations (OrganisationTypeId, Name, ValidatedWithCompaniesHouse, IsComplianceScheme, NationId, ExternalId)
    values (6, N'Natural Resources Wales', 0, 0, 4, N'DC8A6533-031D-4D65-BF2F-45953CF05266')
