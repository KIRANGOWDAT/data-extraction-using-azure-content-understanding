# Exercise 4: Document Extraction Configuration and Ingestion

### Estimated Duration: 75 Minutes

## Overview

In this exercise, you will configure the document extraction pipeline and ingest your first document using Azure Content Understanding. You will upload a JSON configuration that defines the fields to extract from lease agreements, then process a sample PDF through the ingestion API. Finally, you will explore the extracted structured data — including fields, confidence scores, and bounding box coordinates — stored in Azure Cosmos DB, and verify the markdown representation in Azure Blob Storage.

## Objectives

In this exercise, you will complete the following tasks:

- Task 1: Review the extraction configuration schema
- Task 2: Upload the extraction configuration via API
- Task 3: Verify the configuration in Cosmos DB
- Task 4: Review the ingestion pipeline code
- Task 5: Ingest a sample lease agreement document
- Task 6: Verify extracted data in Cosmos DB
- Task 7: Explore extracted fields, bounding boxes, and confidence scores
- Task 8: Verify markdown storage in Azure Blob Storage

### Task 1: Review the extraction configuration schema

In this task, you will examine the extraction configuration JSON file and understand each component.

1. Ensure the Azure Function App is running locally from Exercise 3. If not, open a terminal, activate the virtual environment, and start it:

   ```
   cd C:\LabFiles\data-extraction-using-azure-content-understanding
   .venv\Scripts\activate
   func start --script-root ./src/
   ```

1. In VS Code Explorer, expand the **configs** **(1)** folder and click on **document-extraction-v1.0.json** **(2)** to open it.

   ![](../media/Lab-04/image02.png)

1. Review the top-level structure of the configuration:

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

1. Examine the **collection_rows** array. Each row defines a document type and its extraction fields:

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
           ...
       ],
       "analyzer_id": "test-analyzer"
   }
   ```

   ![](../media/Lab-04/image03.png)

1. Understand each field property:

   | Property | Description |
   |---|---|
   | **name** | Field name in the extracted output (e.g., `license_grant_scope`) |
   | **type** | Data type: `string`, `integer`, `float`, `boolean`, `date`, `datetime`, `time`, `object`, or `array` |
   | **description** | Human-readable description that helps Azure Content Understanding understand what to extract |
   | **method** | `extract` (CU extracts from document) or `generate` (LLM generates the value) |
   | **analyzer_id** | The Azure Content Understanding analyzer name created for this configuration |

### Task 2: Upload the extraction configuration via API

In this task, you will upload the configuration to the running Function App, which stores it in Cosmos DB and creates the corresponding Content Understanding analyzer.

1. Open a **new terminal tab** (**Ctrl+Shift+`**) while keeping the Function App running.

1. Activate the virtual environment in the new terminal:

   ```
   cd C:\LabFiles\data-extraction-using-azure-content-understanding
   .venv\Scripts\activate
   ```

1. Upload the extraction configuration using **curl**:

   ```
   curl -X PUT "http://localhost:7071/api/configs/document-extraction/versions/v1.0" ^
     -H "Content-Type: application/json" ^
     -d @configs/document-extraction-v1.0.json
   ```

   ![](../media/Lab-04/image04.png)

1. You should receive a **201 Created** response with a **Location** header pointing to the created resource.

   ![](../media/Lab-04/image05.png)

1. Alternatively, use the **REST Client** extension. Open the file **src/samples/config_update_sample.http** **(1)** and click **Send Request** **(2)** on the local PUT request line.

   ![](../media/Lab-04/image06.png)

1. Behind the scenes, the upload process performs these actions:

   1. **Validates** the JSON configuration against the expected Pydantic schema.
   1. **Creates an Azure Content Understanding analyzer** by calling the `begin_create_analyzer()` API with a template built from the field schema.
   1. **Computes a SHA-256 hash** of the extraction configuration for versioning and deduplication.
   1. **Upserts** the configuration document to the Cosmos DB "Configurations" collection.

