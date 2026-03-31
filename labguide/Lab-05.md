# Data Extraction Using Azure Content Understanding - Lab 05

![](../media/Lab-05/image01.png)

# Contents

- Introduction

- Querying Documents with Natural Language

    - Task 1: Understand the query pipeline and Semantic Kernel

    - Task 2: Query ingested documents using the API

    - Task 3: Explore citations and source references

    - Task 4: Test chat history and session management

    - Task 5: Explore the citation aliasing optimization

- Deploying to Azure and Monitoring

    - Task 6: Deploy the Function App to Azure

    - Task 7: Test the deployed API endpoints

    - Task 8: Monitor the application with Application Insights

    - Task 9: Run the test suite

- Summary

- References

# Introduction

In this lab, you will use the natural language query interface to ask questions about the lease agreement data extracted in Lab 04. You will explore how Azure OpenAI (powered by Semantic Kernel) processes your queries, retrieves data from Cosmos DB, and returns responses with inline citations that trace back to specific pages and bounding boxes in the original PDF. You will also deploy the Function App to Azure and monitor it with Application Insights.

By the end of this lab, you will have learned:

- How the Semantic Kernel-based query pipeline works with tool calling

- How to query extracted documents using natural language with citations

- How chat history enables multi-turn conversational queries

- How citation aliasing optimizes LLM token usage

- How to deploy the Azure Function App to Azure

- How to monitor API performance using Application Insights

# Querying Documents with Natural Language

The Document Enquiry workflow uses Microsoft Semantic Kernel to orchestrate Azure OpenAI (gpt-4o). When a user submits a query, the LLM is forced to call a tool (`get_collection_data`) that retrieves all extracted fields from Cosmos DB for the specified collection. The LLM then formulates a response with inline citations referencing the source documents and bounding box locations.

## Task 1: Understand the query pipeline and Semantic Kernel

In this task, you will trace the query pipeline code to understand how natural language queries are processed.

1. Ensure the Azure Function App is running locally from the previous lab. If not, start it:

    ```
    cd C:\Users\LabUser\Desktop\data-extraction-using-azure-content-understanding
    .venv\Scripts\activate
    func start --script-root ./src/
    ```

2. In VS Code, open the file **src/controllers/inference_controller.py**. Review the `query()` method:

    ![](../media/Lab-05/image02.png)

3. The query process follows these steps:

    a. **Load configuration** — The extraction configuration is loaded from Cosmos DB to obtain the system prompt.

    b. **Create CollectionPlugin** — A Semantic Kernel plugin is instantiated that can retrieve collection data from Cosmos DB.

    c. **Check message limit** — Verifies the session hasn't exceeded the 20-message limit.

    d. **Call LLM** — Invokes `answer_collection_question()` which uses Semantic Kernel to call Azure OpenAI.

    e. **Store chat history** — Saves the conversation to Cosmos DB (SQL API) for multi-turn support.

    f. **Return response** — Returns the LLM response with resolved citations and token usage metrics.

4. Open **src/services/llm_request_manager.py**. Review the `answer_collection_question()` method:

    ![](../media/Lab-05/image03.png)

5. Key implementation details:

    - The method creates a Semantic Kernel **Kernel** instance and registers the **CollectionPlugin**.
    - **FunctionChoiceBehavior.Required** forces the LLM to call the `get_collection_data` tool — it cannot answer without first retrieving the actual data.
    - **response_format = GeneratedResponse** enforces structured output — the LLM must return a JSON object with `response` (text) and `citations` (list of alias references).
    - After the LLM responds, citation aliases are resolved back to actual document paths and bounding box coordinates.

6. Open **src/services/collection_kernel_plugin.py**. Review the `get_collection_data()` method decorated with `@kernel_function`:

    ![](../media/Lab-05/image04.png)

7. This Semantic Kernel plugin method:

    a. Fetches all extracted fields for the collection from Cosmos DB.

    b. Builds a structured `DocumentData` object.

    c. Processes the data through the **CitationMapper**, which replaces verbose citation data (document paths and bounding boxes) with compact aliases like `CITE{collection_id}-A`, `CITE{collection_id}-B`.

    d. Caches the result with a 24-hour TTL to avoid repeated database calls.

    e. Returns the optimized JSON string to the LLM context.

## Task 2: Query ingested documents using the API

