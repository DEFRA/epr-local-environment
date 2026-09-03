using Microsoft.Azure.Cosmos;

var endpoint = Environment.GetEnvironmentVariable("COSMOS_ENDPOINT")
    ?? throw new InvalidOperationException("COSMOS_ENDPOINT is not configured");
var key = Environment.GetEnvironmentVariable("COSMOS_KEY")
    ?? throw new InvalidOperationException("COSMOS_KEY is not configured");
var databaseName = Environment.GetEnvironmentVariable("COSMOS_DATABASE")
    ?? throw new InvalidOperationException("COSMOS_DATABASE is not configured");

var handler = new HttpClientHandler
{
    ServerCertificateCustomValidationCallback = HttpClientHandler.DangerousAcceptAnyServerCertificateValidator,
};

var clientOptions = new CosmosClientOptions
{
    ConnectionMode = ConnectionMode.Gateway,
    HttpClientFactory = () => new HttpClient(handler),
};

using var client = new CosmosClient(endpoint, key, clientOptions);

var database = await client.CreateDatabaseIfNotExistsAsync(databaseName);
Console.WriteLine($"Database ready: {database.Database.Id}");

// epr-pom-api-submission-status's SubmissionContext maps these containers via
// HasPartitionKey + ToJsonProperty, so the physical partition key path must match
// the renamed JSON property, not the C# property name (ValidationEventId is the
// exception - it isn't renamed, so its JSON property name is unchanged).
var containers = new (string Name, string PartitionKeyPath)[]
{
    ("Submissions", "/SubmissionId"),
    ("SubmissionEvents", "/SubmissionEventId"),
    ("ProducerValidationErrors", "/ProducerValidationErrorId"),
    ("ProducerValidationWarnings", "/ValidationEventId"),
};

foreach (var (name, partitionKeyPath) in containers)
{
    var container = await database.Database.CreateContainerIfNotExistsAsync(name, partitionKeyPath);
    Console.WriteLine($"Container ready: {container.Container.Id} (partition key {partitionKeyPath})");
}

await SeedNorthbridgeRegistrationsAsync(database.Database);
await SeedNorthbridgePackagingDataAsync(database.Database);
await SeedPopQuestRegistrationsAsync(database.Database);
await SeedPopQuestPackagingDataAsync(database.Database);

Console.WriteLine("Cosmos DB emulator initialisation complete.");

// Northbridge Compliance Solutions Ltd (CHN 11000000): 2025/2026 accepted registration
// submissions. 2025 is a single combined submission covering all 10 members (5 Large + 5
// Small); 2026 is still split into a Large-producer submission and a Small-producer submission
// (RegistrationJourney is submission-level, so the two bands can't share a submission there).
// Mirrors the same SubmissionId/FileId/SubmissionEventId GUIDs and field values seeded into
// the Synapse mirror in synapse-sqlserver-restore/seed/baseline.sql, so both stores describe the
// same underlying events.
static async Task SeedNorthbridgeRegistrationsAsync(Database database)
{
    const string csApprovedPersonUserId = "94BFD894-8F64-4F8D-9975-259D08786C2B";
    const string northbridgeOrgId = "0BB650B9-125E-4D64-B1D0-06B9E167B2D4";
    const string northbridgeSchemeId = "CAC58048-62A1-4419-9BEE-4B386454D776";
    const string regulatorUserId = "a586e22f-0df0-4a24-8048-ae7d0aabbbbc";
    const string uploadContainerName = "registration-upload-container";

    var submissions = new[]
    {
        new RegistrationSubmissionSeed(
            SubmissionId: "D05A39BD-EC9B-4D4E-AC19-AC4A7A981DE2",
            FileId: "BDA483FE-A1AD-44AB-A3AA-75AF4DE72820",
            BlobName: "6688ED9B-AC4C-4550-B834-5698F3523597",
            AntivirusCheckEventId: "BE793186-B178-46CC-B0A9-36CCFED9B082",
            AntivirusResultEventId: "6A27E408-C054-4F68-8019-4D1DB75F49CC",
            ValidationEventId: "B3114E98-2450-4D59-BD8D-5E8495ED6279",
            SubmittedEventId: "B517E551-8306-4402-AB7A-A72E31F2F048",
            FeePaymentEventId: "BFC79410-3C34-4D3A-AED1-EC050F1337FB",
            AppSubmittedEventId: "EB0CB92D-6AB8-43DA-859C-204945F8902E",
            DecisionEventId: "FA603971-DC12-47FB-AC4E-CFDEF649EAA1",
            FileName: "Northbridge_CompanyDetails_2025.csv",
            SubmissionPeriod: "January to December 2025",
            RegistrationJourney: null,
            MemberCount: 14,
            AppReferenceNumber: "NBCS-2025-L-APP-0001",
            RegistrationReferenceNumber: "NBCS-2025-L-REG-0001",
            PaidAmount: "8500.00",
            AntivirusCheckCreated: "2025-04-01T09:15:00.0000000Z",
            AntivirusResultCreated: "2025-04-01T09:17:32.0000000Z",
            ValidationCreated: "2025-04-01T09:18:10.0000000Z",
            SubmittedCreated: "2025-04-01T09:20:00.0000000Z",
            FeePaymentCreated: "2025-04-01T09:25:44.0000000Z",
            AppSubmittedCreated: "2025-04-01T09:26:05.0000000Z",
            DecisionCreated: "2025-04-19T11:00:00.0000000Z"),
        new RegistrationSubmissionSeed(
            SubmissionId: "601A176C-B17B-4B6B-B672-D0C61A44E733",
            FileId: "D88098E5-500C-48EB-A494-9E81D417A2C9",
            BlobName: "7113CC97-A799-48E4-8A5E-F214532C32E4",
            AntivirusCheckEventId: "F15D51D3-C684-4F7F-A3B1-21C58195F251",
            AntivirusResultEventId: "92CEB81A-2C9A-4633-877F-22FECE5EC216",
            ValidationEventId: "1432D871-DC42-4220-8EA5-C0466AE5F438",
            SubmittedEventId: "2B7CCDB4-CBD1-43AA-B01E-FF2089B835BB",
            FeePaymentEventId: "673B6DCD-02FB-4DD6-8987-50AF57F75D16",
            AppSubmittedEventId: "224831B8-50C4-4C66-A31F-60EBC9C1DE75",
            DecisionEventId: "04505BAD-0FA2-4E16-9A1C-C9719DE6A29D",
            FileName: "Northbridge_CompanyDetails_2026_Large.csv",
            SubmissionPeriod: "January to December 2026",
            RegistrationJourney: null,
            MemberCount: 9,
            AppReferenceNumber: "PEPR11000007226P1",
            RegistrationReferenceNumber: "NBCS-2026-L-REG-0001",
            PaidAmount: "8925.00",
            AntivirusCheckCreated: "2026-04-08T09:00:00.0000000Z",
            AntivirusResultCreated: "2026-04-08T09:02:11.0000000Z",
            ValidationCreated: "2026-04-08T09:03:00.0000000Z",
            SubmittedCreated: "2026-04-08T09:05:00.0000000Z",
            FeePaymentCreated: "2026-04-08T09:09:30.0000000Z",
            AppSubmittedCreated: "2026-04-08T09:09:52.0000000Z",
            DecisionCreated: "2026-04-24T10:45:00.0000000Z"),
        new RegistrationSubmissionSeed(
            SubmissionId: "ECE0880A-B713-42D4-A018-92FD3D8053C6",
            FileId: "520EAFD0-C6E1-4B88-B353-BFD5650E93E1",
            BlobName: "B1DF2A8B-5435-47D8-946A-07B5155B3CA4",
            AntivirusCheckEventId: "E07799B0-0229-49A2-91D3-003F753DD589",
            AntivirusResultEventId: "950A71F9-2461-45E5-83B8-FC995973D836",
            ValidationEventId: "E95BA52D-3A86-4FA5-9CD1-03420E8D1208",
            SubmittedEventId: "A7D6F738-C7FD-45CC-8E49-FE3A2B59DA73",
            FeePaymentEventId: "5687F7F9-AC45-4369-ADBA-A0A0540A7758",
            AppSubmittedEventId: "C6521622-5849-45F4-BA8C-06A16BE5BDF5",
            DecisionEventId: "99D71946-8F40-437B-8264-93A86FA7E540",
            FileName: "Northbridge_CompanyDetails_2026_Small.csv",
            SubmissionPeriod: "January to December 2026",
            RegistrationJourney: "CsoSmallProducer",
            MemberCount: 5,
            AppReferenceNumber: "PEPR11000007226P1S",
            RegistrationReferenceNumber: "NBCS-2026-S-REG-0001",
            PaidAmount: "2625.00",
            AntivirusCheckCreated: "2026-04-09T09:30:00.0000000Z",
            AntivirusResultCreated: "2026-04-09T09:32:09.0000000Z",
            ValidationCreated: "2026-04-09T09:33:00.0000000Z",
            SubmittedCreated: "2026-04-09T09:35:00.0000000Z",
            FeePaymentCreated: "2026-04-09T09:39:21.0000000Z",
            AppSubmittedCreated: "2026-04-09T09:39:45.0000000Z",
            DecisionCreated: "2026-04-25T11:15:00.0000000Z"),
    };

    var submissionsContainer = database.GetContainer("Submissions");
    var eventsContainer = database.GetContainer("SubmissionEvents");

    foreach (var s in submissions)
    {
        // EF Core's Cosmos provider always serializes Guid-typed properties via Guid.ToString()
        // (lowercase "D" format) both when writing documents and when binding LINQ query
        // parameters - e.g. `x.OrganisationId == request.OrganisationId` compiles to a
        // case-sensitive Cosmos string comparison against a lowercase parameter value. Every
        // Guid-shaped field below must be lowercased or real queries (like the submission
        // history screen) silently return zero rows despite the IDs being "the same".
        await submissionsContainer.UpsertItemAsync(new Dictionary<string, object?>
        {
            ["id"] = s.SubmissionId.ToLowerInvariant(),
            ["SubmissionId"] = s.SubmissionId.ToLowerInvariant(),
            ["SubmissionType"] = "Registration",
            ["SubmissionPeriod"] = s.SubmissionPeriod,
            ["DataSourceType"] = "File",
            ["OrganisationId"] = northbridgeOrgId.ToLowerInvariant(),
            ["UserId"] = csApprovedPersonUserId.ToLowerInvariant(),
            ["IsSubmitted"] = true,
            ["IsResubmission"] = false,
            ["ComplianceSchemeId"] = northbridgeSchemeId.ToLowerInvariant(),
            ["AppReferenceNumber"] = s.AppReferenceNumber,
            ["Created"] = s.AntivirusCheckCreated,
            ["RegistrationJourney"] = s.RegistrationJourney,
        }, new PartitionKey(s.SubmissionId.ToLowerInvariant()));

        Task UpsertEvent(string rawEventId, string type, string created, Dictionary<string, object?> extra)
        {
            var eventId = rawEventId.ToLowerInvariant();
            var doc = new Dictionary<string, object?>
            {
                ["id"] = $"{type}|{eventId}",
                ["SubmissionEventId"] = eventId,
                ["SubmissionId"] = s.SubmissionId.ToLowerInvariant(),
                ["Type"] = type,
                ["UserId"] = csApprovedPersonUserId.ToLowerInvariant(),
                ["Created"] = created,
                ["Errors"] = Array.Empty<string>(),
                ["BlobContainerName"] = uploadContainerName,
            };
            foreach (var (key, value) in extra)
            {
                doc[key] = value;
            }

            return eventsContainer.UpsertItemAsync(doc, new PartitionKey(eventId));
        }

        await UpsertEvent(s.AntivirusCheckEventId, "AntivirusCheck", s.AntivirusCheckCreated, new()
        {
            ["FileId"] = s.FileId.ToLowerInvariant(),
            ["FileType"] = "CompanyDetails",
            ["FileName"] = s.FileName,
            ["RegistrationSetId"] = null,
        });

        await UpsertEvent(s.AntivirusResultEventId, "AntivirusResult", s.AntivirusResultCreated, new()
        {
            ["FileId"] = s.FileId.ToLowerInvariant(),
            ["BlobName"] = s.BlobName.ToLowerInvariant(),
            ["AntivirusScanResult"] = "Success",
            ["AntivirusScanTrigger"] = "Upload",
            ["RequiresRowValidation"] = false,
        });

        // BlobName must match the AntivirusResult event above:
        // RegistrationSubmissionEventHelper.SetValidationEvents looks up this event by BlobName
        // (GetRegistrationValidationEventByBlobName), and when isSubmitted is true it dereferences
        // the result unguarded - an unmatched/missing BlobName here produces a NullReferenceException
        // on every GET for this submission, not just a missing-data gap.
        await UpsertEvent(s.ValidationEventId, "Registration", s.ValidationCreated, new()
        {
            ["IsValid"] = true,
            ["ErrorCount"] = 0,
            ["WarningCount"] = 0,
            ["RequiresBrandsFile"] = false,
            ["RequiresPartnershipsFile"] = false,
            ["HasMaxRowErrors"] = false,
            ["RowErrorCount"] = 0,
            ["OrganisationMemberCount"] = s.MemberCount,
            ["BlobName"] = s.BlobName.ToLowerInvariant(),
        });

        await UpsertEvent(s.SubmittedEventId, "Submitted", s.SubmittedCreated, new()
        {
            ["FileId"] = s.FileId.ToLowerInvariant(),
            ["SubmittedBy"] = "Olivia Bennett",
            ["IsResubmission"] = false,
            ["RegistrationJourney"] = s.RegistrationJourney,
        });

        await UpsertEvent(s.FeePaymentEventId, "RegistrationFeePayment", s.FeePaymentCreated, new()
        {
            ["ApplicationReferenceNumber"] = s.AppReferenceNumber,
            // Frontend's RegistrationApplicationStatusCalculator.IsRegistrationFeePaid only treats
            // PaymentMethod (not PaymentStatus) as evidence of payment, and only for these 4 exact
            // values - see FrontendSchemeRegistration.UI/Helpers/RegistrationApplicationStatusCalculator.cs.
            ["PaymentMethod"] = "PayOnline",
            ["PaymentStatus"] = "Paid",
            ["PaidAmount"] = s.PaidAmount,
            ["IsResubmission"] = false,
            ["RegistrationJourney"] = s.RegistrationJourney,
        });

        await UpsertEvent(s.AppSubmittedEventId, "RegistrationApplicationSubmitted", s.AppSubmittedCreated, new()
        {
            ["ApplicationReferenceNumber"] = s.AppReferenceNumber,
            ["SubmissionDate"] = s.AppSubmittedCreated,
            ["IsResubmission"] = false,
            ["RegistrationJourney"] = s.RegistrationJourney,
        });

        await UpsertEvent(s.DecisionEventId, "RegulatorRegistrationDecision", s.DecisionCreated, new()
        {
            ["FileId"] = s.FileId.ToLowerInvariant(),
            ["Decision"] = "Accepted",
            ["RegistrationReferenceNumber"] = s.RegistrationReferenceNumber,
            ["DecisionDate"] = s.DecisionCreated,
            ["Comments"] = "Registration approved",
            ["UserId"] = regulatorUserId.ToLowerInvariant(),
        });

        Console.WriteLine($"Seeded registration submission {s.SubmissionId} ({s.FileName})");
    }
}

