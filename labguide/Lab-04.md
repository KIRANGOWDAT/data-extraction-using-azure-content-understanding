# Data Extraction Using Azure Content Understanding - Lab 04

![](../media/Lab-04/image01.png)

# Contents

- Introduction

- Document Extraction Configuration

    - Task 1: Review the extraction configuration schema

    - Task 2: Upload the extraction configuration via API

    - Task 3: Verify the configuration in Cosmos DB

- Document Ingestion with Azure Content Understanding

    - Task 4: Review the ingestion pipeline code

    - Task 5: Ingest a sample lease agreement document

    - Task 6: Verify extracted data in Cosmos DB

    - Task 7: Explore extracted fields, bounding boxes, and confidence scores

    - Task 8: Verify markdown storage in Azure Blob Storage

- Summary

- References

# Introduction

In this lab, you will configure the document extraction pipeline and ingest your first document using Azure Content Understanding. You will upload a JSON configuration that defines the fields to extract from lease agreements, then process a sample PDF document through the ingestion API. Finally, you will explore the extracted structured data — including fields, confidence scores, and bounding box coordinates — stored in Azure Cosmos DB.

By the end of this lab, you will have learned:

- How to define and upload extraction configuration schemas

- How Azure Content Understanding creates analyzer schemas from configurations

- How to ingest documents via the REST API

- How extracted fields, bounding boxes, and confidence scores are stored in Cosmos DB

- How document markdown is preserved in Azure Blob Storage

# Document Extraction Configuration

Before ingesting documents, you need to upload a configuration that tells the system what fields to extract, what data types to expect, and which Azure Content Understanding analyzer to use.

## Task 1: Review the extraction configuration schema

In this task, you will examine the extraction configuration JSON file and understand each component.

1. Ensure the Azure Function App is running locally from Lab 03. If not, open a terminal, activate the virtual environment, and start it:

    ```
    cd C:\Users\LabUser\Desktop\data-extraction-using-azure-content-understanding
    .venv\Scripts\activate
    func start --script-root ./src/
    ```

2. In VS Code, open the configuration file **configs/document-extraction-v1.0.json**:

    ![](../media/Lab-04/image02.png)

3. Review the top-level structure of the configuration:

    ```json
    {
        "id": "document-extraction-v1.0",
        "name": "document-extraction",
        "version": "v1.0",
        "prompt": "You are a helpful assistant tasked with using the necessary tools to retrieve document information...",
        "collection_rows": [...]
    }
    ```

    - **id** — Unique identifier composed of `{name}-{version}`.
    - **name** and **version** — Used to reference this configuration via the API.
    - **prompt** — The system prompt sent to Azure OpenAI when users query the ingested data.
    - **collection_rows** — Array of document type definitions, each with its own field schema and analyzer.

4. Examine the **collection_rows** array. Each row defines a document type and the fields to extract:

    ```json
    {
        "data_type": "LeaseAgreement",
        "field_schema": [
            {
                "name": "license_grant_scope",
                "type": "string",
                "description": "Scope of license granted to the lessee or company",
                "method": "extract"
            },
            {
                "name": "lease_duration",
                "type": "string",
                "description": "Minimum or expected duration of the lease",
                "method": "extract"
            },
            {
                "name": "termination_conditions",
                "type": "string",
                "description": "Conditions under which the lease can be terminated",
                "method": "extract"
            },
            {
                "name": "compliance_audit_terms",
                "type": "string",
                "description": "Details around compliance verification and audit rights",
                "method": "extract"
            },
            {
                "name": "prohibited_uses",
                "type": "string",
                "description": "Explicitly forbidden uses or restrictions",
                "method": "extract"
            }
        ],
        "analyzer_id": "test-analyzer"
    }
    ```

    ![](../media/Lab-04/image03.png)