In this task, you will send natural language queries to the API and examine the responses.

1. Open a **new terminal tab** and run the following curl command to query the ingested lease agreement:

    ```
    curl -X POST "http://localhost:7071/api/v1/query" ^
      -H "Content-Type: application/json" ^
      -H "x-user: labuser@contoso.com" ^
      -d "{\"cid\": \"Collection1\", \"sid\": \"session1\", \"query\": \"What are the termination conditions for Lease1?\"}"
    ```

    ![](../media/Lab-05/image05.png)

2. Review the response. It should contain:

    ```json
    {
      "response": "The lease agreement for Lease1 can be terminated under the following conditions: [1]...",
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

3. Understand each part of the response:

    - **response** — The natural language answer from Azure OpenAI, with inline citation markers `[1]`, `[2]`, etc.
    - **citations** — An array where each item is `[source_document_path, bounding_box_coordinates]`. Citation `[1]` in the response corresponds to `citations[0]`.
    - **metrics** — Token usage and latency information for monitoring costs.

4. Try another query about the lease scope:

    ```
    curl -X POST "http://localhost:7071/api/v1/query" ^
      -H "Content-Type: application/json" ^
      -H "x-user: labuser@contoso.com" ^
      -d "{\"cid\": \"Collection1\", \"sid\": \"session1\", \"query\": \"What is the scope of the license grant?\"}"
    ```

    ![](../media/Lab-05/image07.png)

5. Try a more analytical query:

    ```
    curl -X POST "http://localhost:7071/api/v1/query" ^
      -H "Content-Type: application/json" ^
      -H "x-user: labuser@contoso.com" ^
      -d "{\"cid\": \"Collection1\", \"sid\": \"session1\", \"query\": \"Are there any prohibited uses? List them all.\"}"
    ```

    ![](../media/Lab-05/image08.png)

6. Alternatively, use the **REST Client** extension. Open **src/samples/query_api_sample.http** and modify the local query request with your collection ID. Click **Send Request**.

    ![](../media/Lab-05/image09.png)

## Task 3: Explore citations and source references

In this task, you will understand how citations trace back to the original document.

1. Examine the `citations` array from your previous query response. Each citation contains two elements:

    - **Source document path** — e.g., `Collections/Collection1/Lease1/MicrosoftLeaseAgreement` — identifies which document and where in blob storage the markdown is stored.

    - **Bounding box** — e.g., `D(5,1.2567,4.5678,...)` — specifies the page number and exact coordinates on the PDF page where the referenced text appears.

2. The bounding box format is `D(page, x1, y1, x2, y2, x3, y3, x4, y4)` where:

    - **page** — The page number in the PDF (1-indexed).
    - **x1,y1 → x4,y4** — Four corner coordinates of the bounding polygon on the page.

    ![](../media/Lab-05/image10.png)

3. This traceability is critical for enterprise use cases. When a user asks "What are the termination conditions?", the system not only provides the answer but also identifies the **exact location** on the **exact page** of the **exact document** where that information was found.

4. Open the original PDF document at **document_samples/Agreement_for_leasing_or_renting_certain_Microsoft_Software_Products.pdf** and navigate to the page referenced in the citation to verify the bounding box matches the relevant text.

    ![](../media/Lab-05/image11.png)

## Task 4: Test chat history and session management

In this task, you will observe how the system maintains conversational context across multiple queries within a session.

1. Start a new session by using a different session ID and ask a broad question:

    ```
    curl -X POST "http://localhost:7071/api/v1/query" ^
      -H "Content-Type: application/json" ^
      -H "x-user: labuser@contoso.com" ^
      -d "{\"cid\": \"Collection1\", \"sid\": \"session2\", \"query\": \"Tell me about the compliance audit terms.\"}"
    ```

    ![](../media/Lab-05/image12.png)

2. Now ask a follow-up question in the **same session** that relies on context:

    ```
    curl -X POST "http://localhost:7071/api/v1/query" ^
      -H "Content-Type: application/json" ^
      -H "x-user: labuser@contoso.com" ^
      -d "{\"cid\": \"Collection1\", \"sid\": \"session2\", \"query\": \"Can you elaborate on the audit frequency mentioned?\"}"
    ```

    ![](../media/Lab-05/image13.png)

3. Notice that the LLM maintains context from the previous question. It knows "the audit frequency mentioned" refers to the compliance audit terms discussed earlier. This is powered by the **chat history** stored in the Cosmos DB SQL API.

4. Navigate to the Azure Portal, open the Cosmos DB SQL API account (`devdataextwucosmoskb0`), and open **Data Explorer**.

5. Expand **knowledge-base-db** → **chat-history** and browse the stored conversation documents. You should see entries for your session with both user messages and assistant responses.

    ![](../media/Lab-05/image14.png)

6. Note that the system has a **20-message limit** per session. After 20 messages, subsequent queries return an HTTP 400 error indicating the limit has been reached. Start a new session ID to continue querying.

>**Note:** Chat history stores messages with inline citations stripped from the assistant responses (using the citation cleaner utility) to keep stored context clean. Tool call messages are also filtered out from the retrieved history.

## Task 5: Explore the citation aliasing optimization

In this task, you will understand the token optimization technique that reduces LLM costs.

1. Open **src/services/citation_mapper.py** in VS Code.

    ![](../media/Lab-05/image15.png)

2. The `process_json()` method performs citation aliasing:

    a. Iterates through all extracted fields in the collection data.

    b. Replaces verbose `source_document` and `source_bounding_boxes` values with compact aliases like `CITE{collection_id}-A`, `CITE{collection_id}-B`.

    c. Removes the `type` field from each entry (not needed by the LLM).

    d. Builds a reverse mapping dictionary to restore real citations after the LLM responds.

3. This optimization achieves approximately **50% reduction** in input/output tokens, significantly reducing Azure OpenAI API costs. For example:

    | Before | After |
    |---|---|
    | `"source_document": "Collections/Collection1/Lease1/MicrosoftLeaseAgreement"` | `"source": "CITECollection1-A"` |
    | `"source_bounding_boxes": "D(5,1.2567,4.5678,...)"` | (removed, stored in mapping) |

4. After the LLM generates a response with alias references, the `restore_citations()` method in **collection_kernel_plugin.py** maps them back to the real document paths and bounding box coordinates before returning to the user.

    ![](../media/Lab-05/image16.png)

5. Open the file **docs/design/decisions/alias-names-vs-real-citation.md** to read the full architecture decision record behind this optimization.

    ![](../media/Lab-05/image17.png)

# Deploying to Azure and Monitoring

Now that you have tested the complete solution locally, you will deploy the Function App to Azure and verify it works in the cloud environment.

## Task 6: Deploy the Function App to Azure

In this task, you will deploy the local Function App code to the Azure Function App provisioned by Terraform.

1. Open a terminal and ensure you are in the project root directory with the virtual environment activated:

    ```
    cd C:\Users\LabUser\Desktop\data-extraction-using-azure-content-understanding
    .venv\Scripts\activate
    ```

2. Stop the locally running Function App by pressing **Ctrl+C** in the terminal running `func start`.

3. Deploy the Function App to Azure using Azure Functions Core Tools:

    ```
    func azure functionapp publish devdataextwufunc0 --python --script-root ./src/
    ```

    ![](../media/Lab-05/image18.png)

4. Wait for the deployment to complete. You should see output confirming:

    - Function app files packaged and uploaded
    - Remote build completed
    - Syncing triggers
    - Function URLs listed

    ![](../media/Lab-05/image19.png)

5. Note the deployed endpoint URL, which will be in the format:

    ```
    https://devdataextwufunc0.azurewebsites.net/api/
    ```

6. Update the **app_config.yaml** `dev:` section with the same endpoints you configured for the `local:` section, but using the deployed Function App's managed identity for authentication instead of local Azure CLI credentials.

    ![](../media/Lab-05/image20.png)

## Task 7: Test the deployed API endpoints

In this task, you will verify that the deployed API endpoints are working correctly.

1. Test the **health check** on the deployed endpoint:

    ```
    curl https://devdataextwufunc0.azurewebsites.net/api/v1/health
    ```

    ![](../media/Lab-05/image21.png)

2. Verify all services show as **healthy**. The deployed Function App uses its **managed identity** for authentication to Azure services, which was configured by the Terraform deployment.

3. Upload the extraction configuration to the **deployed** endpoint:

    ```
    curl -X PUT "https://devdataextwufunc0.azurewebsites.net/api/configs/document-extraction/versions/v1.0" ^
      -H "Content-Type: application/json" ^
      -d @configs/document-extraction-v1.0.json
    ```

    ![](../media/Lab-05/image22.png)

4. Ingest the document to the **deployed** endpoint:

    ```
    curl -X POST "https://devdataextwufunc0.azurewebsites.net/api/ingest-documents/Collection1/Lease1/MicrosoftLeaseAgreement" ^
      -H "Content-Type: application/octet-stream" ^
      --data-binary @document_samples/Agreement_for_leasing_or_renting_certain_Microsoft_Software_Products.pdf
    ```

    ![](../media/Lab-05/image23.png)

5. Query the deployed endpoint:

    ```
    curl -X POST "https://devdataextwufunc0.azurewebsites.net/api/v1/query" ^
      -H "Content-Type: application/json" ^
      -H "x-user: labuser@contoso.com" ^
      -d "{\"cid\": \"Collection1\", \"sid\": \"azure-session1\", \"query\": \"Summarize all key terms of Lease1.\"}"
    ```

    ![](../media/Lab-05/image24.png)

6. Verify that the response includes the answer with citations and metrics, confirming the full pipeline works end-to-end in Azure.

## Task 8: Monitor the application with Application Insights

In this task, you will use Application Insights to monitor the deployed Function App's performance and troubleshoot issues.

1. In the Azure Portal, navigate to your **Application Insights** resource (`devdataextwuAppi`).

    ![](../media/Lab-05/image25.png)

2. Click on **Live Metrics** in the left menu to see real-time request rates, response times, and failures.

    ![](../media/Lab-05/image26.png)

3. Navigate to **Transaction search** and search for recent requests to see the execution traces for your API calls.

    ![](../media/Lab-05/image27.png)

4. Click on a specific query request to see the end-to-end transaction details:

    - HTTP request metadata (status, duration, URL)
    - Dependency calls to Cosmos DB, Azure OpenAI, Key Vault
    - Custom events and traces logged by the application
    - Token usage from Azure OpenAI

    ![](../media/Lab-05/image28.png)

5. Navigate to **Failures** to check for any errors. Review the failure details and exception messages if any are present.

6. Navigate to **Performance** to view average response times broken down by operation. The query endpoint typically has the highest latency due to the LLM call.

    ![](../media/Lab-05/image29.png)

>**Note:** If you enabled Semantic Kernel telemetry by setting `SEMANTICKERNEL_EXPERIMENTAL_GENAI_ENABLE_OTEL_DIAGNOSTICS=true` in the Function App settings, you will also see detailed traces of the Semantic Kernel workflow — including tool calls, prompt/completion content, and token counts — in Application Insights.

## Task 9: Run the test suite

In this task, you will run the project's unit tests to validate the codebase.

1. In the terminal, install the test dependencies:

    ```
    pip install -r requirements_dev.txt
    ```

    ![](../media/Lab-05/image30.png)

2. Run the test suite:

    ```
    pytest
    ```

    ![](../media/Lab-05/image31.png)

3. Review the test results. The tests cover:

    - **Controllers** — Health check, inference, config upload, document ingestion
    - **Services** — CU client, Cosmos operations, LLM request manager, citation mapping
    - **Utilities** — Citation cleaner, health check cache, path utilities, singleton pattern
    - **Routes** — HTTP trigger route validation
    - **Decorators** — Error handler decorator

4. All tests should pass, confirming the codebase is working correctly.

    ![](../media/Lab-05/image32.png)

# Summary

Congratulations! You have completed the Data Extraction Using Azure Content Understanding workshop. Throughout these five labs, you have:

- **Lab 01** — Set up the lab environment and explored the solution architecture
- **Lab 02** — Deployed the complete Azure infrastructure using Terraform
- **Lab 03** — Configured the application with Azure service endpoints and secrets
- **Lab 04** — Uploaded extraction configurations and ingested a lease agreement document
- **Lab 05** — Queried documents with natural language, explored citations, deployed to Azure, and monitored with Application Insights

You now have a fully functional intelligent document processing solution that:

- Extracts structured data from unstructured documents using Azure Content Understanding
- Stores extracted fields with confidence scores and bounding boxes in Cosmos DB
- Enables natural language querying with inline citations via Azure OpenAI and Semantic Kernel
- Supports multi-turn conversations with chat history persistence
- Runs on a serverless Azure Functions architecture with comprehensive monitoring

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