// Northbridge Compliance Solutions Ltd (CHN 11000000): Packaging Data (POM) submissions - a
// distinct data source/journey from Registration above (SubmissionType "Producer", half-year
// SubmissionPeriod, no RegistrationJourney field). 3 submissions: 2025 H1 (Large only, Accepted),
// 2025 H2 (mixed Large+Small, Accepted, then a resubmission already in progress - new file
// uploaded and fee viewed, but not yet paid or finally submitted), 2026 H1 (Large only, Rejected).
// Each submission's shape genuinely differs (decision outcome, resubmission tail on 2025 H2 only),
// so the event chains are written out explicitly per submission rather than forced through a
// shared record shape. Mirrors the same GUIDs/values seeded into the Synapse mirror in
// synapse-sqlserver-restore/seed/baseline.sql, so both stores describe the same underlying events.
static async Task SeedNorthbridgePackagingDataAsync(Database database)
{
    const string csApprovedPersonUserId = "94BFD894-8F64-4F8D-9975-259D08786C2B";
    const string northbridgeOrgId = "0BB650B9-125E-4D64-B1D0-06B9E167B2D4";
    const string northbridgeSchemeId = "CAC58048-62A1-4419-9BEE-4B386454D776";
    const string regulatorUserId = "a586e22f-0df0-4a24-8048-ae7d0aabbbbc";
    const string uploadContainerName = "pom-upload-container-recyclers";

    var submissionsContainer = database.GetContainer("Submissions");
    var eventsContainer = database.GetContainer("SubmissionEvents");

    // Created must be set: EF Core's Submission entity declares it non-nullable, and the real
    // SubmissionsPeriodGetQueryHandler (backing GetSubmissionIdsAsync, which
    // IsAnySubmissionAcceptedForDataPeriod depends on) filters "x.Created != null" - a Cosmos
    // document missing this property entirely evaluates to undefined against that filter, not
    // true, so the submission silently drops out of the result set even though everything else
    // about it is correct.
    Task UpsertSubmission(string submissionId, string submissionPeriod, bool isResubmission, string created) =>
        submissionsContainer.UpsertItemAsync(new Dictionary<string, object?>
        {
            ["id"] = submissionId.ToLowerInvariant(),
            ["SubmissionId"] = submissionId.ToLowerInvariant(),
            ["SubmissionType"] = "Producer",
            ["SubmissionPeriod"] = submissionPeriod,
            ["DataSourceType"] = "File",
            ["OrganisationId"] = northbridgeOrgId.ToLowerInvariant(),
            ["UserId"] = csApprovedPersonUserId.ToLowerInvariant(),
            ["IsSubmitted"] = true,
            ["IsResubmission"] = isResubmission,
            ["ComplianceSchemeId"] = northbridgeSchemeId.ToLowerInvariant(),
            ["Created"] = created,
        }, new PartitionKey(submissionId.ToLowerInvariant()));

    Task UpsertEvent(string submissionId, string eventId, string type, string created, Dictionary<string, object?> extra)
    {
        var lowerEventId = eventId.ToLowerInvariant();
        var doc = new Dictionary<string, object?>
        {
            ["id"] = $"{type}|{lowerEventId}",
            ["SubmissionEventId"] = lowerEventId,
            ["SubmissionId"] = submissionId.ToLowerInvariant(),
            ["Type"] = type,
            ["UserId"] = csApprovedPersonUserId.ToLowerInvariant(),
            ["Created"] = created,
            ["Errors"] = Array.Empty<string>(),
        };
        foreach (var (key, value) in extra)
        {
            doc[key] = value;
        }

        return eventsContainer.UpsertItemAsync(doc, new PartitionKey(lowerEventId));
    }

    // ---- 2025 H1: Large only, Accepted ----
    const string h1SubmissionId = "8447509F-A90E-4436-BB34-06CDDE1C7AB9";
    const string h1FileId = "99A60710-11CC-45A7-BCEF-170E9CDDB56E";
    const string h1BlobName = "5EE9C2CA-0100-488A-BE21-7A7F6546C913";

    await UpsertSubmission(h1SubmissionId, "January to June 2025", isResubmission: false, created: "2025-07-08T09:10:00.0000000Z");
    await UpsertEvent(h1SubmissionId, "574412FE-4AC1-4CB3-A1B6-BC5DBA4ED684", "AntivirusCheck", "2025-07-08T09:10:00.0000000Z", new()
    {
        ["FileId"] = h1FileId.ToLowerInvariant(),
        ["FileType"] = "Pom",
        ["FileName"] = "Northbridge_Pom_2025H1.csv",
        ["BlobContainerName"] = uploadContainerName,
    });
    await UpsertEvent(h1SubmissionId, "A4C9868A-F462-4EA3-8FB3-A54C0D3EFA59", "AntivirusResult", "2025-07-08T09:12:22.0000000Z", new()
    {
        ["FileId"] = h1FileId.ToLowerInvariant(),
        ["BlobName"] = h1BlobName.ToLowerInvariant(),
        ["AntivirusScanResult"] = "Success",
        ["AntivirusScanTrigger"] = "Upload",
        ["RequiresRowValidation"] = false,
    });
    await UpsertEvent(h1SubmissionId, "00CD4BAE-1C48-47BE-B94B-5ED6CFF975AD", "CheckSplitter", "2025-07-08T09:13:05.0000000Z", new()
    {
        ["IsValid"] = true,
        ["ErrorCount"] = 0,
        ["WarningCount"] = 0,
        ["DataCount"] = 1,
        ["BlobName"] = h1BlobName.ToLowerInvariant(),
    });
    await UpsertEvent(h1SubmissionId, "7E4E74E1-ED6D-4EC1-8870-979D2DB676C0", "ProducerValidation", "2025-07-08T09:13:40.0000000Z", new()
    {
        ["IsValid"] = true,
        ["ErrorCount"] = 0,
        ["WarningCount"] = 0,
        ["BlobName"] = h1BlobName.ToLowerInvariant(),
    });
    await UpsertEvent(h1SubmissionId, "A7B56495-9992-4388-B408-CFED1351BD35", "Submitted", "2025-07-08T09:15:00.0000000Z", new()
    {
        ["FileId"] = h1FileId.ToLowerInvariant(),
        ["SubmittedBy"] = "Olivia Bennett",
        ["IsResubmission"] = false,
        ["SubmissionPeriod"] = "January to June 2025",
    });
    await UpsertEvent(h1SubmissionId, "BB76CD87-F1C9-4DCA-AE3F-57909E6FB7B4", "RegulatorPoMDecision", "2025-07-22T10:30:00.0000000Z", new()
    {
        ["FileId"] = h1FileId.ToLowerInvariant(),
        ["Decision"] = "Accepted",
        ["RegistrationReferenceNumber"] = "NBCS-2025H1-POM-DEC-0001",
        ["DecisionDate"] = "2025-07-22T10:30:00.0000000Z",
        ["Comments"] = "Packaging data accepted",
        ["IsResubmissionRequired"] = false,
        ["UserId"] = regulatorUserId.ToLowerInvariant(),
    });
    Console.WriteLine($"Seeded packaging data submission {h1SubmissionId} (2025 H1, Accepted)");

    // ---- 2025 H2: mixed Large+Small, Accepted, then a resubmission already in progress ----
    const string h2SubmissionId = "C18BF17E-DEC1-434E-A5CA-A37D9811C72D";
    const string h2FileId = "DC607430-00DC-40FE-92E9-4B6A6BB491C1";
    const string h2BlobName = "2918E82C-BD28-45A3-8C14-5FE2AF464849";
    const string h2ResubFileId = "A5372C4B-EF7D-4FBD-B665-02805694C071";
    const string h2ResubBlobName = "0DB4F56A-E98C-4B34-B020-9C67E2ADBD5C";

    // Submission-level IsResubmission=true: this submission is currently mid-resubmission.
    await UpsertSubmission(h2SubmissionId, "July to December 2025", isResubmission: true, created: "2025-10-06T10:00:00.0000000Z");

    // Original submission, accepted by the regulator.
    await UpsertEvent(h2SubmissionId, "521652F1-3856-41E7-8B7D-D223BB5DF4F3", "AntivirusCheck", "2025-10-06T10:00:00.0000000Z", new()
    {
        ["FileId"] = h2FileId.ToLowerInvariant(),
        ["FileType"] = "Pom",
        ["FileName"] = "Northbridge_Pom_2025H2.csv",
        ["BlobContainerName"] = uploadContainerName,
    });
    await UpsertEvent(h2SubmissionId, "263410B7-57EA-4BA8-80F4-05C087B2A00A", "AntivirusResult", "2025-10-06T10:02:15.0000000Z", new()
    {
        ["FileId"] = h2FileId.ToLowerInvariant(),
        ["BlobName"] = h2BlobName.ToLowerInvariant(),
        ["AntivirusScanResult"] = "Success",
        ["AntivirusScanTrigger"] = "Upload",
        ["RequiresRowValidation"] = false,
    });
    await UpsertEvent(h2SubmissionId, "556BDC2B-2D72-4E99-B1C8-B836AFCD8BDF", "CheckSplitter", "2025-10-06T10:03:00.0000000Z", new()
    {
        ["IsValid"] = true,
        ["ErrorCount"] = 0,
        ["WarningCount"] = 0,
        ["DataCount"] = 1,
        ["BlobName"] = h2BlobName.ToLowerInvariant(),
    });
    await UpsertEvent(h2SubmissionId, "FD2ADFC1-96AB-4D94-A4ED-57E27E7180A2", "ProducerValidation", "2025-10-06T10:03:45.0000000Z", new()
    {
        ["IsValid"] = true,
        ["ErrorCount"] = 0,
        ["WarningCount"] = 0,
        ["BlobName"] = h2BlobName.ToLowerInvariant(),
    });
    await UpsertEvent(h2SubmissionId, "BAA4E703-6B3A-4D75-B9D5-FC6C465F3F1C", "Submitted", "2025-10-06T10:05:00.0000000Z", new()
    {
        ["FileId"] = h2FileId.ToLowerInvariant(),
        ["SubmittedBy"] = "Olivia Bennett",
        ["IsResubmission"] = false,
        ["SubmissionPeriod"] = "July to December 2025",
    });
    await UpsertEvent(h2SubmissionId, "EA054576-5331-4BAD-9856-B51C27EAD755", "RegulatorPoMDecision", "2025-10-20T11:00:00.0000000Z", new()
    {
        ["FileId"] = h2FileId.ToLowerInvariant(),
        ["Decision"] = "Accepted",
        ["RegistrationReferenceNumber"] = "NBCS-2025H2-POM-DEC-0001",
        ["DecisionDate"] = "2025-10-20T11:00:00.0000000Z",
        ["Comments"] = "Packaging data accepted",
        ["IsResubmissionRequired"] = false,
        ["UserId"] = regulatorUserId.ToLowerInvariant(),
    });

    // Resubmission in progress: reference number issued, corrected file uploaded and validated,
    // fee viewed but deliberately not yet paid and not yet finally submitted to the regulator.
    await UpsertEvent(h2SubmissionId, "94DDEB72-0233-45DA-8A1B-BB6E826AC618", "PackagingResubmissionReferenceNumberCreated", "2026-01-15T09:00:00.0000000Z", new()
    {
        ["PackagingResubmissionReferenceNumber"] = "NBCS-2025H2-POM-RESUB-0001",
    });
    await UpsertEvent(h2SubmissionId, "EF82DC4E-3812-4EDB-9A7E-1F020B267D05", "AntivirusCheck", "2026-01-15T09:30:00.0000000Z", new()
    {
        ["FileId"] = h2ResubFileId.ToLowerInvariant(),
        ["FileType"] = "Pom",
        ["FileName"] = "Northbridge_Pom_2025H2_Resubmission.csv",
        ["BlobContainerName"] = uploadContainerName,
    });
    await UpsertEvent(h2SubmissionId, "93BEBD40-10BB-45E9-AF30-AF52FBE39C5C", "AntivirusResult", "2026-01-15T09:32:10.0000000Z", new()
    {
        ["FileId"] = h2ResubFileId.ToLowerInvariant(),
        ["BlobName"] = h2ResubBlobName.ToLowerInvariant(),
        ["AntivirusScanResult"] = "Success",
        ["AntivirusScanTrigger"] = "Upload",
        ["RequiresRowValidation"] = false,
    });
    await UpsertEvent(h2SubmissionId, "8A3783E4-9180-4D06-B097-8295E82C772B", "CheckSplitter", "2026-01-15T09:33:00.0000000Z", new()
    {
        ["IsValid"] = true,
        ["ErrorCount"] = 0,
        ["WarningCount"] = 0,
        ["DataCount"] = 1,
        ["BlobName"] = h2ResubBlobName.ToLowerInvariant(),
    });
    await UpsertEvent(h2SubmissionId, "8A5C6578-474C-44AD-AC97-BC2892CBA5F8", "ProducerValidation", "2026-01-15T09:33:50.0000000Z", new()
    {
        ["IsValid"] = true,
        ["ErrorCount"] = 0,
        ["WarningCount"] = 0,
        ["BlobName"] = h2ResubBlobName.ToLowerInvariant(),
    });
    await UpsertEvent(h2SubmissionId, "313BA353-A541-4A9D-9E3F-B4ED0A301FB9", "Submitted", "2026-01-15T09:35:00.0000000Z", new()
    {
        ["FileId"] = h2ResubFileId.ToLowerInvariant(),
        ["SubmittedBy"] = "Olivia Bennett",
        ["IsResubmission"] = true,
        ["SubmissionPeriod"] = "July to December 2025",
    });
    // Fee has been viewed (ready to pay) - deliberately no PackagingDataResubmissionFeePayment
    // event yet, and no PackagingResubmissionApplicationSubmitted event: payment and the final
    // "submit application" step haven't happened.
    await UpsertEvent(h2SubmissionId, "E1CBF577-9AD7-4314-B92D-C62786FC9486", "PackagingResubmissionFeeViewed", "2026-01-15T09:40:00.0000000Z", new()
    {
        ["FileId"] = h2ResubFileId.ToLowerInvariant(),
        ["IsPackagingResubmissionFeeViewed"] = true,
    });
    Console.WriteLine($"Seeded packaging data submission {h2SubmissionId} (2025 H2, Accepted + resubmission in progress)");

    // ---- 2026 H1: Large only. Two cycles under the same SubmissionId: an original file that
    // was Accepted, then - months later - a corrected file the compliance scheme resubmitted
    // that the regulator went on to Reject. This is deliberate, not incidental: the packaging
    // frontend's own resubmission routing (FileUploadSubLandingController.HandleSubmissionBasedOnStatus
    // -> SubmissionService.IsAnySubmissionAcceptedForDataPeriod) only shows the "Resubmit packaging
    // data" intermediate page (UploadNewFileToSubmitController) for a submission whose OWN event
    // history contains at least one Accepted decision - a submission that has only ever been
    // Rejected, with no prior Accepted cycle, instead falls through to the plain first-time
    // upload flow (FileUploadController), which is the wrong page for a rejected resubmission.
    // The second cycle is modelled as a COMPLETED fee-based resubmission: reference number, corrected
    // file, fee viewed, fee paid and the declaration, followed by the regulator's Rejected decision.
    // Note the routing consequence - because the declaration sets ResubmissionApplicationSubmitted,
    // FileUploadSubLandingController.HandleSubmissionBasedOnStatus now sends this submission to
    // PackagingDataResubmissionController.ResubmissionTaskList rather than to
    // UploadNewFileToSubmitController. That is the correct destination for a resubmission that has
    // already been declared; the 2025 H2 submissions remain the in-progress example.
    const string h1_2026SubmissionId = "84FA8B3B-ACF0-4FAE-8B70-27137AF5F24C";

    // Cycle A: original file, Accepted.
    const string h1_2026FileIdA = "68DD58D5-B0A5-4B67-95D5-47FD7946F5B7";
    const string h1_2026BlobNameA = "62D90EC6-0A28-439F-A09B-DF79EE919F39";

    // Cycle B: corrected file submitted later, Rejected - this is the current/latest state, and
    // the file the "File already submitted" table on the intermediate page shows as needing to
    // be replaced.
    const string h1_2026FileIdB = "559469D2-FBEB-4DC6-B670-CA2AC9E2F319";
    const string h1_2026BlobNameB = "B52AAEE6-5C64-4C55-B194-6140488F6063";

    await UpsertSubmission(h1_2026SubmissionId, "January to June 2026", isResubmission: true, created: "2026-01-08T09:00:00.0000000Z");

    await UpsertEvent(h1_2026SubmissionId, "B7997346-D063-4E51-8244-E9904D608ED0", "AntivirusCheck", "2026-01-08T09:00:00.0000000Z", new()
    {
        ["FileId"] = h1_2026FileIdA.ToLowerInvariant(),
        ["FileType"] = "Pom",
        ["FileName"] = "Northbridge_Pom_2026H1.csv",
        ["BlobContainerName"] = uploadContainerName,
    });
    await UpsertEvent(h1_2026SubmissionId, "3C6247D4-9983-48BD-A5E7-32260BF45998", "AntivirusResult", "2026-01-08T09:02:10.0000000Z", new()
    {
        ["FileId"] = h1_2026FileIdA.ToLowerInvariant(),
        ["BlobName"] = h1_2026BlobNameA.ToLowerInvariant(),
        ["AntivirusScanResult"] = "Success",
        ["AntivirusScanTrigger"] = "Upload",
        ["RequiresRowValidation"] = false,
    });
    await UpsertEvent(h1_2026SubmissionId, "789E16BD-BF4F-4EE6-AB55-398F8FBA4F83", "CheckSplitter", "2026-01-08T09:03:00.0000000Z", new()
    {
        ["IsValid"] = true,
        ["ErrorCount"] = 0,
        ["WarningCount"] = 0,
        ["DataCount"] = 1,
        ["BlobName"] = h1_2026BlobNameA.ToLowerInvariant(),
    });
    await UpsertEvent(h1_2026SubmissionId, "5E60C8D7-2E39-4948-AE91-7AC9B3E5ABCA", "ProducerValidation", "2026-01-08T09:03:40.0000000Z", new()
    {
        ["IsValid"] = true,
        ["ErrorCount"] = 0,
        ["WarningCount"] = 0,
        ["BlobName"] = h1_2026BlobNameA.ToLowerInvariant(),
    });
    await UpsertEvent(h1_2026SubmissionId, "9AA5ADCD-D038-4A0F-849A-C74BB345C28E", "Submitted", "2026-01-08T09:05:00.0000000Z", new()
    {
        ["FileId"] = h1_2026FileIdA.ToLowerInvariant(),
        ["SubmittedBy"] = "Olivia Bennett",
        ["IsResubmission"] = false,
        ["SubmissionPeriod"] = "January to June 2026",
    });
    await UpsertEvent(h1_2026SubmissionId, "74827CA2-CA30-4BC2-9299-9402AEA27577", "RegulatorPoMDecision", "2026-01-22T10:30:00.0000000Z", new()
    {
        ["FileId"] = h1_2026FileIdA.ToLowerInvariant(),
        ["Decision"] = "Accepted",
        ["RegistrationReferenceNumber"] = "NBCS-2026H1-POM-DEC-0001",
        ["DecisionDate"] = "2026-01-22T10:30:00.0000000Z",
        ["Comments"] = "Packaging data accepted",
        ["IsResubmissionRequired"] = false,
        ["UserId"] = regulatorUserId.ToLowerInvariant(),
    });

    // The fee-based resubmission cycle. The reference number has to predate the corrected file:
    // GetPackagingResubmissionApplicationDetailsQueryHandler treats an upload older than the cycle's
    // reference number as belonging to the previous cycle and reports the cycle as NotStarted.
    await UpsertEvent(h1_2026SubmissionId, "E9175738-3FAA-4832-A66A-2BEB9147CFDA", "PackagingResubmissionReferenceNumberCreated", "2026-07-06T09:00:00.0000000Z", new()
    {
        ["PackagingResubmissionReferenceNumber"] = "NBCS-2026H1-POM-RESUB-0001",
    });
    await UpsertEvent(h1_2026SubmissionId, "E2AC17CC-1EE2-47B9-B5AC-49AAC2284FE4", "AntivirusCheck", "2026-07-07T09:00:00.0000000Z", new()
    {
        ["FileId"] = h1_2026FileIdB.ToLowerInvariant(),
        ["FileType"] = "Pom",
        ["FileName"] = "Northbridge_Pom_2026H1_Corrected.csv",
        ["BlobContainerName"] = uploadContainerName,
    });
    await UpsertEvent(h1_2026SubmissionId, "EE853F07-FFB1-41E8-A3ED-2290156322FB", "AntivirusResult", "2026-07-07T09:02:10.0000000Z", new()
    {
        ["FileId"] = h1_2026FileIdB.ToLowerInvariant(),
        ["BlobName"] = h1_2026BlobNameB.ToLowerInvariant(),
        ["AntivirusScanResult"] = "Success",
        ["AntivirusScanTrigger"] = "Upload",
        ["RequiresRowValidation"] = false,
    });
    await UpsertEvent(h1_2026SubmissionId, "B824A29E-56A7-4D66-98B5-E6472DD922D0", "CheckSplitter", "2026-07-07T09:03:00.0000000Z", new()
    {
        ["IsValid"] = true,
        ["ErrorCount"] = 0,
        ["WarningCount"] = 0,
        ["DataCount"] = 1,
        ["BlobName"] = h1_2026BlobNameB.ToLowerInvariant(),
    });
    await UpsertEvent(h1_2026SubmissionId, "AB84FB18-CE80-42E5-BEFD-A7E321C19440", "ProducerValidation", "2026-07-07T09:03:40.0000000Z", new()
    {
        ["IsValid"] = true,
        ["ErrorCount"] = 0,
        ["WarningCount"] = 0,
        ["BlobName"] = h1_2026BlobNameB.ToLowerInvariant(),
    });
    await UpsertEvent(h1_2026SubmissionId, "EF2060D4-8901-43DF-A334-68A8F6C29812", "Submitted", "2026-07-07T09:05:00.0000000Z", new()
    {
        ["FileId"] = h1_2026FileIdB.ToLowerInvariant(),
        ["SubmittedBy"] = "Olivia Bennett",
        ["IsResubmission"] = true,
        ["SubmissionPeriod"] = "January to June 2026",
    });
    // Fee viewed, paid and declared. All three must postdate the Submitted event above: the handler
    // only reports the fee and declaration fields when their events are newer than the last submit.
    await UpsertEvent(h1_2026SubmissionId, "8604F180-B5E6-49BE-B942-93DB6BA86DB1", "PackagingResubmissionFeeViewed", "2026-07-07T09:10:00.0000000Z", new()
    {
        ["FileId"] = h1_2026FileIdB.ToLowerInvariant(),
        ["IsPackagingResubmissionFeeViewed"] = true,
    });
    // PaymentMethod drives the frontend's ResubmissionFeePaid check, which accepts only
    // PayByPhone/PayOnline/PayByBankTransfer; the handler additionally ignores "Offline" outright.
    // 2560.00 = the 2026 compliance-scheme resubmission base fee (512.00) x 5 changed members,
    // matching ComplianceSchemeResubmissionService (baseFee * MemberCount) against the member count
    // dbo.v_CSO_Pom_Resubmitted_ByCSID computes for this cycle.
    await UpsertEvent(h1_2026SubmissionId, "AC6BE508-09A0-48E0-81EE-64ADA2056D07", "PackagingDataResubmissionFeePayment", "2026-07-07T09:20:00.0000000Z", new()
    {
        ["FileId"] = h1_2026FileIdB.ToLowerInvariant(),
        ["ReferenceNumber"] = "NBCS-2026H1-POM-RESUB-0001",
        ["PaymentMethod"] = "PayByBankTransfer",
        ["PaymentStatus"] = "Paid",
        ["PaidAmount"] = "2560.00",
    });
    // The declaration closes the cycle: with no later reference number the handler stops reporting
    // an open cycle, which is what makes this a completed resubmission rather than one in progress.
    await UpsertEvent(h1_2026SubmissionId, "B49F4888-47DA-4D84-940C-E06B0AF3ADC4", "PackagingResubmissionApplicationSubmitted", "2026-07-07T09:25:00.0000000Z", new()
    {
        ["FileId"] = h1_2026FileIdB.ToLowerInvariant(),
        ["IsResubmitted"] = true,
        ["SubmittedBy"] = "Olivia Bennett",
        ["SubmissionDate"] = "2026-07-07T09:25:00.0000000Z",
        ["Comments"] = "Corrected packaging data resubmitted for January to June 2026",
    });
    await UpsertEvent(h1_2026SubmissionId, "FAD8ABE3-72C1-46AA-9CD1-2BD513672EDB", "RegulatorPoMDecision", "2026-07-21T10:15:00.0000000Z", new()
    {
        ["FileId"] = h1_2026FileIdB.ToLowerInvariant(),
        ["Decision"] = "Rejected",
        ["RegistrationReferenceNumber"] = "NBCS-2026H1-POM-DEC-0002",
        ["DecisionDate"] = "2026-07-21T10:15:00.0000000Z",
        ["Comments"] = "Packaging data rejected: the corrected material weight figures do not reconcile with the originally accepted submission for this period",
        ["IsResubmissionRequired"] = true,
        ["UserId"] = regulatorUserId.ToLowerInvariant(),
    });
    Console.WriteLine($"Seeded packaging data submission {h1_2026SubmissionId} (2026 H1, Accepted then Rejected on resubmission)");

    // ---- 2024-P1 (January to June 2024): Large producers only. First submission Accepted, then a resubmission that was also Accepted. ----
    const string nb2024p1SubmissionId = "D5D5D5D5-5555-4555-8555-000000000001";
    await UpsertSubmission(nb2024p1SubmissionId, "January to June 2024", isResubmission: true, created: "2024-08-05T09:00:00.0000000Z");
    await UpsertEvent(nb2024p1SubmissionId, "D5D5D5D5-DDDD-4DDD-8DDD-000000000001", "AntivirusCheck", "2024-08-05T09:00:00.0000000Z", new()
    {
        ["FileId"] = "d5d5d5d5-aaaa-4aaa-8aaa-000000000001",
        ["FileType"] = "Pom",
        ["FileName"] = "Northbridge_Pom_2024P1.csv",
        ["RegistrationSetId"] = null,
    });
    await UpsertEvent(nb2024p1SubmissionId, "D5D5D5D5-DDDD-4DDD-8DDD-000000000002", "AntivirusResult", "2024-08-05T09:02:10.0000000Z", new()
    {
        ["FileId"] = "d5d5d5d5-aaaa-4aaa-8aaa-000000000001",
        ["BlobName"] = "d5d5d5d5-bbbb-4bbb-8bbb-000000000001",
        ["AntivirusScanResult"] = "Success",
        ["RequiresRowValidation"] = false,
    });
    await UpsertEvent(nb2024p1SubmissionId, "D5D5D5D5-DDDD-4DDD-8DDD-000000000003", "CheckSplitter", "2024-08-05T09:03:00.0000000Z", new()
    {
        ["BlobName"] = "d5d5d5d5-bbbb-4bbb-8bbb-000000000001",
        ["DataCount"] = 1,
        ["ErrorCount"] = 0,
        ["WarningCount"] = 0,
    });
    await UpsertEvent(nb2024p1SubmissionId, "D5D5D5D5-DDDD-4DDD-8DDD-000000000004", "ProducerValidation", "2024-08-05T09:03:40.0000000Z", new()
    {
        ["BlobName"] = "d5d5d5d5-bbbb-4bbb-8bbb-000000000001",
        ["IsValid"] = true,
        ["ErrorCount"] = 0,
        ["WarningCount"] = 0,
    });
    await UpsertEvent(nb2024p1SubmissionId, "D5D5D5D5-DDDD-4DDD-8DDD-000000000005", "Submitted", "2024-08-05T09:05:00.0000000Z", new()
    {
        ["FileId"] = "d5d5d5d5-aaaa-4aaa-8aaa-000000000001",
        ["SubmittedBy"] = "Olivia Bennett",
        ["IsResubmission"] = false,
        ["SubmissionPeriod"] = "January to June 2024",
    });
    await UpsertEvent(nb2024p1SubmissionId, "D5D5D5D5-DDDD-4DDD-8DDD-000000000006", "RegulatorPoMDecision", "2024-08-19T10:30:00.0000000Z", new()
    {
        ["FileId"] = "d5d5d5d5-aaaa-4aaa-8aaa-000000000001",
        ["Decision"] = "Accepted",
        ["RegistrationReferenceNumber"] = "NBCS-2024P1-POM-DEC-0001",
        ["DecisionDate"] = "2024-08-19T10:30:00.0000000Z",
        ["Comments"] = "Packaging data accepted",
        ["IsResubmissionRequired"] = false,
        ["UserId"] = regulatorUserId.ToLowerInvariant(),
    });
    await UpsertEvent(nb2024p1SubmissionId, "D5D5D5D5-DDDD-4DDD-8DDD-000000000007", "PackagingResubmissionReferenceNumberCreated", "2024-09-09T09:00:00.0000000Z", new()
    {
        ["PackagingResubmissionReferenceNumber"] = "NBCS-2024P1-POM-RESUB-0001",
    });
    await UpsertEvent(nb2024p1SubmissionId, "D5D5D5D5-DDDD-4DDD-8DDD-000000000008", "AntivirusCheck", "2024-09-10T09:00:00.0000000Z", new()
    {
        ["FileId"] = "d5d5d5d5-aaaa-4aaa-8aaa-000000000002",
        ["FileType"] = "Pom",
        ["FileName"] = "Northbridge_Pom_2024P1_Resubmission.csv",
        ["RegistrationSetId"] = null,
    });
    await UpsertEvent(nb2024p1SubmissionId, "D5D5D5D5-DDDD-4DDD-8DDD-000000000009", "AntivirusResult", "2024-09-10T09:02:10.0000000Z", new()
    {
        ["FileId"] = "d5d5d5d5-aaaa-4aaa-8aaa-000000000002",
        ["BlobName"] = "d5d5d5d5-bbbb-4bbb-8bbb-000000000002",
        ["AntivirusScanResult"] = "Success",
        ["RequiresRowValidation"] = false,
    });
    await UpsertEvent(nb2024p1SubmissionId, "D5D5D5D5-DDDD-4DDD-8DDD-000000000010", "CheckSplitter", "2024-09-10T09:03:00.0000000Z", new()
    {
        ["BlobName"] = "d5d5d5d5-bbbb-4bbb-8bbb-000000000002",
        ["DataCount"] = 1,
        ["ErrorCount"] = 0,
        ["WarningCount"] = 0,
    });
    await UpsertEvent(nb2024p1SubmissionId, "D5D5D5D5-DDDD-4DDD-8DDD-000000000011", "ProducerValidation", "2024-09-10T09:03:40.0000000Z", new()
    {
        ["BlobName"] = "d5d5d5d5-bbbb-4bbb-8bbb-000000000002",
        ["IsValid"] = true,
        ["ErrorCount"] = 0,
        ["WarningCount"] = 0,
    });
    await UpsertEvent(nb2024p1SubmissionId, "D5D5D5D5-DDDD-4DDD-8DDD-000000000012", "Submitted", "2024-09-10T09:05:00.0000000Z", new()
    {
        ["FileId"] = "d5d5d5d5-aaaa-4aaa-8aaa-000000000002",
        ["SubmittedBy"] = "Olivia Bennett",
        ["IsResubmission"] = true,
        ["SubmissionPeriod"] = "January to June 2024",
    });
    await UpsertEvent(nb2024p1SubmissionId, "D5D5D5D5-DDDD-4DDD-8DDD-000000000013", "RegulatorPoMDecision", "2024-09-24T10:30:00.0000000Z", new()
    {
        ["FileId"] = "d5d5d5d5-aaaa-4aaa-8aaa-000000000002",
        ["Decision"] = "Accepted",
        ["RegistrationReferenceNumber"] = "NBCS-2024P1-POM-DEC-0002",
        ["DecisionDate"] = "2024-09-24T10:30:00.0000000Z",
        ["Comments"] = "Packaging data accepted",
        ["IsResubmissionRequired"] = false,
        ["UserId"] = regulatorUserId.ToLowerInvariant(),
    });
    await UpsertEvent(nb2024p1SubmissionId, "D5D5D5D5-DDDD-4DDD-8DDD-000000000014", "PackagingResubmissionFeeViewed", "2024-09-10T09:10:00.0000000Z", new()
    {
        ["FileId"] = "d5d5d5d5-aaaa-4aaa-8aaa-000000000002",
        ["IsPackagingResubmissionFeeViewed"] = true,
    });
    await UpsertEvent(nb2024p1SubmissionId, "D5D5D5D5-DDDD-4DDD-8DDD-000000000015", "PackagingDataResubmissionFeePayment", "2024-09-10T09:20:00.0000000Z", new()
    {
        ["FileId"] = "d5d5d5d5-aaaa-4aaa-8aaa-000000000002",
        ["ReferenceNumber"] = "NBCS-2024P1-POM-RESUB-0001",
        ["PaymentMethod"] = "PayByBankTransfer",
        ["PaymentStatus"] = "Paid",
        ["PaidAmount"] = "2150.00",
    });
    await UpsertEvent(nb2024p1SubmissionId, "D5D5D5D5-DDDD-4DDD-8DDD-000000000016", "PackagingResubmissionApplicationSubmitted", "2024-09-10T09:25:00.0000000Z", new()
    {
        ["FileId"] = "d5d5d5d5-aaaa-4aaa-8aaa-000000000002",
        ["IsResubmitted"] = true,
        ["SubmittedBy"] = "Olivia Bennett",
        ["SubmissionDate"] = "2024-09-10T09:25:00.0000000Z",
        ["Comments"] = "Corrected packaging data resubmitted for January to June 2024",
    });
    Console.WriteLine($"Seeded packaging data submission {nb2024p1SubmissionId} (2024-P1, Accepted, then resubmission Accepted)");

    // ---- 2024-P4 (July to December 2024): Large producers only. First submission Rejected; no resubmission cycle. ----
    const string nb2024p4SubmissionId = "D6D6D6D6-5555-4555-8555-000000000001";
    await UpsertSubmission(nb2024p4SubmissionId, "July to December 2024", isResubmission: false, created: "2025-02-10T09:00:00.0000000Z");
    await UpsertEvent(nb2024p4SubmissionId, "D6D6D6D6-DDDD-4DDD-8DDD-000000000001", "AntivirusCheck", "2025-02-10T09:00:00.0000000Z", new()
    {
        ["FileId"] = "d6d6d6d6-aaaa-4aaa-8aaa-000000000001",
        ["FileType"] = "Pom",
        ["FileName"] = "Northbridge_Pom_2024P4.csv",
        ["RegistrationSetId"] = null,
    });
    await UpsertEvent(nb2024p4SubmissionId, "D6D6D6D6-DDDD-4DDD-8DDD-000000000002", "AntivirusResult", "2025-02-10T09:02:10.0000000Z", new()
    {
        ["FileId"] = "d6d6d6d6-aaaa-4aaa-8aaa-000000000001",
        ["BlobName"] = "d6d6d6d6-bbbb-4bbb-8bbb-000000000001",
        ["AntivirusScanResult"] = "Success",
        ["RequiresRowValidation"] = false,
    });
    await UpsertEvent(nb2024p4SubmissionId, "D6D6D6D6-DDDD-4DDD-8DDD-000000000003", "CheckSplitter", "2025-02-10T09:03:00.0000000Z", new()
    {
        ["BlobName"] = "d6d6d6d6-bbbb-4bbb-8bbb-000000000001",
        ["DataCount"] = 1,
        ["ErrorCount"] = 0,
        ["WarningCount"] = 0,
    });
    await UpsertEvent(nb2024p4SubmissionId, "D6D6D6D6-DDDD-4DDD-8DDD-000000000004", "ProducerValidation", "2025-02-10T09:03:40.0000000Z", new()
    {
        ["BlobName"] = "d6d6d6d6-bbbb-4bbb-8bbb-000000000001",
        ["IsValid"] = true,
        ["ErrorCount"] = 0,
        ["WarningCount"] = 0,
    });
    await UpsertEvent(nb2024p4SubmissionId, "D6D6D6D6-DDDD-4DDD-8DDD-000000000005", "Submitted", "2025-02-10T09:05:00.0000000Z", new()
    {
        ["FileId"] = "d6d6d6d6-aaaa-4aaa-8aaa-000000000001",
        ["SubmittedBy"] = "Olivia Bennett",
        ["IsResubmission"] = false,
        ["SubmissionPeriod"] = "July to December 2024",
    });
    await UpsertEvent(nb2024p4SubmissionId, "D6D6D6D6-DDDD-4DDD-8DDD-000000000006", "RegulatorPoMDecision", "2025-02-24T10:30:00.0000000Z", new()
    {
        ["FileId"] = "d6d6d6d6-aaaa-4aaa-8aaa-000000000001",
        ["Decision"] = "Rejected",
        ["RegistrationReferenceNumber"] = "NBCS-2024P4-POM-DEC-0001",
        ["DecisionDate"] = "2025-02-24T10:30:00.0000000Z",
        ["Comments"] = "Packaging data rejected: the reported tonnages could not be reconciled with the supporting evidence for this period",
        ["IsResubmissionRequired"] = true,
        ["UserId"] = regulatorUserId.ToLowerInvariant(),
    });
    Console.WriteLine($"Seeded packaging data submission {nb2024p4SubmissionId} (2024-P4, Rejected)");
}

