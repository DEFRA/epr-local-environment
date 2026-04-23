- **Previous Payment Information Flow**
  - **Overview**
    - This document traces how previous payment information is retrieved and displayed on the regulator's registration submission details page:
      - **URL Pattern**: `/regulators/registration-submission-details/{submissionId}`
      - **Example**: `/regulators/registration-submission-details/1ba7b672-68ee-4dbd-ae2b-a9d882bc1b3d`
    - The data flows through multiple services before reaching the database.
  - **Architecture Flow**
    - ```
      epr-regulator-service (Frontend)
          ↓ HTTP POST
      epr-payment-facade (API Gateway)
          ↓ HTTP POST
      epr-payment-service (Payment API)
          ↓ SQL Query
      SQL Server Database (Payment table)
      ```
  - **Detailed Flow by Service**
    - **1. epr-regulator-service (Frontend)**
      - **1.1 Controller Layer**
        - **File**: [RegistrationSubmissionsController.cs](https://github.com/DEFRA/epr-regulator-service/blob/18040a85df69452e7f2e32634b11ffbd42a49820/src/EPR.RegulatorService.Frontend.Web/Controllers/RegistrationSubmissions/RegistrationSubmissionsController.cs#L117-L155)
        - **Endpoint**: `GET /regulators/registration-submission-details/{submissionId}`
        - **Handler**: `RegistrationSubmissionDetails(Guid? submissionId)` (lines 117-155)
        - ```csharp
          public async Task<IActionResult> RegistrationSubmissionDetails(Guid? submissionId)
          {
              _currentSession = await _sessionManager.GetSessionAsync(HttpContext.Session);

              if (!GetOrRejectProvidedSubmissionId(submissionId.Value, out var model))
              {
                  model = await FetchFromSessionOrFacadeAsync(submissionId.Value,
                      _facadeService.GetRegistrationSubmissionDetails);
              }

              return View(nameof(RegistrationSubmissionDetails), model);
          }
          ```
        - **Data Retrieval Flow for ReferenceNumber**:
          - **Session/Facade Layer** (epr-regulator-service):
            - Calls [FetchFromSessionOrFacadeAsync](https://github.com/DEFRA/epr-regulator-service/blob/18040a85df69452e7f2e32634b11ffbd42a49820/src/EPR.RegulatorService.Frontend.Web/Controllers/RegistrationSubmissions/RegistrationSubmissionsController_part.cs#L76-L92)
              - First checks session cache
              - If not cached, calls facade: `_facadeService.GetRegistrationSubmissionDetails(submissionId)`
            - [FacadeService.GetRegistrationSubmissionDetails](https://github.com/DEFRA/epr-regulator-service/blob/18040a85df69452e7f2e32634b11ffbd42a49820/src/EPR.RegulatorService.Frontend.Core/Services/FacadeService.cs#L446-L461)
              - Makes HTTP GET to facade endpoint: `organisation-registration-submission-details/{submissionId}`
              - Receives `RegistrationSubmissionOrganisationDetailsResponse` with `ApplicationReferenceNumber`
          - **Regulator Facade Layer** (epr-regulator-service-facade):
            - [Controller](https://github.com/DEFRA/epr-regulator-service-facade/blob/80d32f9cb502f8d4a22a8deabe0a4a3465657212/src/EPR.RegulatorService.Facade.API/Controllers/OrganisationRegistrationSubmissionsController.cs#L170-L197): `GetRegistrationSubmissionDetails`
            - [Service](https://github.com/DEFRA/epr-regulator-service-facade/blob/80d32f9cb502f8d4a22a8deabe0a4a3465657212/src/EPR.RegulatorService.Facade.Core/Services/RegistrationSubmission/OrganisationRegistrationSubmissionService.cs#L81-L100): `HandleGetOrganisationRegistrationSubmissionDetails`
              - **Line 85-90**: Checks for Cosmos delta updates (recent regulator decisions)
                - Calls `GetDeltaSubmissionEvents()` to get recent decision events from Cosmos DB
              - **Line 92**: Calls `commonDataService.GetOrganisationRegistrationSubmissionDetails(submissionId)`
                - Retrieves base data from Common Data API
              - **Line 94-96**: Merges Cosmos updates into base data if available
                - Calls [MergeCosmosUpdates](https://github.com/DEFRA/epr-regulator-service-facade/blob/80d32f9cb502f8d4a22a8deabe0a4a3465657212/src/EPR.RegulatorService.Facade.Core/Services/RegistrationSubmission/OrganisationRegistationSubmissionService_Synchronisation.cs#L151-L184)
                - **Important**: This only updates status fields (`SubmissionStatus`, `RegulatorComments`, `RegistrationReferenceNumber`, decision dates)
                - **ApplicationReferenceNumber is NOT modified** - it remains as retrieved from Common Data API
            - [CommonDataService](https://github.com/DEFRA/epr-regulator-service-facade/blob/80d32f9cb502f8d4a22a8deabe0a4a3465657212/src/EPR.RegulatorService.Facade.Core/Services/CommonData/CommonDataService.cs#L47-L65): `GetOrganisationRegistrationSubmissionDetails`
              - Makes HTTP GET to Common Data API: `submissions/organisation-registration-submission/{submissionId}`
          - **Common Data API Layer** (epr-common-data-api):
            - [Controller](https://github.com/DEFRA/epr-common-data-api/blob/50205de774c76804c810fc00319f28153f12d3d8/src/EPR.CommonDataService.Api/Controllers/SubmissionsController.cs#L144-L174): `GetOrganisationRegistrationSubmissionDetails`
            - [Service](https://github.com/DEFRA/epr-common-data-api/blob/50205de774c76804c810fc00319f28153f12d3d8/src/EPR.CommonDataService.Core/Services/SubmissionsService.cs#L111-L142): `GetOrganisationRegistrationSubmissionDetails`
              - **Line 117-119**: Determines which stored procedure to use based on feature flag
                - `dbo.sp_FetchOrganisationRegistrationSubmissionDetails_resub_LateFee` (with late fee logic)
                - OR `dbo.sp_FetchOrganisationRegistrationSubmissionDetails_resub` (standard)
              - **Line 128**: Executes stored procedure against SQL Server (Accounts database)
              - Returns `OrganisationRegistrationDetailsDto` containing `ApplicationReferenceNumber`
          - **Data Source**: **SQL Server Accounts Database**
            - **Stored Procedures**:
              - [sp_FetchOrganisationRegistrationSubmissionDetails_resub_LateFee](https://github.com/DEFRA/epr-common-data-api/blob/50205de774c76804c810fc00319f28153f12d3d8/src/EPR.CommonDataService.Data/Scripts/Stored%20Procedures/sp_fetch-organisation-registration-details-resub-latefee.sql#L6-L14)
                - Line 12: Queries from `dbo.t_FetchOrganisationRegistrationSubmissionDetails_resub` table
              - [sp_FetchOrganisationRegistrationSubmissionDetails_resub](https://github.com/DEFRA/epr-common-data-api/blob/50205de774c76804c810fc00319f28153f12d3d8/src/EPR.CommonDataService.Data/Scripts/Stored%20Procedures/sp_fetch-organisation-registration-details-resub.sql#L6-L13)
                - Line 11: Queries from `dbo.t_FetchOrganisationRegistrationSubmissionDetails_resub` table
            - **Table Schema**: [t_FetchOrganisationRegistrationSubmissionDetails_resub](https://github.com/DEFRA/epr-common-data-api/blob/50205de774c76804c810fc00319f28153f12d3d8/src/EPR.CommonDataService.Data/Scripts/Create%20Tables/create-apps-fetchorgregdetails-table.sql#L3-L72)
              - Line 9: `[ApplicationReferenceNumber] [nvarchar](4000) NULL`
              - This table is populated from [V_FetchOrganisationRegistrationSubmissionDetails_resub view](https://github.com/DEFRA/epr-common-data-api/blob/50205de774c76804c810fc00319f28153f12d3d8/src/EPR.CommonDataService.Data/Scripts/Views/sp_fetch-organisation-registration-details-resub.sql#L15-L24)
                - Line 24: `S.AppReferenceNumber as ApplicationReferenceNumber`
                - Line 47: From table `[rpd].[Submissions]`
            - **Ultimate Source Table**: `[rpd].[Submissions]`
              - Column: `AppReferenceNumber`
              - **This is the authoritative source** - ApplicationReferenceNumber is stored in this table
          - **Data Mapping Chain**:
            - SQL Server → `OrganisationRegistrationDetailsDto` (Common Data API)
            - → `RegistrationSubmissionOrganisationDetailsFacadeResponse` (Facade)
            - → [RegistrationSubmissionOrganisationDetailsResponse](https://github.com/DEFRA/epr-regulator-service/blob/18040a85df69452e7f2e32634b11ffbd42a49820/src/EPR.RegulatorService.Frontend.Core/Models/RegistrationSubmissions/FacadeCommonData/RegistrationSubmissionOrganisationDetailsResponse.cs#L26) (Frontend)
              - Contains: `ApplicationReferenceNumber`
            - → [RegistrationSubmissionOrganisationDetails](https://github.com/DEFRA/epr-regulator-service/blob/18040a85df69452e7f2e32634b11ffbd42a49820/src/EPR.RegulatorService.Frontend.Core/Models/RegistrationSubmissions/RegistrationSubmissionOrganisationDetails.cs#L115-L175) (implicit conversion)
              - Line 138: Maps `ApplicationReferenceNumber` from response
            - → [RegistrationSubmissionDetailsViewModel](https://github.com/DEFRA/epr-regulator-service/blob/18040a85df69452e7f2e32634b11ffbd42a49820/src/EPR.RegulatorService.Frontend.Web/ViewModels/RegistrationSubmissions/RegistrationSubmissionDetailsViewModel.cs#L55-L92) (implicit conversion)
              - Line 61: Sets `ReferenceNumber = details.ApplicationReferenceNumber`
          - **Result**: `viewModel.ReferenceNumber` = `ApplicationReferenceNumber` from **SQL Server Accounts Database** (via Common Data API stored procedure)
      - **1.2 View Component Layer**
        - **File**: [ProducerPaymentDetailsViewComponent.cs](https://github.com/DEFRA/epr-regulator-service/blob/18040a85df69452e7f2e32634b11ffbd42a49820/src/EPR.RegulatorService.Frontend.Web/ViewComponents/RegistrationSubmissions/ProducerPaymentDetailsViewComponent.cs#L22-L71)
        - **Method**: `InvokeAsync(RegistrationSubmissionDetailsViewModel viewModel)` (lines 22-71)
        - **Key Operation** (line 26):
          - ```csharp
            var producerPaymentResponse = await paymentFacadeService.GetProducerPaymentDetailsAsync(
                new ProducerPaymentRequest
                {
                    ApplicationReferenceNumber = viewModel.ReferenceNumber,
                    NoOfSubsidiariesOnlineMarketplace = viewModel.ProducerDetails.NoOfSubsidiariesOnlineMarketPlace,
                    NumberOfSubsidiaries = viewModel.ProducerDetails.NoOfSubsidiaries,
                    IsLateFeeApplicable = viewModel.ProducerDetails.IsLateFeeApplicable,
                    IsProducerOnlineMarketplace = viewModel.ProducerDetails.IsProducerOnlineMarketplace,
                    ProducerType = viewModel.ProducerDetails.ProducerType,
                    Regulator = viewModel.NationCode,
                    SubmissionDate = TimeZoneInfo.ConvertTimeToUtc(/* ... */)
                });
            ```
        - **Mapping** (line 50):
          - ```csharp
            PreviousPaymentsReceived = ConvertToPoundsFromPence(
                producerPaymentResponse.PreviousPaymentsReceived)
            ```
      - **1.3 Payment Facade HTTP Client**
        - **File**: [PaymentFacadeService.cs](https://github.com/DEFRA/epr-regulator-service/blob/18040a85df69452e7f2e32634b11ffbd42a49820/src/EPR.RegulatorService.Frontend.Core/Services/PaymentFacadeService.cs#L66-L74)
        - **Method**: `GetProducerPaymentDetailsAsync(ProducerPaymentRequest request)` (lines 66-74)
        - **HTTP Call**:
          - ```csharp
            var response = await _httpClient.PostAsJsonAsync(
                _paymentFacadeApiConfig.Endpoints["GetProducerPaymentDetailsPath"],
                request);
            ```
        - **Configuration** (appsettings.json line 231):
          - ```json
            "GetProducerPaymentDetailsPath": "producer/registration-fee"
            ```
    - **2. epr-payment-facade (API Gateway)**
      - **2.1 Controller Layer**
        - **File**: [ProducersFeesController.cs](https://github.com/DEFRA/epr-payment-facade/blob/d62d5ab3437c442ee1bade8afe1e8fc9af501a99/src/EPR.Payment.Facade/Controllers/RegistrationFees/Producer/ProducersFeesController.cs#L50-L99)
        - **Endpoint**: `POST /api/v1/producer/registration-fee`
        - **Handler**: `CalculateFeesAsync(ProducerFeesRequestDto request)` (lines 50-99)
        - ```csharp
          [HttpPost("v1/producer/registration-fee")]
          public async Task<IActionResult> CalculateFeesAsync(
              [FromBody] ProducerFeesRequestDto producerRegistrationFeesRequestDto,
              CancellationToken cancellationToken)
          {
              var result = await _producerFeesService.CalculateProducerFeesAsync(
                  producerRegistrationFeesRequestDto,
                  cancellationToken);
              return Ok(result);
          }
          ```
      - **2.2 Service Layer**
        - **File**: [ProducerFeesService.cs](https://github.com/DEFRA/epr-payment-facade/blob/d62d5ab3437c442ee1bade8afe1e8fc9af501a99/src/EPR.Payment.Facade/Services/RegistrationFees/Producer/ProducerFeesService.cs#L26-L32)
        - **Method**: `CalculateProducerFeesAsync(ProducerFeesRequestDto request)` (lines 26-32)
        - **Delegates to HTTP Service**:
          - ```csharp
            var response = await _httpProducerFeesService.CalculateProducerFeesAsync(request);
            ```
      - **2.3 HTTP Client Layer**
        - **File**: [HttpProducerFeesService.cs](https://github.com/DEFRA/epr-payment-facade/blob/d62d5ab3437c442ee1bade8afe1e8fc9af501a99/src/EPR.Payment.Facade.Common/RESTServices/RegistrationFees/Producer/HttpProducerFeesService.cs#L30-L48)
        - **Method**: `CalculateProducerFeesAsync(ProducerFeesRequestDto request)` (lines 30-48)
        - **HTTP Call** (line 37):
          - ```csharp
            var url = UrlConstants.CalculateProducerRegistrationFees; // "producer/registration-fee"
            var response = await Post<ProducerFeesResponseDto>(url, request, cancellationToken);
            ```
    - **3. epr-payment-service (Payment API)**
      - **3.1 Controller Layer**
        - **File**: [ProducerFeesController.cs](https://github.com/DEFRA/epr-payment-service/blob/5c605ff38dc601b80006bde1d0fea785e04774fa/src/EPR.Payment.Service/Controllers/RegistrationFees/Producer/ProducerFeesController.cs#L43-L82)
        - **Endpoint**: `POST /api/v1/producer/registration-fee`
        - **Handler**: `CalculateFeesAsync(ProducerRegistrationFeesRequestDto request)` (lines 43-82)
        - ```csharp
          [HttpPost("v1/producer/registration-fee")]
          public async Task<ActionResult<RegistrationFeesResponseDto>> CalculateFeesAsync(
              [FromBody] ProducerRegistrationFeesRequestDto request,
              CancellationToken cancellationToken)
          {
              var result = await _producerFeesCalculatorService.CalculateFeesAsync(
                  request,
                  cancellationToken);
              return Ok(result);
          }
          ```
      - **3.2 Calculator Service**
        - **File**: [ProducerFeesCalculatorService.cs](https://github.com/DEFRA/epr-payment-service/blob/5c605ff38dc601b80006bde1d0fea785e04774fa/src/EPR.Payment.Service/Services/RegistrationFees/Producer/ProducerFeesCalculatorService.cs#L38-L57)
        - **Method**: `CalculateFeesAsync(ProducerRegistrationFeesRequestDto request)` (lines 38-57)
        - **Previous Payment Lookup** (line 53):
          - ```csharp
            response.PreviousPayment = await _paymentsService.GetPreviousPaymentsByReferenceAsync(
                request.ApplicationReferenceNumber,
                cancellationToken);
            ```
        - **Outstanding Calculation** (line 54):
          - ```csharp
            response.OutstandingPayment = response.TotalFee - response.PreviousPayment;
            ```
      - **3.3 Payments Service**
        - **File**: [PaymentsService.cs](https://github.com/DEFRA/epr-payment-service/blob/5c605ff38dc601b80006bde1d0fea785e04774fa/src/EPR.Payment.Service/Services/Payments/PaymentsService.cs#L15-L23)
        - **Method**: `GetPreviousPaymentsByReferenceAsync(string reference)` (lines 15-23)
        - ```csharp
          public async Task<decimal> GetPreviousPaymentsByReferenceAsync(
              string reference,
              CancellationToken cancellationToken)
          {
              if (string.IsNullOrEmpty(reference))
              {
                  throw new ArgumentException(PaymentConstants.InvalidReference);
              }

              return await _paymentsRepository.GetPreviousPaymentsByReferenceAsync(
                  reference,
                  cancellationToken);
          }
          ```
      - **3.4 Repository Layer**
        - **File**: [PaymentsRepository.cs](https://github.com/DEFRA/epr-payment-service/blob/5c605ff38dc601b80006bde1d0fea785e04774fa/src/EPR.Payment.Service.Common.Data/Repositories/Payments/PaymentsRepository.cs#L15-L21)
        - **Method**: `GetPreviousPaymentsByReferenceAsync(string reference)` (lines 15-21)
        - ```csharp
          public async Task<decimal> GetPreviousPaymentsByReferenceAsync(
              string reference,
              CancellationToken cancellationToken)
          {
              return await _dataContext.Payment
                     .Where(a => a.Reference == reference &&
                                 a.InternalStatusId == Enums.Status.Success)
                     .SumAsync(a => a.Amount, cancellationToken);
          }
          ```
  - **Database Layer**
    - **Data Source**
      - **Database**: SQL Server
      - **Table**: `Payment`
      - **Schema**: `EPR.Payment.Service.Common.Data.DataModels.Payment`
    - **Payment Table Structure**
      - **Key Fields**:
        - `Id` (Primary Key)
        - `Reference` (ApplicationReferenceNumber) - **Query Filter**
        - `Amount` - **Aggregated Value**
        - `InternalStatusId` (enum) - **Query Filter** (must be `Success`)
        - `UserId`
        - `Regulator`
        - `ReasonForPayment`
        - `CreatedDate`
        - `UpdatedDate`
      - **Navigation Properties**:
        - `OnlinePayment` - GovPay transactions
        - `OfflinePayment` - BACS, CHAPS, cheque payments
    - **Query Logic**
      - **Filter Criteria**:
        - `Reference` = ApplicationReferenceNumber (the submission ID)
        - `InternalStatusId` = `Status.Success` (only successful payments)
      - **Aggregation**:
        - **SUM** of all `Amount` values matching the criteria
      - **Result**:
        - Returns total amount (in pence) of all successful previous payments for this registration
  - **Data Flow Summary**
    - **Request Path**
      - **User** → Views registration submission details page
      - **Frontend** → Constructs payment request with submission details
      - **Payment Facade** → Forwards request to payment service
      - **Payment Service** → Queries database for previous payments
      - **Database** → Returns sum of successful payment amounts
    - **Response Path**
      - **Database** → Returns decimal amount (in pence)
      - **Payment Service** → Includes in fee calculation response
      - **Payment Facade** → Passes through response
      - **Frontend** → Converts pence to pounds and displays
    - **Key Identifiers**
      - **ApplicationReferenceNumber** / **Reference**: Unique identifier linking:
        - Registration submissions
        - Payment records
        - Fee calculations
  - **Additional Components**
    - **Payment Detail Retrieval**
      - For detailed payment information (date, method, type), a separate method is available:
      - **File**: [PreviousPaymentsHelper.cs](https://github.com/DEFRA/epr-payment-service/blob/5c605ff38dc601b80006bde1d0fea785e04774fa/src/EPR.Payment.Service/Services/Payments/PreviousPaymentsHelper.cs#L11-L41)
      - **Method**: `GetPreviousPaymentAsync(string applicationReferenceNumber)` (lines 11-41)
      - **Returns**: `PreviousPaymentDetailResponseDto` containing:
        - `PaymentAmount`
        - `PaymentMode` (Online/Offline)
        - `PaymentDate`
        - `PaymentMethod` (GovPay, BACS, CHAPS, etc.)
      - **Query**:
        - ```csharp
          Payment? payment = await paymentsRepository.GetPreviousPaymentIncludeChildrenByReferenceAsync(
              applicationReferenceNumber,
              cancellationToken);
          ```
      - This uses `.Include()` to load related `OnlinePayment` and `OfflinePayment` entities.
  - **Notes**
    - **Currency Conversion**
      - Database stores amounts in **pence** (decimal)
      - Frontend displays in **pounds** (pence ÷ 100)
    - **Payment Types**
      - **Online**: GovPay transactions
      - **Offline**: Manual payments (BACS, CHAPS, cheque)
    - **Status Filtering**
      - Only payments with `InternalStatusId == Status.Success` are included in the previous payment total.
