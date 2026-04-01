# Exercise 5: Querying Documents and Deploying to Azure

### Estimated Duration: 75 Minutes

## Overview

In this exercise, you will use the natural language query interface to ask questions about the lease agreement extracted in Exercise 4. You will explore how Azure OpenAI (powered by Semantic Kernel) processes your queries, retrieves data from Cosmos DB, and returns responses with inline citations that trace back to specific pages and bounding boxes in the original PDF. You will also test chat history for multi-turn conversations, explore the citation aliasing optimization, deploy the Function App to Azure, monitor it with Application Insights, and run the project test suite.

## Objectives

In this exercise, you will complete the following tasks:

- Task 1: Understand the query pipeline and Semantic Kernel
- Task 2: Query ingested documents using the API
- Task 3: Explore citations and source references
- Task 4: Test chat history and session management
- Task 5: Explore the citation aliasing optimization
- Task 6: Deploy the Function App to Azure
- Task 7: Test the deployed API endpoints
- Task 8: Monitor the application with Application Insights
- Task 9: Run the test suite

### Task 1: Understand the query pipeline and Semantic Kernel

In this task, you will trace the query pipeline code to understand how natural language queries are processed.

1. Ensure the Azure Function App is running locally from the previous exercise. If not, start it:

   ```
   cd C:\LabFiles\data-extraction-using-azure-content-understanding
   .venv\Scripts\activate
   func start --script-root ./src/
   ```

1. In VS Code, open the file **src/controllers/inference_controller.py** **(1)**. Review the `query()` method:

   ![](../media/Lab-05/image02.png)

1. The query process follows these steps:

   1. **Load configuration** — The extraction configuration is loaded from Cosmos DB to obtain the system prompt.
   1. **Create CollectionPlugin** — A Semantic Kernel plugin is instantiated that can retrieve collection data from Cosmos DB.
   1. **Check message limit** — Verifies the session hasn't exceeded the 20-message limit.
   1. **Call LLM** — Invokes `answer_collection_question()` which uses Semantic Kernel to call Azure OpenAI.
   1. **Store chat history** — Saves the conversation to Cosmos DB (SQL API) for multi-turn support.
   1. **Return response** — Returns the LLM response with resolved citations and token usage metrics.

1. Open **src/services/llm_request_manager.py** **(1)**. Review the `answer_collection_question()` method:

   ![](../media/Lab-05/image03.png)

1. Key implementation details:

   - The method creates a Semantic Kernel **Kernel** instance and registers the **CollectionPlugin**.
   - **FunctionChoiceBehavior.Required** forces the LLM to call the `get_collection_data` tool — it cannot answer without first retrieving the actual data.
   - **response_format = GeneratedResponse** enforces structured output — the LLM must return a JSON object with `response` (text) and `citations` (list of alias references).
   - After the LLM responds, citation aliases are resolved back to actual document paths and bounding box coordinates.

1. Open **src/services/collection_kernel_plugin.py** **(1)**. Review the `get_collection_data()` method decorated with `@kernel_function`:

   ![](../media/Lab-05/image04.png)

1. This Semantic Kernel plugin method:

   1. Fetches all extracted fields for the collection from Cosmos DB.
   1. Builds a structured `DocumentData` object.
   1. Processes the data through the **CitationMapper**, which replaces verbose citation data with compact aliases like `CITE{collection_id}-A`, `CITE{collection_id}-B`.
   1. Caches the result with a 24-hour TTL to avoid repeated database calls.
   1. Returns the optimized JSON string to the LLM context.

### Task 2: Query ingested documents using the API

In this task, you will send natural language queries to the API and examine the responses.

