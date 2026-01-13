insert into Users (UserId, Email) values ('579C319D-D552-47A2-BF4C-5A125A3183BC', 'test+17122025143216@ee.com')

insert into Persons (FirstName, LastName, Email, Telephone, UserId) values ('DP First name','Last Name','test+17122025143216@ee.com','07123456789',(select Id from Users where Email = 'test+17122025143216@ee.com'))

insert into Organisations (OrganisationTypeId, CompaniesHouseNumber, Name, TradingName, ValidatedWithCompaniesHouse, IsComplianceScheme, NationId) values (1, '12345678', 'Org Name', 'Trading Name', 1, 1, 1)

insert into PersonOrganisationConnections (JobTitle, OrganisationId, OrganisationRoleId, PersonId, PersonRoleId) values ('Director', (select Id from Organisations where Name = 'Org Name'), 1, (select Id from Users where Email = 'test+17122025143216@ee.com'), 1)

insert into Enrolments (ConnectionId, ServiceRoleId, EnrolmentStatusId) values ((select Id from PersonOrganisationConnections where JobTitle = 'Director'), 1, 3)

insert into ComplianceSchemes (Name, CompaniesHouseNumber, NationId) values ('Org Name', '12345678', 1)