5. Understand each field property:

    - **name** — The field name that will appear in the extracted output (e.g., `license_grant_scope`).
    - **type** — Data type for the extracted value. Supported types include: `string`, `integer`, `float`, `boolean`, `date`, `datetime`, `time`, `object`, and `array`.
    - **description** — Human-readable description that helps Azure Content Understanding understand what to extract.
    - **method** — Either `extract` (CU extracts the field from the document) or `generate` (LLM generates the value).
    - **analyzer_id** — The Azure Content Understanding analyzer name that will be created for this configuration.

## Task 2: Upload the extraction configuration via API

In this task, you will upload the configuration to the running Function App, which will store it in Cosmos DB and create the corresponding Content Understanding analyzer.

1. Open a **new terminal tab** (**Ctrl+Shift+`**) while keeping the Function App running.

2. Activate the virtual environment in the new terminal:

    ```
    cd C:\Users\LabUser\Desktop\data-extraction-using-azure-content-understanding
    .venv\Scripts\activate
    ```

3. Upload the extraction configuration using **curl**:

    ```
    curl -X PUT "http://localhost:7071/api/configs/document-extraction/versions/v1.0" ^
      -H "Content-Type: application/json" ^
      -d @configs/document-extraction-v1.0.json
    ```

    ![](../media/Lab-04/image04.png)

4. You should receive a **201 Created** response with a **Location** header pointing to the created configuration resource.

    ![](../media/Lab-04/image05.png)

5. Alternatively, you can use the **REST Client** extension in VS Code. Open the file **src/samples/config_update_sample.http** and click **Send Request** on the local PUT request line.

    ![](../media/Lab-04/image06.png)

6. Behind the scenes, the upload process performs these actions:

    a. **Validates** the JSON configuration against the expected Pydantic schema.

    b. **Creates an Azure Content Understanding analyzer** by calling the `begin_create_analyzer()` API with a template built from the field schema. Each field becomes a typed extraction field in the CU analyzer.

    c. **Computes a SHA-256 hash** of the extraction configuration for versioning and deduplication.

    d. **Upserts** the configuration document to the Cosmos DB "Configurations" collection.

7. Verify the configuration was stored successfully by retrieving it:

    ```
    curl http://localhost:7071/api/configs/document-extraction/versions/v1.0
    ```

    You should see the full configuration JSON returned, including the computed `extraction_config_hash`.

    ![](../media/Lab-04/image07.png)

## Task 3: Verify the configuration in Cosmos DB

In this task, you will navigate to Cosmos DB in the Azure Portal and inspect the stored configuration document.

1. Open the **Azure Portal** and navigate to your Cosmos DB (Mongo API) account (`devdataextwucosmos0`).

2. Open **Data Explorer** from the left menu.

    ![](../media/Lab-04/image08.png)

3. Expand the **data-extraction-db** database and click on the **Configurations** collection.

4. Click on **Documents** to view the stored configuration document. You should see a document with `_id: "document-extraction-v1.0"`.

    ![](../media/Lab-04/image09.png)

5. Expand the document and review the stored fields:

    - **name** — `document-extraction`
    - **version** — `v1.0`
    - **prompt** — The system prompt for Azure OpenAI
    - **collection_rows** — Complete field schemas and analyzer ID
    - **lease_config_hash** — The SHA-256 hash of the extraction configuration

    ![](../media/Lab-04/image10.png)

>**Note:** The `lease_config_hash` is a critical component. When documents are ingested, they are associated with this hash. If the extraction configuration changes, a new hash is generated, and documents need to be re-ingested to ensure consistency.

# Document Ingestion with Azure Content Understanding

Now that the extraction configuration is uploaded and the CU analyzer is created, you can ingest documents. The ingestion pipeline sends PDF documents to Azure Content Understanding, extracts structured fields, and stores the results in Cosmos DB.

## Task 4: Review the ingestion pipeline code

In this task, you will trace the code path for document ingestion to understand how the system processes documents.

1. In VS Code, open the file **src/routes/api/v1/ingest_documents_routes.py**. This defines the HTTP trigger for document ingestion:

    ```
    POST /api/ingest-documents/{collection_id}/{lease_id}/{document_name}
    ```

    ![](../media/Lab-04/image11.png)

2. Open **src/controllers/ingest_lease_documents_controller.py**. Review the `ingest_documents()` method. It performs these steps:

    a. Loads the extraction configuration from Cosmos DB.

    b. Checks if the document has already been ingested (deduplication by collection ID + lease ID + filename + config hash).

    c. Sends the PDF binary to Azure Content Understanding via `begin_analyze_data()`.

    d. Polls the CU operation until it completes via `poll_result()`.

    e. Calls the ingestion service to process and store the results.

    ![](../media/Lab-04/image12.png)

3. Open **src/services/azure_content_understanding_client.py**. Review the key methods:

    - `begin_analyze_data(analyzer_id, file_bytes)` — Sends the PDF binary to the CU analyzer and returns an operation URL.
    - `poll_result(operation_url)` — Polls the operation URL until the status is "succeeded" or "failed".

    ![](../media/Lab-04/image13.png)

4. Open **src/services/ingest_lease_documents_service.py**. Review `ingest_analyzer_output()` which:

    a. Acquires a distributed MongoDB lock on the document.

    b. Gets or creates the collection document in Cosmos DB (keyed by `{collection_id}-{config_hash}`).

    c. Gets or creates the lease entry within the collection.

    d. Uploads the markdown representation to Azure Blob Storage.

    e. Extracts fields with bounding boxes, confidence scores, and source pages.

    f. Upserts the complete document to the Cosmos DB "Documents" collection.

    g. Releases the lock.

    ![](../media/Lab-04/image14.png)

## Task 5: Ingest a sample lease agreement document

In this task, you will send the sample lease agreement PDF to the ingestion endpoint and observe the extraction process.

1. In the terminal, run the following **curl** command to ingest the sample lease agreement:

    ```
    curl -X POST "http://localhost:7071/api/ingest-documents/Collection1/Lease1/MicrosoftLeaseAgreement" ^
      -H "Content-Type: application/octet-stream" ^
      --data-binary @document_samples/Agreement_for_leasing_or_renting_certain_Microsoft_Software_Products.pdf
    ```

    ![](../media/Lab-04/image15.png)

2. Switch to the terminal tab running the Function App. Observe the log output showing the ingestion process:

    - Configuration loaded from Cosmos DB
    - Document sent to Azure Content Understanding
    - Polling for extraction completion
    - Fields extracted with confidence scores
    - Data stored in Cosmos DB
    - Markdown uploaded to Blob Storage

    ![](../media/Lab-04/image16.png)

3. Wait for the response. A successful ingestion returns a **200 OK** status.

    ![](../media/Lab-04/image17.png)

4. Alternatively, use the REST Client. Open **src/samples/ingest_doc_sample.http** and click **Send Request** on the local POST request.

    ![](../media/Lab-04/image18.png)

>**Note:** The first ingestion call may take **30-60 seconds** as Azure Content Understanding processes the document. Subsequent calls for already-ingested documents will return immediately due to the deduplication check.

## Task 6: Verify extracted data in Cosmos DB

In this task, you will inspect the extracted document data stored in Cosmos DB.

1. Navigate to the **Azure Portal** and open your Cosmos DB (Mongo API) account (`devdataextwucosmos0`).

2. Open **Data Explorer** and expand the **data-extraction-db** database.

3. Click on the **Documents** collection. You should see a new document with an ID following the pattern `Collection1-{config_hash}`.

    ![](../media/Lab-04/image19.png)

4. Click on the document to expand it. Review the structure:

    ```json
    {
      "_id": "Collection1-{hash}",
      "config_id": "document-extraction-v1.0",
      "lease_config_hash": "{hash}",
      "information": {
        "entities": [
          {
            "name": "Lease1",
            "original_documents": ["MicrosoftLeaseAgreement"],
            "markdowns": ["Collections/Collection1/Lease1/MicrosoftLeaseAgreement.md"],
            "fields": {
              "license_grant_scope": [...],
              "lease_duration": [...],
              "termination_conditions": [...],
              "compliance_audit_terms": [...],
              "prohibited_uses": [...]
            }
          }
        ]
      }
    }
    ```

    ![](../media/Lab-04/image20.png)

## Task 7: Explore extracted fields, bounding boxes, and confidence scores

In this task, you will examine the individual extracted field values and their metadata.

1. In the Cosmos DB Data Explorer, expand the **fields** object within the lease entity.

2. Click on **license_grant_scope** to see the extracted value. Each field contains:

    ```json
    {
      "type": "string",
      "valueString": "The license grants the right to use Microsoft software products...",
      "spans": [
        {
          "offset": 1234,
          "length": 156
        }
      ],
      "confidence": 0.932,
      "source": "D(3,1.2567,4.5678,6.7890,4.5678,6.7890,5.1234,1.2567,5.1234)",
      "document": "MicrosoftLeaseAgreement",
      "markdown": "Collections/Collection1/Lease1/MicrosoftLeaseAgreement.md",
      "date_of_document": null
    }
    ```

    ![](../media/Lab-04/image21.png)

3. Understand each metadata field:

    - **valueString** — The actual extracted text value from the document.
    - **spans** — Character offset and length in the document's markdown representation.
    - **confidence** — A score between 0 and 1 indicating how confident Azure Content Understanding is in the extraction. Values above 0.9 are highly reliable.
    - **source** — Bounding box coordinates in the format `D(page, x1, y1, x2, y2, ...)` specifying the exact location of the text in the original PDF.
    - **document** — The source document filename.
    - **markdown** — The blob storage path to the document's markdown representation.

4. Review the remaining extracted fields:

    - **lease_duration** — The duration of the lease agreement.
    - **termination_conditions** — Conditions under which the agreement can be terminated.
    - **compliance_audit_terms** — Audit rights and compliance verification terms.
    - **prohibited_uses** — Restrictions and forbidden activities.

    ![](../media/Lab-04/image22.png)

5. Compare the confidence scores across fields. Fields that have clear, unambiguous language in the source document will typically have higher confidence scores (above 0.9), while fields requiring interpretation may have lower scores.

## Task 8: Verify markdown storage in Azure Blob Storage

In this task, you will verify that the document's markdown representation was uploaded to Azure Blob Storage.

1. In the Azure Portal, navigate to your **Storage Account** (`devdataextwuSa0`).

2. Open **Containers** from the left menu and click on the **processed** container.

    ![](../media/Lab-04/image23.png)

3. Navigate through the folder hierarchy: **Collections** → **Collection1** → **Lease1**.

4. You should see the markdown file **MicrosoftLeaseAgreement.md**.

    ![](../media/Lab-04/image24.png)

5. Click on the markdown file and select **Edit** to preview its contents. This is the full-text markdown representation of the PDF document generated by Azure Content Understanding.

    ![](../media/Lab-04/image25.png)

>**Note:** The markdown representation is used as the reference format for the document. It preserves the text content while being more machine-readable than the original PDF. The bounding box coordinates in each extracted field reference specific positions in the original PDF for precise traceability.

# Summary

In this lab, you reviewed and uploaded the extraction configuration, which created an Azure Content Understanding analyzer. You then ingested a sample lease agreement document through the REST API and observed how Azure Content Understanding extracts structured fields (license grant scope, lease duration, termination conditions, compliance audit terms, and prohibited uses) with confidence scores and bounding box coordinates. You verified the extracted data in Cosmos DB and confirmed the markdown document was stored in Azure Blob Storage.

In the next lab, you will query the ingested documents using natural language and deploy the solution to Azure.

# References

Data Extraction Using Azure Content Understanding introduces you to building an intelligent document processing solution on Azure. Here are resources to help you continue learning:

- Read the [Azure Content Understanding documentation](https://learn.microsoft.com/en-us/azure/ai-services/content-understanding/)

- Explore the [Azure OpenAI Service documentation](https://docs.microsoft.com/azure/cognitive-services/openai/)

- Review the [Azure Functions Python Developer Guide](https://docs.microsoft.com/azure/azure-functions/functions-reference-python)

- Learn about [Azure Cosmos DB](https://docs.microsoft.com/azure/cosmos-db/)

- Explore the [Terraform AzureRM Provider documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

- Read about [Semantic Kernel](https://learn.microsoft.com/en-us/semantic-kernel/overview/)

- Understand [Azure Key Vault secrets management](https://learn.microsoft.com/en-us/azure/key-vault/secrets/about-secrets)

- Learn about [Azure Blob Storage](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-blobs-introduction)

- Review [Azure Application Insights](https://learn.microsoft.com/en-us/azure/azure-monitor/app/app-insights-overview)

- Explore [Azure AI Foundry](https://learn.microsoft.com/en-us/azure/ai-studio/what-is-ai-studio)

© 2026 Microsoft Corporation. All rights reserved.

By using this demo/lab, you agree to the following terms:

The technology/functionality described in this demo/lab is provided by Microsoft Corporation for purposes of obtaining your feedback and to provide you with a learning experience. You may only use the demo/lab to evaluate such technology features and functionality and provide feedback to Microsoft. You may not use it for any other purpose. You may not modify, copy, distribute, transmit, display, perform, reproduce, publish, license, create derivative works from, transfer, or sell this demo/lab or any portion thereof.

COPYING OR REPRODUCTION OF THE DEMO/LAB (OR ANY PORTION OF IT) TO ANY OTHER SERVER OR LOCATION FOR FURTHER REPRODUCTION OR REDISTRIBUTION IS EXPRESSLY PROHIBITED.

THIS DEMO/LAB PROVIDES CERTAIN SOFTWARE TECHNOLOGY/PRODUCT FEATURES AND FUNCTIONALITY, INCLUDING POTENTIAL NEW FEATURES AND CONCEPTS, IN A SIMULATED ENVIRONMENT WITHOUT COMPLEX SET-UP OR INSTALLATION FOR THE PURPOSE DESCRIBED ABOVE. THE TECHNOLOGY/CONCEPTS REPRESENTED IN THIS DEMO/LAB MAY NOT REPRESENT FULL FEATURE FUNCTIONALITY AND MAY NOT WORK THE WAY A FINAL VERSION MAY WORK. WE ALSO MAY NOT RELEASE A FINAL VERSION OF SUCH FEATURES OR CONCEPTS. YOUR EXPERIENCE WITH USING SUCH FEATURES AND FUNCTIONALITY IN A PHYSICAL ENVIRONMENT MAY ALSO BE DIFFERENT.

**FEEDBACK**. If you give feedback about the technology features, functionality and/or concepts described in this demo/lab to Microsoft, you give to Microsoft, without charge, the right to use, share and commercialize your feedback in any way and for any purpose. You also give to third parties, without charge, any patent rights needed for their products, technologies and services to use or interface with any specific parts of a Microsoft software or service that includes the feedback. You will not give feedback that is subject to a license that requires Microsoft to license its software or documentation to third parties because we include your feedback in them. These rights survive this agreement.

MICROSOFT CORPORATION HEREBY DISCLAIMS ALL WARRANTIES AND CONDITIONS WITH REGARD TO THE DEMO/LAB, INCLUDING ALL WARRANTIES AND CONDITIONS OF MERCHANTABILITY, WHETHER EXPRESS, IMPLIED OR STATUTORY, FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. MICROSOFT DOES NOT MAKE ANY ASSURANCES OR REPRESENTATIONS WITH REGARD TO THE ACCURACY OF THE RESULTS, OUTPUT THAT DERIVES FROM USE OF DEMO/ LAB, OR SUITABILITY OF THE INFORMATION CONTAINED IN THE DEMO/LAB FOR ANY PURPOSE.

**DISCLAIMER**

This demo/lab contains only a portion of new features and enhancements in Microsoft Azure. Some of the features might change in future releases of the product. In this demo/lab, you will learn about some of the new features but not all of the new features.