1. Open a **new terminal tab** (**Ctrl+Shift+`**) and run the following curl command to query the ingested lease agreement:

   ```
   curl -X POST "http://localhost:7071/api/v1/query" ^
     -H "Content-Type: application/json" ^
     -H "x-user: labuser@contoso.com" ^
     -d "{\"cid\": \"Collection1\", \"sid\": \"session1\", \"query\": \"What are the termination conditions for Lease1?\"}"
   ```

   ![](../media/Lab-05/image05.png)

1. Review the response structure:

   ```json
   {
     "response": "The lease agreement can be terminated under the following conditions: [1]...",
     "citations": [
       [
         "Collections/Collection1/Lease1/MicrosoftLeaseAgreement",
         "D(5,1.2567,4.5678,6.7890,4.5678,6.7890,5.1234,1.2567,5.1234)"
       ]
     ],
     "metrics": {
       "prompt_tokens": 1250,
       "completion_tokens": 180,
       "total_tokens": 1430,
       "total_latency_sec": 3.45
     }
   }
   ```

   ![](../media/Lab-05/image06.png)

1. Understand each part of the response:

   | Field | Description |
   |---|---|
   | **response** | Natural language answer with inline citation markers `[1]`, `[2]`, etc. |
   | **citations** | Array where each item is `[source_document_path, bounding_box_coordinates]` |
   | **metrics** | Token usage and latency for monitoring costs |

1. Try another query about the lease scope:

   ```
   curl -X POST "http://localhost:7071/api/v1/query" ^
     -H "Content-Type: application/json" ^
     -H "x-user: labuser@contoso.com" ^
     -d "{\"cid\": \"Collection1\", \"sid\": \"session1\", \"query\": \"What is the scope of the license grant?\"}"
   ```

   ![](../media/Lab-05/image07.png)

1. Try a more analytical query:

   ```
   curl -X POST "http://localhost:7071/api/v1/query" ^
     -H "Content-Type: application/json" ^
     -H "x-user: labuser@contoso.com" ^
     -d "{\"cid\": \"Collection1\", \"sid\": \"session1\", \"query\": \"Are there any prohibited uses? List them all.\"}"
   ```

   ![](../media/Lab-05/image08.png)

1. Alternatively, use the **REST Client** extension. Open **src/samples/query_api_sample.http** **(1)** and modify the local query request with your collection ID. Click **Send Request** **(2)**.

   ![](../media/Lab-05/image09.png)

### Task 3: Explore citations and source references

In this task, you will understand how citations trace back to the original document.

1. Examine the `citations` array from your previous query response. Each citation contains two elements:

   - **Source document path** — e.g., `Collections/Collection1/Lease1/MicrosoftLeaseAgreement` — identifies the document and its blob storage location.
   - **Bounding box** — e.g., `D(5,1.2567,4.5678,...)` — specifies the page number and exact coordinates on the PDF page.

1. The bounding box format is `D(page, x1, y1, x2, y2, x3, y3, x4, y4)` where:

   | Component | Description |
   |---|---|
   | **page** | Page number in the PDF (1-indexed) |
   | **x1,y1 → x4,y4** | Four corner coordinates of the bounding polygon |

   ![](../media/Lab-05/image10.png)

1. This traceability is critical for enterprise use cases — the system not only provides the answer but identifies the **exact location** on the **exact page** of the **exact document** where that information was found.

1. Open the original PDF at **document_samples/Agreement_for_leasing_or_renting_certain_Microsoft_Software_Products.pdf** **(1)** and navigate to the page referenced in the citation to verify the bounding box matches the relevant text.

   ![](../media/Lab-05/image11.png)

### Task 4: Test chat history and session management

In this task, you will observe how the system maintains conversational context across multiple queries within a session.

1. Start a new session by using a different session ID and ask a broad question:

   ```
   curl -X POST "http://localhost:7071/api/v1/query" ^
     -H "Content-Type: application/json" ^
     -H "x-user: labuser@contoso.com" ^
     -d "{\"cid\": \"Collection1\", \"sid\": \"session2\", \"query\": \"Tell me about the compliance audit terms.\"}"
   ```

   ![](../media/Lab-05/image12.png)

1. Now ask a follow-up question in the **same session** that relies on context:

   ```
   curl -X POST "http://localhost:7071/api/v1/query" ^
     -H "Content-Type: application/json" ^
     -H "x-user: labuser@contoso.com" ^
     -d "{\"cid\": \"Collection1\", \"sid\": \"session2\", \"query\": \"Can you elaborate on the audit frequency mentioned?\"}"
   ```

   ![](../media/Lab-05/image13.png)

1. Notice that the LLM maintains context from the previous question. It knows "the audit frequency mentioned" refers to the compliance audit terms discussed earlier. This is powered by the **chat history** stored in the Cosmos DB SQL API.

1. Navigate to the Azure Portal, open the Cosmos DB SQL API account **(1)** (`devdataextwucosmoskb0`), and open **Data Explorer** **(2)**.

1. Expand **knowledge-base-db** **(1)** → **chat-history** **(2)** and browse the stored conversation documents. You should see entries for your session with both user messages and assistant responses.

   ![](../media/Lab-05/image14.png)

1. Note that the system has a **20-message limit** per session. After 20 messages, subsequent queries return an HTTP 400 error. Start a new session ID to continue querying.

   >**Note:** Chat history stores messages with inline citations stripped from assistant responses (using the citation cleaner utility) to keep stored context clean. Tool call messages are also filtered out from retrieved history.

### Task 5: Explore the citation aliasing optimization

In this task, you will understand the token optimization technique that reduces LLM costs.

1. Open **src/services/citation_mapper.py** **(1)** in VS Code.

   ![](../media/Lab-05/image15.png)

1. The `process_json()` method performs citation aliasing:

   1. Iterates through all extracted fields in the collection data.
   1. Replaces verbose `source_document` and `source_bounding_boxes` values with compact aliases like `CITE{collection_id}-A`.
   1. Removes the `type` field from each entry (not needed by the LLM).
   1. Builds a reverse mapping dictionary to restore real citations after the LLM responds.

1. This optimization achieves approximately **50% reduction** in input/output tokens, significantly reducing Azure OpenAI API costs:

   | Before | After |
   |---|---|
   | `"source_document": "Collections/Collection1/Lease1/MicrosoftLeaseAgreement"` | `"source": "CITECollection1-A"` |
   | `"source_bounding_boxes": "D(5,1.2567,4.5678,...)"` | (removed, stored in mapping) |

1. After the LLM generates a response with alias references, the `restore_citations()` method in **collection_kernel_plugin.py** maps them back to real document paths and bounding box coordinates.

   ![](../media/Lab-05/image16.png)

1. Open the file **docs/design/decisions/alias-names-vs-real-citation.md** **(1)** to read the full architecture decision record behind this optimization.

   ![](../media/Lab-05/image17.png)

### Task 6: Deploy the Function App to Azure

In this task, you will deploy the local Function App code to the Azure Function App provisioned by Terraform.

1. Open a terminal and ensure you are in the project root with the virtual environment activated:

   ```
   cd C:\LabFiles\data-extraction-using-azure-content-understanding
   .venv\Scripts\activate
   ```

1. Stop the locally running Function App by pressing **Ctrl+C** in the terminal running `func start`.

1. Deploy the Function App to Azure using Azure Functions Core Tools:

   ```
   func azure functionapp publish devdataextwufunc0 --python --script-root ./src/
   ```

   ![](../media/Lab-05/image18.png)

1. Wait for the deployment to complete. You should see output confirming:

   - Function app files packaged and uploaded
   - Remote build completed
   - Syncing triggers
   - Function URLs listed

   ![](../media/Lab-05/image19.png)

1. Note the deployed endpoint URL:

   ```
   https://devdataextwufunc0.azurewebsites.net/api/
   ```

1. Update the **app_config.yaml** `dev:` section with the same endpoints you configured for `local:`, but using the deployed Function App's managed identity for authentication.

   ![](../media/Lab-05/image20.png)

### Task 7: Test the deployed API endpoints

In this task, you will verify that the deployed API endpoints are working correctly.

1. Test the **health check** on the deployed endpoint:

   ```
   curl https://devdataextwufunc0.azurewebsites.net/api/v1/health
   ```

   ![](../media/Lab-05/image21.png)

1. Verify all services show as **healthy**. The deployed Function App uses its **managed identity** for authentication to Azure services.

1. Upload the extraction configuration to the **deployed** endpoint:

   ```
   curl -X PUT "https://devdataextwufunc0.azurewebsites.net/api/configs/document-extraction/versions/v1.0" ^
     -H "Content-Type: application/json" ^
     -d @configs/document-extraction-v1.0.json
   ```

   ![](../media/Lab-05/image22.png)

1. Ingest the document to the **deployed** endpoint:

   ```
   curl -X POST "https://devdataextwufunc0.azurewebsites.net/api/ingest-documents/Collection1/Lease1/MicrosoftLeaseAgreement" ^
     -H "Content-Type: application/octet-stream" ^
     --data-binary @document_samples/Agreement_for_leasing_or_renting_certain_Microsoft_Software_Products.pdf
   ```

   ![](../media/Lab-05/image23.png)

1. Query the deployed endpoint:

   ```
   curl -X POST "https://devdataextwufunc0.azurewebsites.net/api/v1/query" ^
     -H "Content-Type: application/json" ^
     -H "x-user: labuser@contoso.com" ^
     -d "{\"cid\": \"Collection1\", \"sid\": \"azure-session1\", \"query\": \"Summarize all key terms of Lease1.\"}"
   ```

   ![](../media/Lab-05/image24.png)

1. Verify that the response includes the answer with citations and metrics, confirming the full pipeline works end-to-end in Azure.

### Task 8: Monitor the application with Application Insights

In this task, you will use Application Insights to monitor the deployed Function App's performance and troubleshoot issues.

1. In the Azure Portal, navigate to your **Application Insights** resource **(1)** (`devdataextwuAppi`).

   ![](../media/Lab-05/image25.png)

1. Click on **Live Metrics** **(1)** in the left menu to see real-time request rates, response times, and failures.

   ![](../media/Lab-05/image26.png)

1. Navigate to **Transaction search** **(1)** and search for recent requests to see execution traces for your API calls.

   ![](../media/Lab-05/image27.png)

1. Click on a specific query request to see the end-to-end transaction details:

   - HTTP request metadata (status, duration, URL)
   - Dependency calls to Cosmos DB, Azure OpenAI, Key Vault
   - Custom events and traces logged by the application
   - Token usage from Azure OpenAI

   ![](../media/Lab-05/image28.png)

1. Navigate to **Failures** **(1)** to check for any errors. Review failure details and exception messages if present.

1. Navigate to **Performance** **(1)** to view average response times broken down by operation. The query endpoint typically has the highest latency due to the LLM call.

   ![](../media/Lab-05/image29.png)

   >**Note:** If you enabled Semantic Kernel telemetry by setting `SEMANTICKERNEL_EXPERIMENTAL_GENAI_ENABLE_OTEL_DIAGNOSTICS=true` in the Function App settings, you will also see detailed traces of the Semantic Kernel workflow — including tool calls, prompt/completion content, and token counts.

### Task 9: Run the test suite

In this task, you will run the project's unit tests to validate the codebase.

1. In the terminal, install the test dependencies:

   ```
   pip install -r requirements_dev.txt
   ```

   ![](../media/Lab-05/image30.png)

1. Run the test suite:

   ```
   pytest
   ```

   ![](../media/Lab-05/image31.png)

1. Review the test results. The tests cover:

   | Category | What is tested |
   |---|---|
   | **Controllers** | Health check, inference, config upload, document ingestion |
   | **Services** | CU client, Cosmos operations, LLM request manager, citation mapping |
   | **Utilities** | Citation cleaner, health check cache, path utilities, singleton pattern |
   | **Routes** | HTTP trigger route validation |
   | **Decorators** | Error handler decorator |

1. All tests should pass, confirming the codebase is working correctly.

   ![](../media/Lab-05/image32.png)

## Summary

Congratulations! You have completed the **Data Extraction Using Azure Content Understanding** workshop. Throughout these five exercises, you have:

1. **Exercise 1** — Set up the lab environment and explored the solution architecture.
2. **Exercise 2** — Deployed the complete Azure infrastructure using Terraform.
3. **Exercise 3** — Configured the application with Azure service endpoints and Key Vault secrets.
4. **Exercise 4** — Uploaded extraction configurations and ingested a lease agreement document.
5. **Exercise 5** — Queried documents with natural language, explored citations, deployed to Azure, and monitored with Application Insights.

You now have a fully functional intelligent document processing solution that:

- Extracts structured data from unstructured documents using **Azure Content Understanding**
- Stores extracted fields with confidence scores and bounding boxes in **Cosmos DB**
- Enables natural language querying with inline citations via **Azure OpenAI** and **Semantic Kernel**
- Supports multi-turn conversations with **chat history** persistence
- Runs on a serverless **Azure Functions** architecture with comprehensive monitoring via **Application Insights**

### You have successfully completed all exercises in this workshop.

© 2026 Microsoft Corporation. All rights reserved.

By using this demo/lab, you agree to the following terms:

The technology/functionality described in this demo/lab is provided by Microsoft Corporation for purposes of obtaining your feedback and to provide you with a learning experience. You may only use the demo/lab to evaluate such technology features and functionality and provide feedback to Microsoft. You may not use it for any other purpose. You may not modify, copy, distribute, transmit, display, perform, reproduce, publish, license, create derivative works from, transfer, or sell this demo/lab or any portion thereof.

COPYING OR REPRODUCTION OF THE DEMO/LAB (OR ANY PORTION OF IT) TO ANY OTHER SERVER OR LOCATION FOR FURTHER REPRODUCTION OR REDISTRIBUTION IS EXPRESSLY PROHIBITED.

THIS DEMO/LAB PROVIDES CERTAIN SOFTWARE TECHNOLOGY/PRODUCT FEATURES AND FUNCTIONALITY, INCLUDING POTENTIAL NEW FEATURES AND CONCEPTS, IN A SIMULATED ENVIRONMENT WITHOUT COMPLEX SET-UP OR INSTALLATION FOR THE PURPOSE DESCRIBED ABOVE. THE TECHNOLOGY/CONCEPTS REPRESENTED IN THIS DEMO/LAB MAY NOT REPRESENT FULL FEATURE FUNCTIONALITY AND MAY NOT WORK THE WAY A FINAL VERSION MAY WORK. WE ALSO MAY NOT RELEASE A FINAL VERSION OF SUCH FEATURES OR CONCEPTS. YOUR EXPERIENCE WITH USING SUCH FEATURES AND FUNCTIONALITY IN A PHYSICAL ENVIRONMENT MAY ALSO BE DIFFERENT.

**FEEDBACK**. If you give feedback about the technology features, functionality and/or concepts described in this demo/lab to Microsoft, you give to Microsoft, without charge, the right to use, share and commercialize your feedback in any way and for any purpose. You also give to third parties, without charge, any patent rights needed for their products, technologies and services to use or interface with any specific parts of a Microsoft software or service that includes the feedback. You will not give feedback that is subject to a license that requires Microsoft to license its software or documentation to third parties because we include your feedback in them. These rights survive this agreement.

MICROSOFT CORPORATION HEREBY DISCLAIMS ALL WARRANTIES AND CONDITIONS WITH REGARD TO THE DEMO/LAB, INCLUDING ALL WARRANTIES AND CONDITIONS OF MERCHANTABILITY, WHETHER EXPRESS, IMPLIED OR STATUTORY, FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. MICROSOFT DOES NOT MAKE ANY ASSURANCES OR REPRESENTATIONS WITH REGARD TO THE ACCURACY OF THE RESULTS, OUTPUT THAT DERIVES FROM USE OF DEMO/ LAB, OR SUITABILITY OF THE INFORMATION CONTAINED IN THE DEMO/LAB FOR ANY PURPOSE.

**DISCLAIMER**

This demo/lab contains only a portion of new features and enhancements in Microsoft Azure. Some of the features might change in future releases of the product. In this demo/lab, you will learn about some of the new features but not all of the new features.