1. Verify the configuration was stored by retrieving it:

   ```
   curl http://localhost:7071/api/configs/document-extraction/versions/v1.0
   ```

   You should see the full configuration JSON returned, including the computed `extraction_config_hash`.

   ![](../media/Lab-04/image07.png)

### Task 3: Verify the configuration in Cosmos DB

In this task, you will navigate to Cosmos DB in the Azure Portal and inspect the stored configuration document.

1. Open the **Azure Portal** and navigate to your Cosmos DB (Mongo API) account **(1)** (`devdataextwucosmos0`).

1. Open **Data Explorer** **(1)** from the left menu.

   ![](../media/Lab-04/image08.png)

1. Expand the **data-extraction-db** **(1)** database and click on the **Configurations** **(2)** collection.

1. Click on **Documents** **(1)** to view the stored configuration document. You should see a document with `_id: "document-extraction-v1.0"`.

   ![](../media/Lab-04/image09.png)

1. Expand the document and review the stored fields:

   - **name** — `document-extraction`
   - **version** — `v1.0`
   - **prompt** — The system prompt for Azure OpenAI
   - **collection_rows** — Complete field schemas and analyzer ID
   - **lease_config_hash** — The SHA-256 hash of the extraction configuration

   ![](../media/Lab-04/image10.png)

   >**Note:** The `lease_config_hash` is a critical component. When documents are ingested, they are associated with this hash. If the extraction configuration changes, a new hash is generated, and documents need to be re-ingested to ensure consistency.

### Task 4: Review the ingestion pipeline code

In this task, you will trace the code path for document ingestion to understand how the system processes documents.

1. In VS Code, open the file **src/routes/api/v1/ingest_documents_routes.py** **(1)**. This defines the HTTP trigger for document ingestion:

   ```
   POST /api/ingest-documents/{collection_id}/{lease_id}/{document_name}
   ```

   ![](../media/Lab-04/image11.png)

1. Open **src/controllers/ingest_lease_documents_controller.py** **(1)**. Review the `ingest_documents()` method, which performs these steps:

   1. Loads the extraction configuration from Cosmos DB.
   1. Checks if the document has already been ingested (deduplication by collection ID + lease ID + filename + config hash).
   1. Sends the PDF binary to Azure Content Understanding via `begin_analyze_data()`.
   1. Polls the CU operation until completion via `poll_result()`.
   1. Calls the ingestion service to process and store the results.

   ![](../media/Lab-04/image12.png)

1. Open **src/services/azure_content_understanding_client.py** **(1)**. Review the key methods:

   - `begin_analyze_data(analyzer_id, file_bytes)` — Sends the PDF binary to the CU analyzer and returns an operation URL.
   - `poll_result(operation_url)` — Polls the operation URL until the status is "succeeded" or "failed".

   ![](../media/Lab-04/image13.png)

1. Open **src/services/ingest_lease_documents_service.py** **(1)**. Review `ingest_analyzer_output()` which:

   1. Acquires a distributed MongoDB lock on the document.
   1. Gets or creates the collection document in Cosmos DB (keyed by `{collection_id}-{config_hash}`).
   1. Gets or creates the lease entry within the collection.
   1. Uploads the markdown representation to Azure Blob Storage.
   1. Extracts fields with bounding boxes, confidence scores, and source pages.
   1. Upserts the complete document to the Cosmos DB "Documents" collection.
   1. Releases the lock.

   ![](../media/Lab-04/image14.png)

### Task 5: Ingest a sample lease agreement document

In this task, you will send the sample lease agreement PDF to the ingestion endpoint and observe the extraction process.

1. In the terminal, run the following **curl** command to ingest the sample lease agreement:

   ```
   curl -X POST "http://localhost:7071/api/ingest-documents/Collection1/Lease1/MicrosoftLeaseAgreement" ^
     -H "Content-Type: application/octet-stream" ^
     --data-binary @document_samples/Agreement_for_leasing_or_renting_certain_Microsoft_Software_Products.pdf
   ```

   ![](../media/Lab-04/image15.png)

