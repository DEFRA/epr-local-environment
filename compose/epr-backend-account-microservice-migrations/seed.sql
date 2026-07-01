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

-- Regulator organisations (one per nation) + regulator admin users
declare @orgs table (Name nvarchar(255), NationId int, ExternalId uniqueidentifier)
insert into @orgs values
    ('Environment Agency',                     1, 'b480f515-dfd5-4a9c-8407-e9db9e00d6b0'),
    ('Northern Ireland Environment Agency',    2, '69f047b5-7355-4aef-9c21-8daf1ad577f8'),
    ('Scottish Environment Protection Agency', 3, '5724dc87-e950-49b5-b6c6-7eac70397d95'),
    ('Natural Resources Wales',                4, 'a52c17d0-4884-471c-97cb-b1089d2d08e9')

declare @users table (Oid uniqueidentifier, Email nvarchar(255), FirstName nvarchar(255), NationId int)
insert into @users values
    ('a586e22f-0df0-4a24-8048-ae7d0aabbbbc', 'eprqatest+RegulatorNation1@gmail.com', 'EA',   1),
    ('02524e4a-a69a-495f-a73b-39d96685289f', 'eprtest+RegulatorNation3@gmail.com',   'NIEA', 2),
    ('dd57f6ac-f9f2-4bbc-b557-a9fd1022fbd4', 'eprtest+RegulatorNation2@gmail.com',   'SEPA', 3),
    ('b5135434-f518-43e1-9613-65889c694f8b', 'eprqatest+RegulatorNation4@gmail.com', 'NRW',  4)

insert into Organisations (OrganisationTypeId, Name, ValidatedWithCompaniesHouse, IsComplianceScheme, NationId, ExternalId)
    select 6, o.Name, 0, 0, o.NationId, o.ExternalId from @orgs o
    where not exists (select 1 from Organisations existing where existing.ExternalId = o.ExternalId)

insert into Users (UserId, Email)
    select u.Oid, u.Email from @users u
    where not exists (select 1 from Users existing where existing.UserId = u.Oid)

insert into Persons (FirstName, LastName, Email, Telephone, UserId)
    select u.FirstName, 'Regulator', u.Email, '00441234560000', usr.Id
    from @users u join Users usr on usr.UserId = u.Oid
    where not exists (select 1 from Persons existing where existing.UserId = usr.Id)

insert into PersonOrganisationConnections (JobTitle, OrganisationId, OrganisationRoleId, PersonId, PersonRoleId)
    select 'Regulator', o.Id, 1, p.Id, 1
    from @users u
    join Users usr on usr.UserId = u.Oid
    join Persons p on p.UserId = usr.Id
    join Organisations o on o.OrganisationTypeId = 6 and o.NationId = u.NationId
    where not exists (select 1 from PersonOrganisationConnections existing where existing.PersonId = p.Id and existing.OrganisationId = o.Id)

-- Without this enrolment the FE's RegulatorBasicPolicyHandler rejects the user with a 403 at sign-in.
declare @serviceRoleRegulatorAdmin int = 4
declare @enrolmentStatusApproved int = 3

insert into Enrolments (ConnectionId, ServiceRoleId, EnrolmentStatusId)
    select c.Id, @serviceRoleRegulatorAdmin, @enrolmentStatusApproved
    from @users u
    join Users usr on usr.UserId = u.Oid
    join Persons p on p.UserId = usr.Id
    join Organisations o on o.OrganisationTypeId = 6 and o.NationId = u.NationId
    join PersonOrganisationConnections c on c.PersonId = p.Id and c.OrganisationId = o.Id
    where not exists (select 1 from Enrolments existing where existing.ConnectionId = c.Id)