// POP QUEST LTD (CHN 17121895): the Direct Producer equivalent of the Northbridge seeds above.
// The shapes are deliberately the same - the differences that matter for a direct producer are
// that no ComplianceSchemeId is set anywhere, RegistrationJourney stays null, and the
// "members" behind the data are the producer itself plus its 2 subsidiaries rather than scheme
// members. Mirrors the same GUIDs seeded into the Synapse replica in
// synapse-sqlserver-restore/seed/baseline.sql and uploaded to Azurite by compose.yml's azurite-init.
static async Task SeedPopQuestRegistrationsAsync(Database database)
{
    const string approvedPersonUserId = "79D0DEAB-C22D-4C30-8082-508FF8DC1BD7";
    const string popQuestOrgId = "E2316C5E-D434-41DA-8274-494DC0762D20";
    const string regulatorUserId = "a586e22f-0df0-4a24-8048-ae7d0aabbbbc";
    const string uploadContainerName = "registration-upload-container";

    var submissionsContainer = database.GetContainer("Submissions");
    var eventsContainer = database.GetContainer("SubmissionEvents");

    var submissions = new[]
    {
        new PopQuestRegistrationSeed(
            SubmissionId: "F2A3B4C5-D6E7-4F8A-8B9C-0D1E2F3A4B56",
            FileId: "A3B4C5D6-E7F8-4A9B-8C0D-1E2F3A4B5C67",
            BlobName: "B4C5D6E7-F8A9-4B0C-8D1E-2F3A4B5C6D78",
            FileName: "PopQuest_CompanyDetails_2025.csv",
            SubmissionPeriod: "January to December 2025",
            AppReferenceNumber: "PQL-2025-APP-0001",
            RegistrationReferenceNumber: "PQL-2025-REG-0001",
            PaidAmount: "2600.00",
            EventIdPrefix: "D3D3D3D3-DDDD-4DDD-8DDD",
            Day: "2025-04-01",
            DecisionDay: "2025-04-19"),
        new PopQuestRegistrationSeed(
            SubmissionId: "C5D6E7F8-A9B0-4C1D-8E2F-3A4B5C6D7E89",
            FileId: "D6E7F8A9-B0C1-4D2E-8F3A-4B5C6D7E8F90",
            BlobName: "E7F8A9B0-C1D2-4E3F-8A4B-5C6D7E8F9A01",
            FileName: "PopQuest_CompanyDetails_2026.csv",
            SubmissionPeriod: "January to December 2026",
            AppReferenceNumber: "PEPR16528226P1",
            RegistrationReferenceNumber: "PQL-2026-REG-0001",
            PaidAmount: "2750.00",
            EventIdPrefix: "D4D4D4D4-DDDD-4DDD-8DDD",
            Day: "2026-04-01",
            DecisionDay: "2026-04-18"),
    };

    foreach (var s in submissions)
    {
        // Every Guid-shaped value is lowercased for the same reason as the Northbridge seeds -
        // EF Core's Cosmos provider binds LINQ query parameters as lowercase strings and the
        // comparison is case-sensitive.
        await submissionsContainer.UpsertItemAsync(new Dictionary<string, object?>
        {
            ["id"] = s.SubmissionId.ToLowerInvariant(),
            ["SubmissionId"] = s.SubmissionId.ToLowerInvariant(),
            ["SubmissionType"] = "Registration",
            ["SubmissionPeriod"] = s.SubmissionPeriod,
            ["DataSourceType"] = "File",
            ["OrganisationId"] = popQuestOrgId.ToLowerInvariant(),
            ["UserId"] = approvedPersonUserId.ToLowerInvariant(),
            ["IsSubmitted"] = true,
            ["IsResubmission"] = false,
            // No ComplianceSchemeId - this is a direct producer, not a scheme member.
            ["AppReferenceNumber"] = s.AppReferenceNumber,
            ["Created"] = $"{s.Day}T09:15:00.0000000Z",
            ["RegistrationJourney"] = null,
        }, new PartitionKey(s.SubmissionId.ToLowerInvariant()));

        Task UpsertEvent(int seq, string type, string created, Dictionary<string, object?> extra)
        {
            var eventId = $"{s.EventIdPrefix}-{seq:D12}".ToLowerInvariant();
            var doc = new Dictionary<string, object?>
            {
                ["id"] = $"{type}|{eventId}",
                ["SubmissionEventId"] = eventId,
                ["SubmissionId"] = s.SubmissionId.ToLowerInvariant(),
                ["Type"] = type,
                ["UserId"] = approvedPersonUserId.ToLowerInvariant(),
                ["Created"] = created,
                ["Errors"] = Array.Empty<string>(),
                ["BlobContainerName"] = uploadContainerName,
            };
            foreach (var (key, value) in extra)
            {
                doc[key] = value;
            }

            return eventsContainer.UpsertItemAsync(doc, new PartitionKey(eventId));
        }

        await UpsertEvent(1, "AntivirusCheck", $"{s.Day}T09:15:00.0000000Z", new()
        {
            ["FileId"] = s.FileId.ToLowerInvariant(),
            ["FileType"] = "CompanyDetails",
            ["FileName"] = s.FileName,
            ["RegistrationSetId"] = null,
        });

        await UpsertEvent(2, "AntivirusResult", $"{s.Day}T09:17:32.0000000Z", new()
        {
            ["FileId"] = s.FileId.ToLowerInvariant(),
            ["BlobName"] = s.BlobName.ToLowerInvariant(),
            ["AntivirusScanResult"] = "Success",
            ["AntivirusScanTrigger"] = "Upload",
            ["RequiresRowValidation"] = false,
        });

        // BlobName must match the AntivirusResult event above - see the note on the Northbridge
        // equivalent: GetRegistrationValidationEventByBlobName is dereferenced unguarded.
        await UpsertEvent(3, "Registration", $"{s.Day}T09:18:10.0000000Z", new()
        {
            ["IsValid"] = true,
            ["ErrorCount"] = 0,
            ["WarningCount"] = 0,
            ["RequiresBrandsFile"] = false,
            ["RequiresPartnershipsFile"] = false,
            ["HasMaxRowErrors"] = false,
            ["RowErrorCount"] = 0,
            // The producer itself plus its 2 subsidiaries.
            ["OrganisationMemberCount"] = 3,
            ["BlobName"] = s.BlobName.ToLowerInvariant(),
        });

        await UpsertEvent(4, "Submitted", $"{s.Day}T09:20:00.0000000Z", new()
        {
            ["FileId"] = s.FileId.ToLowerInvariant(),
            ["SubmittedBy"] = "Olivia Reed",
            ["IsResubmission"] = false,
            ["RegistrationJourney"] = null,
        });

        await UpsertEvent(5, "RegistrationFeePayment", $"{s.Day}T09:25:44.0000000Z", new()
        {
            ["ApplicationReferenceNumber"] = s.AppReferenceNumber,
            ["PaymentMethod"] = "PayOnline",
            ["PaymentStatus"] = "Paid",
            ["PaidAmount"] = s.PaidAmount,
            ["IsResubmission"] = false,
            ["RegistrationJourney"] = null,
        });

        await UpsertEvent(6, "RegistrationApplicationSubmitted", $"{s.Day}T09:26:05.0000000Z", new()
        {
            ["ApplicationReferenceNumber"] = s.AppReferenceNumber,
            ["SubmissionDate"] = $"{s.Day}T09:26:05.0000000Z",
            ["IsResubmission"] = false,
            ["RegistrationJourney"] = null,
        });

        await UpsertEvent(7, "RegulatorRegistrationDecision", $"{s.DecisionDay}T11:00:00.0000000Z", new()
        {
            ["FileId"] = s.FileId.ToLowerInvariant(),
            ["Decision"] = "Accepted",
            ["RegistrationReferenceNumber"] = s.RegistrationReferenceNumber,
            ["DecisionDate"] = $"{s.DecisionDay}T11:00:00.0000000Z",
            ["Comments"] = "Registration approved",
            ["UserId"] = regulatorUserId.ToLowerInvariant(),
        });

        Console.WriteLine($"Seeded POP QUEST registration submission {s.SubmissionId} ({s.FileName})");
    }
}