1. Switch to the terminal tab running the Function App. Observe the log output showing the ingestion process:

   - Configuration loaded from Cosmos DB
   - Document sent to Azure Content Understanding
   - Polling for extraction completion
   - Fields extracted with confidence scores
   - Data stored in Cosmos DB
   - Markdown uploaded to Blob Storage

   ![](../media/Lab-04/image16.png)

1. Wait for the response. A successful ingestion returns a **200 OK** status.

   ![](../media/Lab-04/image17.png)

1. Alternatively, use the **REST Client** extension. Open **src/samples/ingest_doc_sample.http** **(1)** and click **Send Request** **(2)** on the local POST request.

   ![](../media/Lab-04/image18.png)

   >**Note:** The first ingestion call may take **30–60 seconds** as Azure Content Understanding processes the document. Subsequent calls for already-ingested documents return immediately due to the deduplication check.

### Task 6: Verify extracted data in Cosmos DB

In this task, you will inspect the extracted document data stored in Cosmos DB.

1. Navigate to the **Azure Portal** and open your Cosmos DB (Mongo API) account **(1)** (`devdataextwucosmos0`).

1. Open **Data Explorer** **(1)** and expand the **data-extraction-db** **(2)** database.

1. Click on the **Documents** **(1)** collection. You should see a new document with an ID following the pattern `Collection1-{config_hash}`.

   ![](../media/Lab-04/image19.png)

1. Click on the document to expand it. Review the structure:

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

### Task 7: Explore extracted fields, bounding boxes, and confidence scores

In this task, you will examine the individual extracted field values and their metadata.

1. In the Cosmos DB Data Explorer, expand the **fields** **(1)** object within the lease entity.

1. Click on **license_grant_scope** **(1)** to see the extracted value. Each field contains:

   ```json
   {
     "type": "string",
     "valueString": "The license grants the right to use Microsoft software products...",
     "spans": [{ "offset": 1234, "length": 156 }],
     "confidence": 0.932,
     "source": "D(3,1.2567,4.5678,6.7890,4.5678,6.7890,5.1234,1.2567,5.1234)",
     "document": "MicrosoftLeaseAgreement",
     "markdown": "Collections/Collection1/Lease1/MicrosoftLeaseAgreement.md"
   }
   ```

   ![](../media/Lab-04/image21.png)

1. Understand each metadata field:

   | Field | Description |
   |---|---|
   | **valueString** | Actual extracted text value from the document |
   | **spans** | Character offset and length in the document's markdown representation |
   | **confidence** | Score between 0 and 1 indicating extraction reliability (above 0.9 is highly reliable) |
   | **source** | Bounding box coordinates `D(page, x1, y1, x2, y2, ...)` — exact location in the original PDF |
   | **document** | Source document filename |
   | **markdown** | Blob storage path to the document's markdown representation |

1. Review the remaining extracted fields:

   - **lease_duration** — Duration of the lease agreement
   - **termination_conditions** — Conditions under which the agreement can be terminated
   - **compliance_audit_terms** — Audit rights and compliance verification terms
   - **prohibited_uses** — Restrictions and forbidden activities

   ![](../media/Lab-04/image22.png)

1. Compare the confidence scores across fields. Fields with clear, unambiguous language typically have higher scores (above 0.9), while fields requiring interpretation may have lower scores.

### Task 8: Verify markdown storage in Azure Blob Storage

In this task, you will verify that the document's markdown representation was uploaded to Azure Blob Storage.

1. In the Azure Portal, navigate to your **Storage Account** **(1)** (`devdataextwuSa0`).

1. Open **Containers** **(1)** from the left menu and click on the **processed** **(2)** container.

   ![](../media/Lab-04/image23.png)

1. Navigate through the folder hierarchy: **Collections** **(1)** → **Collection1** **(2)** → **Lease1** **(3)**.

1. You should see the markdown file **MicrosoftLeaseAgreement.md** **(1)**.

   ![](../media/Lab-04/image24.png)

1. Click on the markdown file and select **Edit** **(1)** to preview its contents. This is the full-text markdown representation of the PDF document generated by Azure Content Understanding.

   ![](../media/Lab-04/image25.png)

   >**Note:** The markdown representation preserves the text content while being more machine-readable than the original PDF. The bounding box coordinates in each extracted field reference specific positions in the original PDF for precise traceability.

