declare @userId uniqueidentifier
declare @email nvarchar(255)
set @userId = '579C319D-D552-47A2-BF4C-5A125A3183BC'
set @email = 'test+17122025143216@ee.com'

insert into Users (UserId, Email) values (@userId, @email)

insert into Persons (FirstName, LastName, Email, Telephone, UserId) values ('First name', 'Last Name', @email, '07123456789', (select Id from Users where Email = @email))

-- this is used in seed.sql for service epr-prn-common-backend-migrations
declare @organisationExternalId uniqueidentifier
set @organisationExternalId = '94BFC917-B9B6-45D7-847B-E5F500BFE198'

insert into Organisations (OrganisationTypeId, CompaniesHouseNumber, Name, TradingName, ValidatedWithCompaniesHouse, IsComplianceScheme, NationId, ExternalId) values (1, '12345678', 'Organisation Name', 'Trading Name', 1, 1, 1, @organisationExternalId)

declare @organisationId int
set @organisationId = SCOPE_IDENTITY()

insert into PersonOrganisationConnections (JobTitle, OrganisationId, OrganisationRoleId, PersonId, PersonRoleId) values ('Director', @organisationId, 1, (select Id from Users where Email = @email), 1)

declare @connectionId int
set @connectionId = SCOPE_IDENTITY()

insert into Enrolments (ConnectionId, ServiceRoleId, EnrolmentStatusId) values (@connectionId, 1, 3)

-- this is used in seed.sql for service epr-prn-common-backend-migrations
declare @complianceSchemeExternalId uniqueidentifier
set @complianceSchemeExternalId = 'D93376E3-0681-46BE-AEB4-7450A2E784D8'

insert into ComplianceSchemes (Name, ExternalId, CompaniesHouseNumber, NationId) values ('Compliance Scheme Name', @complianceSchemeExternalId,'12345678', 1)