// POP QUEST LTD Packaging Data (POM) submissions: 2025 H1 (Accepted), 2025 H2 (Accepted then a
// resubmission already in progress - new file uploaded and fee viewed, but not paid or finally
// submitted), 2026 H1 (Accepted then a corrected file Rejected). The 2025 H1/H2 Synapse rows
// already existed in seed.sql before this was added; these documents give them their missing
// Cosmos counterpart so they actually surface in the frontend.
static async Task SeedPopQuestPackagingDataAsync(Database database)
{
    const string approvedPersonUserId = "79D0DEAB-C22D-4C30-8082-508FF8DC1BD7";
    const string popQuestOrgId = "E2316C5E-D434-41DA-8274-494DC0762D20";
    const string regulatorUserId = "a586e22f-0df0-4a24-8048-ae7d0aabbbbc";
    const string uploadContainerName = "pom-upload-container-recyclers";

    var submissionsContainer = database.GetContainer("Submissions");
    var eventsContainer = database.GetContainer("SubmissionEvents");

    Task UpsertSubmission(string submissionId, string submissionPeriod, bool isResubmission, string created) =>
        submissionsContainer.UpsertItemAsync(new Dictionary<string, object?>
        {
            ["id"] = submissionId.ToLowerInvariant(),
            ["SubmissionId"] = submissionId.ToLowerInvariant(),
            ["SubmissionType"] = "Producer",
            ["SubmissionPeriod"] = submissionPeriod,
            ["DataSourceType"] = "File",
            ["OrganisationId"] = popQuestOrgId.ToLowerInvariant(),
            ["UserId"] = approvedPersonUserId.ToLowerInvariant(),
            ["IsSubmitted"] = true,
            ["IsResubmission"] = isResubmission,
            // No ComplianceSchemeId - direct producer.
            ["Created"] = created,
        }, new PartitionKey(submissionId.ToLowerInvariant()));

    Task UpsertEvent(string submissionId, string eventId, string type, string created, Dictionary<string, object?> extra)
    {
        var lowerEventId = eventId.ToLowerInvariant();
        var doc = new Dictionary<string, object?>
        {
            ["id"] = $"{type}|{lowerEventId}",
            ["SubmissionEventId"] = lowerEventId,
            ["SubmissionId"] = submissionId.ToLowerInvariant(),
            ["Type"] = type,
            ["UserId"] = approvedPersonUserId.ToLowerInvariant(),
            ["Created"] = created,
            ["Errors"] = Array.Empty<string>(),
        };
        foreach (var (key, value) in extra)
        {
            doc[key] = value;
        }

        return eventsContainer.UpsertItemAsync(doc, new PartitionKey(lowerEventId));
    }

    // Emits the standard accepted POM chain for one uploaded file:
    // AntivirusCheck -> AntivirusResult -> CheckSplitter -> ProducerValidation -> Submitted.
    // The regulator decision is left to the caller since it differs per submission.
    // eventIds must supply exactly those 5 ids, in that order - they are passed in rather than
    // generated so the pre-existing 2025 H1/H2 events can reuse the GUIDs already committed to
    // synapse-sqlserver-restore/seed/baseline.sql instead of inventing a second set.
    async Task UpsertFileCycle(string submissionId, string[] eventIds, string fileId,
        string blobName, string fileName, string period, string day, bool isResubmission)
    {
        string Id(int index) => eventIds[index];

        await UpsertEvent(submissionId, Id(0), "AntivirusCheck", $"{day}T09:00:00.0000000Z", new()
        {
            ["FileId"] = fileId.ToLowerInvariant(),
            ["FileType"] = "Pom",
            ["FileName"] = fileName,
            ["BlobContainerName"] = uploadContainerName,
        });
        await UpsertEvent(submissionId, Id(1), "AntivirusResult", $"{day}T09:02:10.0000000Z", new()
        {
            ["FileId"] = fileId.ToLowerInvariant(),
            ["BlobName"] = blobName.ToLowerInvariant(),
            ["AntivirusScanResult"] = "Success",
            ["AntivirusScanTrigger"] = "Upload",
            ["RequiresRowValidation"] = false,
        });
        await UpsertEvent(submissionId, Id(2), "CheckSplitter", $"{day}T09:03:00.0000000Z", new()
        {
            ["IsValid"] = true,
            ["ErrorCount"] = 0,
            ["WarningCount"] = 0,
            ["DataCount"] = 1,
            ["BlobName"] = blobName.ToLowerInvariant(),
        });
        await UpsertEvent(submissionId, Id(3), "ProducerValidation", $"{day}T09:03:40.0000000Z", new()
        {
            ["IsValid"] = true,
            ["ErrorCount"] = 0,
            ["WarningCount"] = 0,
            ["BlobName"] = blobName.ToLowerInvariant(),
        });
        await UpsertEvent(submissionId, Id(4), "Submitted", $"{day}T09:05:00.0000000Z", new()
        {
            ["FileId"] = fileId.ToLowerInvariant(),
            ["SubmittedBy"] = "Olivia Reed",
            ["IsResubmission"] = isResubmission,
            ["SubmissionPeriod"] = period,
        });
    }

    // ---- 2025 H1: Accepted ----
    const string h1SubmissionId = "C3D4E5F6-A7B8-4C9D-0E1F-2A3B4C5D6E7F";
    const string h1FileId = "D4E5F6A7-B8C9-4D0E-1F2A-3B4C5D6E7F80";
    const string h1BlobName = "A1B2C3D4-E5F6-4A7B-8C9D-0E1F2A3B4C5D";
    // a1/a2/a3/a4 already exist in seed.sql's DP block; a5/a6 are the CheckSplitter and
    // ProducerValidation events that block was missing and which seed.sql now also adds.
    string[] h1EventIds =
    [
        "a1a1a1a1-1111-4111-8111-111111111111", "a2a2a2a2-2222-4222-8222-222222222222",
        "a5a5a5a5-5555-4555-8555-555555555555", "a6a6a6a6-6666-4666-8666-666666666666",
        "a3a3a3a3-3333-4333-8333-333333333333",
    ];

    await UpsertSubmission(h1SubmissionId, "January to June 2025", isResubmission: false, created: "2025-07-08T09:00:00.0000000Z");
    await UpsertFileCycle(h1SubmissionId, h1EventIds, h1FileId, h1BlobName,
        "PopQuest_Pom_2025H1.csv", "January to June 2025", "2025-07-08", isResubmission: false);
    await UpsertEvent(h1SubmissionId, "a4a4a4a4-4444-4444-8444-444444444444", "RegulatorPoMDecision", "2025-07-22T10:30:00.0000000Z", new()
    {
        ["FileId"] = h1FileId.ToLowerInvariant(),
        ["Decision"] = "Accepted",
        ["RegistrationReferenceNumber"] = "PQL-2025H1-POM-DEC-0001",
        ["DecisionDate"] = "2025-07-22T10:30:00.0000000Z",
        ["Comments"] = "Packaging data accepted",
        ["IsResubmissionRequired"] = false,
        ["UserId"] = regulatorUserId.ToLowerInvariant(),
    });
    Console.WriteLine($"Seeded POP QUEST packaging data submission {h1SubmissionId} (2025 H1, Accepted)");

    // ---- 2025 H2: Accepted, then a resubmission already in progress ----
    const string h2SubmissionId = "E5F6A7B8-C9D0-4E1F-2A3B-4C5D6E7F8091";
    const string h2FileId = "F6A7B8C9-D0E1-4F2A-3B4C-5D6E7F809112";
    const string h2BlobName = "B2C3D4E5-F6A7-4B8C-9D0E-1F2A3B4C5D6E";
    const string h2ResubFileId = "B8C9D0E1-F2A3-4B4C-8D5E-6F7A8B9C0D12";
    const string h2ResubBlobName = "A7B8C9D0-E1F2-4A3B-8C4D-5E6F7A8B9C01";
    const string h2Prefix = "D1D1D1D1-DDDD-4DDD-8DDD";
    // b1..b4 already exist in seed.sql's DP block; b5/b6 fill the same two gaps as a5/a6 above.
    string[] h2EventIds =
    [
        "b1b1b1b1-1111-4111-8111-111111111111", "b2b2b2b2-2222-4222-8222-222222222222",
        "b5b5b5b5-5555-4555-8555-555555555555", "b6b6b6b6-6666-4666-8666-666666666666",
        "b3b3b3b3-3333-4333-8333-333333333333",
    ];

    await UpsertSubmission(h2SubmissionId, "July to December 2025", isResubmission: true, created: "2025-10-06T09:00:00.0000000Z");
    await UpsertFileCycle(h2SubmissionId, h2EventIds, h2FileId, h2BlobName,
        "PopQuest_Pom_2025H2.csv", "July to December 2025", "2025-10-06", isResubmission: false);
    await UpsertEvent(h2SubmissionId, "b4b4b4b4-4444-4444-8444-444444444444", "RegulatorPoMDecision", "2025-10-20T11:00:00.0000000Z", new()
    {
        ["FileId"] = h2FileId.ToLowerInvariant(),
        ["Decision"] = "Accepted",
        ["RegistrationReferenceNumber"] = "PQL-2025H2-POM-DEC-0001",
        ["DecisionDate"] = "2025-10-20T11:00:00.0000000Z",
        ["Comments"] = "Packaging data accepted",
        ["IsResubmissionRequired"] = false,
        ["UserId"] = regulatorUserId.ToLowerInvariant(),
    });

    // The resubmission tail. Deliberately no PackagingDataResubmissionFeePayment or
    // PackagingResubmissionApplicationSubmitted event - the fee is ready to view but not yet paid
    // or finally submitted, which is the state under test. The reference number here must match
    // the one the sp_PomResubmissionPaycalParameters stub returns for this SubmissionId.
    await UpsertEvent(h2SubmissionId, $"{h2Prefix}-{1:D12}", "PackagingResubmissionReferenceNumberCreated", "2026-01-20T09:00:00.0000000Z", new()
    {
        ["PackagingResubmissionReferenceNumber"] = "PQL-2025H2-POM-RESUB-0001",
    });
    await UpsertFileCycle(h2SubmissionId,
        [$"{h2Prefix}-{2:D12}", $"{h2Prefix}-{3:D12}", $"{h2Prefix}-{4:D12}", $"{h2Prefix}-{5:D12}", $"{h2Prefix}-{6:D12}"],
        h2ResubFileId, h2ResubBlobName,
        "PopQuest_Pom_2025H2_Resubmission.csv", "July to December 2025", "2026-01-20", isResubmission: true);
    await UpsertEvent(h2SubmissionId, $"{h2Prefix}-{7:D12}", "PackagingResubmissionFeeViewed", "2026-01-20T10:10:00.0000000Z", new()
    {
        ["FileId"] = h2ResubFileId.ToLowerInvariant(),
        ["IsPackagingResubmissionFeeViewed"] = true,
    });
    Console.WriteLine($"Seeded POP QUEST packaging data submission {h2SubmissionId} (2025 H2, Accepted + resubmission in progress)");

    // ---- 2026 H1: Accepted, then a corrected file Rejected ----
    const string y26SubmissionId = "C9D0E1F2-A3B4-4C5D-8E6F-7A8B9C0D1E23";
    const string y26FileIdA = "D0E1F2A3-B4C5-4D6E-8F7A-8B9C0D1E2F34";
    const string y26BlobNameA = "E1F2A3B4-C5D6-4E7F-8A8B-9C0D1E2F3A45";
    const string y26FileIdB = "1A2B3C4D-5E6F-4A7B-8C9D-0E1F2A3B4C5E";
    const string y26BlobNameB = "2B3C4D5E-6F7A-4B8C-9D0E-1F2A3B4C5D6F";
    const string y26Prefix = "D2D2D2D2-DDDD-4DDD-8DDD";

    await UpsertSubmission(y26SubmissionId, "January to June 2026", isResubmission: true, created: "2026-01-08T09:00:00.0000000Z");
    await UpsertFileCycle(y26SubmissionId,
        [$"{y26Prefix}-{1:D12}", $"{y26Prefix}-{2:D12}", $"{y26Prefix}-{3:D12}", $"{y26Prefix}-{4:D12}", $"{y26Prefix}-{5:D12}"],
        y26FileIdA, y26BlobNameA,
        "PopQuest_Pom_2026H1.csv", "January to June 2026", "2026-01-08", isResubmission: false);
    await UpsertEvent(y26SubmissionId, $"{y26Prefix}-{6:D12}", "RegulatorPoMDecision", "2026-01-22T10:30:00.0000000Z", new()
    {
        ["FileId"] = y26FileIdA.ToLowerInvariant(),
        ["Decision"] = "Accepted",
        ["RegistrationReferenceNumber"] = "PQL-2026H1-POM-DEC-0001",
        ["DecisionDate"] = "2026-01-22T10:30:00.0000000Z",
        ["Comments"] = "Packaging data accepted",
        ["IsResubmissionRequired"] = false,
        ["UserId"] = regulatorUserId.ToLowerInvariant(),
    });
    // The fee-based resubmission cycle. The reference number has to predate the corrected file - see
    // the equivalent Northbridge block above for why - and the corrected file's Submitted event is
    // itself the resubmission, hence isResubmission: true.
    await UpsertEvent(y26SubmissionId, $"{y26Prefix}-{13:D12}", "PackagingResubmissionReferenceNumberCreated", "2026-07-06T09:00:00.0000000Z", new()
    {
        ["PackagingResubmissionReferenceNumber"] = "PQL-2026H1-POM-RESUB-0001",
    });
    await UpsertFileCycle(y26SubmissionId,
        [$"{y26Prefix}-{7:D12}", $"{y26Prefix}-{8:D12}", $"{y26Prefix}-{9:D12}", $"{y26Prefix}-{10:D12}", $"{y26Prefix}-{11:D12}"],
        y26FileIdB, y26BlobNameB,
        "PopQuest_Pom_2026H1_Corrected.csv", "January to June 2026", "2026-07-07", isResubmission: true);
    await UpsertEvent(y26SubmissionId, $"{y26Prefix}-{14:D12}", "PackagingResubmissionFeeViewed", "2026-07-07T09:10:00.0000000Z", new()
    {
        ["FileId"] = y26FileIdB.ToLowerInvariant(),
        ["IsPackagingResubmissionFeeViewed"] = true,
    });
    // 807.00 = the 2026 direct-producer resubmission base fee. ProducerResubmissionService only
    // multiplies that by MemberCount when EnableResubmissionProducerMemberCountBaseFeeMultiplication
    // is on, and it is not enabled in this local stack, so the base fee is what gets paid.
    await UpsertEvent(y26SubmissionId, $"{y26Prefix}-{15:D12}", "PackagingDataResubmissionFeePayment", "2026-07-07T09:20:00.0000000Z", new()
    {
        ["FileId"] = y26FileIdB.ToLowerInvariant(),
        ["ReferenceNumber"] = "PQL-2026H1-POM-RESUB-0001",
        ["PaymentMethod"] = "PayByBankTransfer",
        ["PaymentStatus"] = "Paid",
        ["PaidAmount"] = "807.00",
    });
    await UpsertEvent(y26SubmissionId, $"{y26Prefix}-{16:D12}", "PackagingResubmissionApplicationSubmitted", "2026-07-07T09:25:00.0000000Z", new()
    {
        ["FileId"] = y26FileIdB.ToLowerInvariant(),
        ["IsResubmitted"] = true,
        ["SubmittedBy"] = "Olivia Reed",
        ["SubmissionDate"] = "2026-07-07T09:25:00.0000000Z",
        ["Comments"] = "Corrected packaging data resubmitted for January to June 2026",
    });
    await UpsertEvent(y26SubmissionId, $"{y26Prefix}-{12:D12}", "RegulatorPoMDecision", "2026-07-21T10:15:00.0000000Z", new()
    {
        ["FileId"] = y26FileIdB.ToLowerInvariant(),
        ["Decision"] = "Rejected",
        ["RegistrationReferenceNumber"] = "PQL-2026H1-POM-DEC-0002",
        ["DecisionDate"] = "2026-07-21T10:15:00.0000000Z",
        ["Comments"] = "Packaging data rejected: the corrected material weight figures do not reconcile with the originally accepted submission for this period",
        ["IsResubmissionRequired"] = true,
        ["UserId"] = regulatorUserId.ToLowerInvariant(),
    });
    Console.WriteLine($"Seeded POP QUEST packaging data submission {y26SubmissionId} (2026 H1, Accepted then Rejected on resubmission)");

    // ---- 2024-P1 (January to June 2024): Large producers only. First submission Accepted, then a resubmission that was also Accepted. ----
    const string pq2024p1SubmissionId = "D7D7D7D7-5555-4555-8555-000000000001";
    await UpsertSubmission(pq2024p1SubmissionId, "January to June 2024", isResubmission: true, created: "2024-08-05T09:00:00.0000000Z");
    await UpsertEvent(pq2024p1SubmissionId, "D7D7D7D7-DDDD-4DDD-8DDD-000000000001", "AntivirusCheck", "2024-08-05T09:00:00.0000000Z", new()
    {
        ["FileId"] = "d7d7d7d7-aaaa-4aaa-8aaa-000000000001",
        ["FileType"] = "Pom",
        ["FileName"] = "PopQuest_Pom_2024P1.csv",
        ["RegistrationSetId"] = null,
    });
    await UpsertEvent(pq2024p1SubmissionId, "D7D7D7D7-DDDD-4DDD-8DDD-000000000002", "AntivirusResult", "2024-08-05T09:02:10.0000000Z", new()
    {
        ["FileId"] = "d7d7d7d7-aaaa-4aaa-8aaa-000000000001",
        ["BlobName"] = "d7d7d7d7-bbbb-4bbb-8bbb-000000000001",
        ["AntivirusScanResult"] = "Success",
        ["RequiresRowValidation"] = false,
    });
    await UpsertEvent(pq2024p1SubmissionId, "D7D7D7D7-DDDD-4DDD-8DDD-000000000003", "CheckSplitter", "2024-08-05T09:03:00.0000000Z", new()
    {
        ["BlobName"] = "d7d7d7d7-bbbb-4bbb-8bbb-000000000001",
        ["DataCount"] = 1,
        ["ErrorCount"] = 0,
        ["WarningCount"] = 0,
    });
    await UpsertEvent(pq2024p1SubmissionId, "D7D7D7D7-DDDD-4DDD-8DDD-000000000004", "ProducerValidation", "2024-08-05T09:03:40.0000000Z", new()
    {
        ["BlobName"] = "d7d7d7d7-bbbb-4bbb-8bbb-000000000001",
        ["IsValid"] = true,
        ["ErrorCount"] = 0,
        ["WarningCount"] = 0,
    });
    await UpsertEvent(pq2024p1SubmissionId, "D7D7D7D7-DDDD-4DDD-8DDD-000000000005", "Submitted", "2024-08-05T09:05:00.0000000Z", new()
    {
        ["FileId"] = "d7d7d7d7-aaaa-4aaa-8aaa-000000000001",
        ["SubmittedBy"] = "Olivia Reed",
        ["IsResubmission"] = false,
        ["SubmissionPeriod"] = "January to June 2024",
    });
    await UpsertEvent(pq2024p1SubmissionId, "D7D7D7D7-DDDD-4DDD-8DDD-000000000006", "RegulatorPoMDecision", "2024-08-19T10:30:00.0000000Z", new()
    {
        ["FileId"] = "d7d7d7d7-aaaa-4aaa-8aaa-000000000001",
        ["Decision"] = "Accepted",
        ["RegistrationReferenceNumber"] = "PQL-2024P1-POM-DEC-0001",
        ["DecisionDate"] = "2024-08-19T10:30:00.0000000Z",
        ["Comments"] = "Packaging data accepted",
        ["IsResubmissionRequired"] = false,
        ["UserId"] = regulatorUserId.ToLowerInvariant(),
    });
    await UpsertEvent(pq2024p1SubmissionId, "D7D7D7D7-DDDD-4DDD-8DDD-000000000007", "PackagingResubmissionReferenceNumberCreated", "2024-09-09T09:00:00.0000000Z", new()
    {
        ["PackagingResubmissionReferenceNumber"] = "PQL-2024P1-POM-RESUB-0001",
    });
    await UpsertEvent(pq2024p1SubmissionId, "D7D7D7D7-DDDD-4DDD-8DDD-000000000008", "AntivirusCheck", "2024-09-10T09:00:00.0000000Z", new()
    {
        ["FileId"] = "d7d7d7d7-aaaa-4aaa-8aaa-000000000002",
        ["FileType"] = "Pom",
        ["FileName"] = "PopQuest_Pom_2024P1_Resubmission.csv",
        ["RegistrationSetId"] = null,
    });
    await UpsertEvent(pq2024p1SubmissionId, "D7D7D7D7-DDDD-4DDD-8DDD-000000000009", "AntivirusResult", "2024-09-10T09:02:10.0000000Z", new()
    {
        ["FileId"] = "d7d7d7d7-aaaa-4aaa-8aaa-000000000002",
        ["BlobName"] = "d7d7d7d7-bbbb-4bbb-8bbb-000000000002",
        ["AntivirusScanResult"] = "Success",
        ["RequiresRowValidation"] = false,
    });
    await UpsertEvent(pq2024p1SubmissionId, "D7D7D7D7-DDDD-4DDD-8DDD-000000000010", "CheckSplitter", "2024-09-10T09:03:00.0000000Z", new()
    {
        ["BlobName"] = "d7d7d7d7-bbbb-4bbb-8bbb-000000000002",
        ["DataCount"] = 1,
        ["ErrorCount"] = 0,
        ["WarningCount"] = 0,
    });
    await UpsertEvent(pq2024p1SubmissionId, "D7D7D7D7-DDDD-4DDD-8DDD-000000000011", "ProducerValidation", "2024-09-10T09:03:40.0000000Z", new()
    {
        ["BlobName"] = "d7d7d7d7-bbbb-4bbb-8bbb-000000000002",
        ["IsValid"] = true,
        ["ErrorCount"] = 0,
        ["WarningCount"] = 0,
    });
    await UpsertEvent(pq2024p1SubmissionId, "D7D7D7D7-DDDD-4DDD-8DDD-000000000012", "Submitted", "2024-09-10T09:05:00.0000000Z", new()
    {
        ["FileId"] = "d7d7d7d7-aaaa-4aaa-8aaa-000000000002",
        ["SubmittedBy"] = "Olivia Reed",
        ["IsResubmission"] = true,
        ["SubmissionPeriod"] = "January to June 2024",
    });
    await UpsertEvent(pq2024p1SubmissionId, "D7D7D7D7-DDDD-4DDD-8DDD-000000000013", "RegulatorPoMDecision", "2024-09-24T10:30:00.0000000Z", new()
    {
        ["FileId"] = "d7d7d7d7-aaaa-4aaa-8aaa-000000000002",
        ["Decision"] = "Accepted",
        ["RegistrationReferenceNumber"] = "PQL-2024P1-POM-DEC-0002",
        ["DecisionDate"] = "2024-09-24T10:30:00.0000000Z",
        ["Comments"] = "Packaging data accepted",
        ["IsResubmissionRequired"] = false,
        ["UserId"] = regulatorUserId.ToLowerInvariant(),
    });
    await UpsertEvent(pq2024p1SubmissionId, "D7D7D7D7-DDDD-4DDD-8DDD-000000000014", "PackagingResubmissionFeeViewed", "2024-09-10T09:10:00.0000000Z", new()
    {
        ["FileId"] = "d7d7d7d7-aaaa-4aaa-8aaa-000000000002",
        ["IsPackagingResubmissionFeeViewed"] = true,
    });
    await UpsertEvent(pq2024p1SubmissionId, "D7D7D7D7-DDDD-4DDD-8DDD-000000000015", "PackagingDataResubmissionFeePayment", "2024-09-10T09:20:00.0000000Z", new()
    {
        ["FileId"] = "d7d7d7d7-aaaa-4aaa-8aaa-000000000002",
        ["ReferenceNumber"] = "PQL-2024P1-POM-RESUB-0001",
        ["PaymentMethod"] = "PayByBankTransfer",
        ["PaymentStatus"] = "Paid",
        ["PaidAmount"] = "714.00",
    });
    await UpsertEvent(pq2024p1SubmissionId, "D7D7D7D7-DDDD-4DDD-8DDD-000000000016", "PackagingResubmissionApplicationSubmitted", "2024-09-10T09:25:00.0000000Z", new()
    {
        ["FileId"] = "d7d7d7d7-aaaa-4aaa-8aaa-000000000002",
        ["IsResubmitted"] = true,
        ["SubmittedBy"] = "Olivia Reed",
        ["SubmissionDate"] = "2024-09-10T09:25:00.0000000Z",
        ["Comments"] = "Corrected packaging data resubmitted for January to June 2024",
    });
    Console.WriteLine($"Seeded POP QUEST packaging data submission {pq2024p1SubmissionId} (2024-P1, Accepted, then resubmission Accepted)");

    // ---- 2024-P4 (July to December 2024): Large producers only. First submission Rejected; no resubmission cycle. ----
    const string pq2024p4SubmissionId = "D8D8D8D8-5555-4555-8555-000000000001";
    await UpsertSubmission(pq2024p4SubmissionId, "July to December 2024", isResubmission: false, created: "2025-02-10T09:00:00.0000000Z");
    await UpsertEvent(pq2024p4SubmissionId, "D8D8D8D8-DDDD-4DDD-8DDD-000000000001", "AntivirusCheck", "2025-02-10T09:00:00.0000000Z", new()
    {
        ["FileId"] = "d8d8d8d8-aaaa-4aaa-8aaa-000000000001",
        ["FileType"] = "Pom",
        ["FileName"] = "PopQuest_Pom_2024P4.csv",
        ["RegistrationSetId"] = null,
    });
    await UpsertEvent(pq2024p4SubmissionId, "D8D8D8D8-DDDD-4DDD-8DDD-000000000002", "AntivirusResult", "2025-02-10T09:02:10.0000000Z", new()
    {
        ["FileId"] = "d8d8d8d8-aaaa-4aaa-8aaa-000000000001",
        ["BlobName"] = "d8d8d8d8-bbbb-4bbb-8bbb-000000000001",
        ["AntivirusScanResult"] = "Success",
        ["RequiresRowValidation"] = false,
    });
    await UpsertEvent(pq2024p4SubmissionId, "D8D8D8D8-DDDD-4DDD-8DDD-000000000003", "CheckSplitter", "2025-02-10T09:03:00.0000000Z", new()
    {
        ["BlobName"] = "d8d8d8d8-bbbb-4bbb-8bbb-000000000001",
        ["DataCount"] = 1,
        ["ErrorCount"] = 0,
        ["WarningCount"] = 0,
    });
    await UpsertEvent(pq2024p4SubmissionId, "D8D8D8D8-DDDD-4DDD-8DDD-000000000004", "ProducerValidation", "2025-02-10T09:03:40.0000000Z", new()
    {
        ["BlobName"] = "d8d8d8d8-bbbb-4bbb-8bbb-000000000001",
        ["IsValid"] = true,
        ["ErrorCount"] = 0,
        ["WarningCount"] = 0,
    });
    await UpsertEvent(pq2024p4SubmissionId, "D8D8D8D8-DDDD-4DDD-8DDD-000000000005", "Submitted", "2025-02-10T09:05:00.0000000Z", new()
    {
        ["FileId"] = "d8d8d8d8-aaaa-4aaa-8aaa-000000000001",
        ["SubmittedBy"] = "Olivia Reed",
        ["IsResubmission"] = false,
        ["SubmissionPeriod"] = "July to December 2024",
    });
    await UpsertEvent(pq2024p4SubmissionId, "D8D8D8D8-DDDD-4DDD-8DDD-000000000006", "RegulatorPoMDecision", "2025-02-24T10:30:00.0000000Z", new()
    {
        ["FileId"] = "d8d8d8d8-aaaa-4aaa-8aaa-000000000001",
        ["Decision"] = "Rejected",
        ["RegistrationReferenceNumber"] = "PQL-2024P4-POM-DEC-0001",
        ["DecisionDate"] = "2025-02-24T10:30:00.0000000Z",
        ["Comments"] = "Packaging data rejected: the reported tonnages could not be reconciled with the supporting evidence for this period",
        ["IsResubmissionRequired"] = true,
        ["UserId"] = regulatorUserId.ToLowerInvariant(),
    });
    Console.WriteLine($"Seeded POP QUEST packaging data submission {pq2024p4SubmissionId} (2024-P4, Rejected)");
}

record PopQuestRegistrationSeed(
    string SubmissionId,
    string FileId,
    string BlobName,
    string FileName,
    string SubmissionPeriod,
    string AppReferenceNumber,
    string RegistrationReferenceNumber,
    string PaidAmount,
    string EventIdPrefix,
    string Day,
    string DecisionDay);

record RegistrationSubmissionSeed(
    string SubmissionId,
    string FileId,
    string BlobName,
    string AntivirusCheckEventId,
    string AntivirusResultEventId,
    string ValidationEventId,
    string SubmittedEventId,
    string FeePaymentEventId,
    string AppSubmittedEventId,
    string DecisionEventId,
    string FileName,
    string SubmissionPeriod,
    string? RegistrationJourney,
    int MemberCount,
    string AppReferenceNumber,
    string RegistrationReferenceNumber,
    string PaidAmount,
    string AntivirusCheckCreated,
    string AntivirusResultCreated,
    string ValidationCreated,
    string SubmittedCreated,
    string FeePaymentCreated,
    string AppSubmittedCreated,
    string DecisionCreated);