## Summary

In this exercise, you have completed the following:

1. Reviewed the **extraction configuration schema** and understood field definitions, types, and methods.
2. Uploaded the **extraction configuration** via the API, which created an Azure Content Understanding analyzer.
3. Verified the **configuration document** stored in Cosmos DB with its SHA-256 hash.
4. Traced the **ingestion pipeline code** across routes, controllers, services, and the CU client.
5. Ingested a **sample lease agreement PDF** through the REST API.
6. Verified the **extracted structured data** in Cosmos DB (collection and lease entities).
7. Explored **extracted fields** with confidence scores, bounding boxes, and source document references.
8. Confirmed the **markdown representation** was uploaded to Azure Blob Storage.

### You have successfully completed this exercise. Click **Next >>** to proceed to the next exercise.

© 2026 Microsoft Corporation. All rights reserved.

By using this demo/lab, you agree to the following terms:

The technology/functionality described in this demo/lab is provided by Microsoft Corporation for purposes of obtaining your feedback and to provide you with a learning experience. You may only use the demo/lab to evaluate such technology features and functionality and provide feedback to Microsoft. You may not use it for any other purpose. You may not modify, copy, distribute, transmit, display, perform, reproduce, publish, license, create derivative works from, transfer, or sell this demo/lab or any portion thereof.

COPYING OR REPRODUCTION OF THE DEMO/LAB (OR ANY PORTION OF IT) TO ANY OTHER SERVER OR LOCATION FOR FURTHER REPRODUCTION OR REDISTRIBUTION IS EXPRESSLY PROHIBITED.

THIS DEMO/LAB PROVIDES CERTAIN SOFTWARE TECHNOLOGY/PRODUCT FEATURES AND FUNCTIONALITY, INCLUDING POTENTIAL NEW FEATURES AND CONCEPTS, IN A SIMULATED ENVIRONMENT WITHOUT COMPLEX SET-UP OR INSTALLATION FOR THE PURPOSE DESCRIBED ABOVE. THE TECHNOLOGY/CONCEPTS REPRESENTED IN THIS DEMO/LAB MAY NOT REPRESENT FULL FEATURE FUNCTIONALITY AND MAY NOT WORK THE WAY A FINAL VERSION MAY WORK. WE ALSO MAY NOT RELEASE A FINAL VERSION OF SUCH FEATURES OR CONCEPTS. YOUR EXPERIENCE WITH USING SUCH FEATURES AND FUNCTIONALITY IN A PHYSICAL ENVIRONMENT MAY ALSO BE DIFFERENT.

**FEEDBACK**. If you give feedback about the technology features, functionality and/or concepts described in this demo/lab to Microsoft, you give to Microsoft, without charge, the right to use, share and commercialize your feedback in any way and for any purpose. You also give to third parties, without charge, any patent rights needed for their products, technologies and services to use or interface with any specific parts of a Microsoft software or service that includes the feedback. You will not give feedback that is subject to a license that requires Microsoft to license its software or documentation to third parties because we include your feedback in them. These rights survive this agreement.

MICROSOFT CORPORATION HEREBY DISCLAIMS ALL WARRANTIES AND CONDITIONS WITH REGARD TO THE DEMO/LAB, INCLUDING ALL WARRANTIES AND CONDITIONS OF MERCHANTABILITY, WHETHER EXPRESS, IMPLIED OR STATUTORY, FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. MICROSOFT DOES NOT MAKE ANY ASSURANCES OR REPRESENTATIONS WITH REGARD TO THE ACCURACY OF THE RESULTS, OUTPUT THAT DERIVES FROM USE OF DEMO/ LAB, OR SUITABILITY OF THE INFORMATION CONTAINED IN THE DEMO/LAB FOR ANY PURPOSE.

**DISCLAIMER**

This demo/lab contains only a portion of new features and enhancements in Microsoft Azure. Some of the features might change in future releases of the product. In this demo/lab, you will learn about some of the new features but not all of the new features.
