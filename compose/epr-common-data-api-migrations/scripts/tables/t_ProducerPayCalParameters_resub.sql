-- this table is not in source control, it has been taken from DEV Synapse

create table dbo.t_ProducerPayCalParameters_resub
(
    joiner_date                   nvarchar(4000),
    OrganisationExternalId        nvarchar(4000),
    OrganisationId                int,
    FileName                      nvarchar(4000),
    FileId                        nvarchar(4000),
    RegistrationSetId             nvarchar(4000),
    IsOnlineMarketPlace           bit,
    OrganisationSize              nvarchar(4000) not null,
    ProducerSize                  nvarchar(4000) not null,
    NationId                      int,
    NumberOfSubsidiaries          int not null,
    OnlineMarketPlaceSubsidiaries int not null,
    NumberOfLateSubsidiaries      int not null
)
