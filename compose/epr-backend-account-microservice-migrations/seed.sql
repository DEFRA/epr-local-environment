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
