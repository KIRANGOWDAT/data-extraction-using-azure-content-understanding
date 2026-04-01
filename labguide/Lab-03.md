# Exercise 3: Configuring the Application

### Estimated Duration: 60 Minutes

## Overview

In this exercise, you will configure the document extraction application to connect to the Azure services deployed in Exercise 2. This involves setting up local Azure Functions settings, updating the application configuration YAML with your specific resource endpoints and Key Vault secret references, installing Python dependencies, and starting the Function App locally. By the end of this exercise, all five backend services will be healthy and the API endpoints ready for use.

## Objectives

In this exercise, you will complete the following tasks:

- Task 1: Configure local settings for Azure Functions
- Task 2: Update app_config.yaml with Azure service endpoints
- Task 3: Retrieve secrets and endpoints from deployed resources
- Task 4: Set up the Python virtual environment and install dependencies
- Task 5: Start the Azure Function App locally
- Task 6: Verify the health check endpoint

### Task 1: Configure local settings for Azure Functions

In this task, you will create the local Azure Functions settings file that defines runtime environment variables.

1. In VS Code, open the integrated terminal (**Ctrl+`**) and navigate to the **src** directory:

   ```
   cd C:\LabFiles\data-extraction-using-azure-content-understanding\src
   ```

1. Copy the sample settings file to create your local configuration:

   ```
   copy local.settings.sample.json local.settings.json
   ```

   ![](../media/Lab-03/image02.png)

1. Open **local.settings.json** **(1)** in the VS Code Explorer. Review the contents:

   ```json
   {
     "IsEncrypted": false,
     "Values": {
       "FUNCTIONS_WORKER_RUNTIME": "python",
       "AzureWebJobsStorage": "UseDevelopmentStorage=true",
       "PYTHON_ENABLE_DEBUG_LOGGING": "1",
       "ENVIRONMENT": "local",
       "FUNCTIONS_EXTENSION_VERSION": "~4",
       "WEBSITE_NODE_DEFAULT_VERSION": "~18"
     }
   }
   ```

   ![](../media/Lab-03/image03.png)

1. Notice the key settings:

   - **FUNCTIONS_WORKER_RUNTIME** — Set to `python` for the Python Azure Functions runtime.
   - **AzureWebJobsStorage** — Set to `UseDevelopmentStorage=true` for local development (uses the Azurite storage emulator).
   - **ENVIRONMENT** — Set to `local` which tells the application to load the `local:` section from `app_config.yaml`.
   - **FUNCTIONS_EXTENSION_VERSION** — Uses Azure Functions v4 runtime.

1. Navigate to the **Azure Portal**, open your **Storage Account** **(1)** (`devdataextwuSa0`), go to **Access keys** **(2)**, and copy the **Connection string** **(3)**.

   ![](../media/Lab-03/image04.png)

1. Replace the `UseDevelopmentStorage=true` value in **local.settings.json** with the copied connection string:

   ```json
   {
     "IsEncrypted": false,
     "Values": {
       "FUNCTIONS_WORKER_RUNTIME": "python",
       "AzureWebJobsStorage": "<your-storage-connection-string>",
       "PYTHON_ENABLE_DEBUG_LOGGING": "1",
       "ENVIRONMENT": "local",
       "FUNCTIONS_EXTENSION_VERSION": "~4",
       "WEBSITE_NODE_DEFAULT_VERSION": "~18"
     }
   }
   ```

1. **Save** the file (**Ctrl+S**).

   >**Note:** The `local.settings.json` file is excluded from version control via `.gitignore` as it contains sensitive connection strings. Never commit this file to a repository.

### Task 2: Update app_config.yaml with Azure service endpoints

In this task, you will update the application configuration file with the actual endpoints and Key Vault secret references for your deployed Azure resources.

1. In VS Code Explorer, navigate to **src** > **resources** **(1)** and click on **app_config.yaml** **(2)** to open it.

   ![](../media/Lab-03/image05.png)

1. The file has a `local:` section at the top that corresponds to the `ENVIRONMENT=local` setting. It contains configuration for:

   - **key_vault_uri** — Azure Key Vault endpoint (for resolving secrets)
   - **cosmosdb** — Database name, connection string (from Key Vault), collection names
   - **llm** — Azure OpenAI model name, endpoint, API key (from Key Vault)
   - **content_understanding** — CU endpoint, subscription key (from Key Vault), timeout, project ID
   - **chat_history** — Cosmos DB SQL API endpoint, database and container names
   - **blob_storage** — Storage account URL and container name

1. Start with the **Key Vault URI**. In the Azure Portal, open your Key Vault **(1)** (`devdataextwuKv0`), go to **Overview** **(2)**, and copy the **Vault URI** **(3)**.

   ![](../media/Lab-03/image06.png)

1. Update the `key_vault_uri` value in the `local:` section:

   ```yaml
   local:
     key_vault_uri: "https://devdataextwuKv0.vault.azure.net/"
   ```

1. Retrieve the **tenant_id** by running the following command in the terminal:

   ```
   az account show --query tenantId -o tsv
   ```

   ![](../media/Lab-03/image07.png)

### Task 3: Retrieve secrets and endpoints from deployed resources

In this task, you will gather all remaining endpoints and configuration values from your deployed Azure resources to complete the app_config.yaml file.

1. Get the **Azure OpenAI endpoint**. In the Azure Portal, navigate to your Azure OpenAI resource **(1)** (`devdataextwuaoai0`), go to **Keys and Endpoint** **(2)**, and copy the **Endpoint** URL **(3)**.

   ![](../media/Lab-03/image08.png)

1. Update the `llm` section in **app_config.yaml**:

   ```yaml
   llm:
     model_name:
       value: "gpt-4o"
     endpoint:
       value: "https://devdataextwuaoai0.openai.azure.com/openai/deployments/gpt-4o"
     access_key:
       key: "open-ai-key"
       type: "secret"
     api_version:
       value: "2025-04-01-preview"
   ```

   >**Note:** The `access_key` field uses `type: "secret"` which means the application resolves the value from Azure Key Vault using the key name `open-ai-key`. The Terraform deployment automatically stored this secret in Key Vault.

1. Get the **Content Understanding endpoint**. In the Azure Portal, navigate to your AI Services resource **(1)** (`devdataextwuais0`), go to **Keys and Endpoint** **(2)**, and copy the **Endpoint** **(3)**.

   ![](../media/Lab-03/image09.png)

1. Get the **AI Foundry Project ID**. Navigate to the **AI Foundry project** **(1)** in the Azure Portal. The project ID can be found in the project overview or properties.

   ![](../media/Lab-03/image10.png)

1. Update the `content_understanding` section:

   ```yaml
   content_understanding:
     endpoint:
       value: "https://devdataextwuais0.cognitiveservices.azure.com/"
     subscription_key:
       key: "ai-foundry-key"
       type: "secret"
     request_timeout:
       value: 30
     project_id:
       value: "<your-ai-project-id>"
   ```

1. Get the **Cosmos DB SQL API endpoint** for chat history. Navigate to your Cosmos DB SQL API account **(1)** (`devdataextwucosmoskb0`) and copy the **URI** **(2)** from the overview page.

   ![](../media/Lab-03/image11.png)

1. Update the `chat_history` section:

   ```yaml
   chat_history:
     endpoint:
       value: "https://devdataextwucosmoskb0.documents.azure.com:443/"
     db_name:
       value: "knowledge-base-db"
     chat_history_container_name:
       value: "chat-history"
     user_message_limit:
       value: 20
     domain:
       value: "Data Extraction AI"
   ```

1. Get the **Storage Account URL**. Navigate to your Storage Account **(1)** (`devdataextwuSa0`) and copy the **Blob service endpoint** **(2)** from the overview page.

   ![](../media/Lab-03/image12.png)

1. Update the `blob_storage` section:

   ```yaml
   blob_storage:
     account_url:
       value: "https://devdataextwusa0.blob.core.windows.net/"
     container_name:
       value: "processed"
   ```

1. **Save** the file (**Ctrl+S**). Your `local:` section should now have all real values for Key Vault URI, tenant ID, OpenAI endpoint, Content Understanding endpoint, Cosmos DB endpoints, and Storage Account URL.

   ![](../media/Lab-03/image13.png)

   >**Note:** Secret values (Cosmos DB connection string, OpenAI API key, AI Services subscription key) are NOT stored directly in this file. They are referenced by Key Vault secret names (e.g., `key: "cosmosdb-connection-string"`, `type: "secret"`). The application resolves them at runtime using the Key Vault URI. This is a security best practice.

### Task 4: Set up the Python virtual environment and install dependencies

In this task, you will create a Python virtual environment and install all required packages.

1. In the terminal, navigate to the **project root** directory:

   ```
   cd C:\LabFiles\data-extraction-using-azure-content-understanding
   ```

1. Create a Python virtual environment:

   ```
   python -m venv .venv
   ```

   ![](../media/Lab-03/image14.png)

1. Activate the virtual environment:

   ```
   .venv\Scripts\activate
   ```

   You should see `(.venv)` appear at the beginning of your terminal prompt.

   ![](../media/Lab-03/image15.png)

1. Install the project dependencies:

   ```
   pip install -r requirements.txt
   ```

   This installs all required packages including:

   | Package | Purpose |
   |---|---|
   | `azure-functions` | Azure Functions SDK |
   | `azure-keyvault-secrets` | Key Vault secret client |
   | `azure-storage-blob` | Blob storage client |
   | `azure-identity` | Azure authentication (DefaultAzureCredential) |
   | `semantic-kernel` | Microsoft Semantic Kernel for LLM orchestration |
   | `pymongo` | MongoDB driver for Cosmos DB (Mongo API) |
   | `pyyaml` | YAML configuration parser |
   | `requests` | HTTP client for Content Understanding API |
   | `cachetools` | TTL caching for health checks and collection data |

   ![](../media/Lab-03/image16.png)

1. Wait for the installation to complete. You should see **"Successfully installed"** followed by a list of all installed packages.

   ![](../media/Lab-03/image17.png)

1. Verify VS Code is configured to use the virtual environment. Open **.vscode/settings.json** **(1)** and confirm the following setting exists:

   ```json
   {
     "azureFunctions.pythonVenv": ".venv"
   }
   ```

   ![](../media/Lab-03/image18.png)

### Task 5: Start the Azure Function App locally

In this task, you will start the Azure Functions application locally and verify it runs without errors.

1. Ensure your virtual environment is activated (you should see `(.venv)` in the terminal prompt).

1. Start the Azure Function App using Azure Functions Core Tools:

   ```
   func start --script-root ./src/
   ```

   ![](../media/Lab-03/image19.png)

1. Wait for the Function App to initialize. You should see output showing that the following HTTP trigger functions have been registered:

   ```
   Functions:

       health_check:      [GET] http://localhost:7071/api/v1/health
       startup_check:     [GET] http://localhost:7071/api/v1/startup
       put_config:        [PUT] http://localhost:7071/api/configs/{name}/versions/{version}
       get_config:        [GET] http://localhost:7071/api/configs/{name}/versions/{version}
       get_default_config:[GET] http://localhost:7071/api/configs/default
       query:             [POST] http://localhost:7071/api/v1/query
       ingest_documents:  [POST] http://localhost:7071/api/ingest-documents/{collection_id}/{lease_id}/{document_name}
   ```

   ![](../media/Lab-03/image20.png)

   >**Note:** If you see errors related to Key Vault authentication, ensure you are logged in to Azure CLI (`az login`) in the same terminal session. The application uses `DefaultAzureCredential` which falls back to Azure CLI credentials for local development.

1. Keep the terminal running — the Function App must remain active for the next task.

### Task 6: Verify the health check endpoint

In this task, you will test the health check endpoint to verify that the application can connect to all backend services.

1. Open a **new terminal tab** (**Ctrl+Shift+`**) in VS Code while keeping the Function App running in the first tab.

1. Test the **startup liveness probe**:

   ```
   curl http://localhost:7071/api/v1/startup
   ```

   You should receive a simple **200 OK** response confirming the Function App is running.

   ![](../media/Lab-03/image21.png)

1. Test the **full health check** that verifies connectivity to all backend services:

   ```
   curl http://localhost:7071/api/v1/health
   ```

   ![](../media/Lab-03/image22.png)

1. Review the health check response. When all services are healthy, you will see:

   ```json
   {
     "status": "healthy",
     "checks": {
       "mongo_db":               { "status": "healthy" },
       "cosmos_db":              { "status": "healthy" },
       "key_vault":              { "status": "healthy" },
       "content_understanding":  { "status": "healthy" },
       "azure_openai":           { "status": "healthy" }
     }
   }
   ```

1. Verify that all five services show **"status": "healthy"**:

   | Service | Backend |
   |---|---|
   | **mongo_db** | Cosmos DB (Mongo API) connectivity |
   | **cosmos_db** | Cosmos DB (SQL API) for chat history |
   | **key_vault** | Azure Key Vault secret resolution |
   | **content_understanding** | Azure Content Understanding API |
   | **azure_openai** | Azure OpenAI gpt-4o model |

   >**Note:** If any service shows "unhealthy", double-check the corresponding endpoint and secret name in `app_config.yaml`. Health check results are cached for 300 seconds (5 minutes), so wait after making configuration changes before re-testing.

1. Alternatively, use the **REST Client** extension. Open the file **src/samples/health_check_sample.http** **(1)** and click **Send Request** **(2)** on the local health check line.

   ![](../media/Lab-03/image23.png)

1. The REST Client displays the response inline in VS Code, which is convenient for testing APIs throughout the remaining exercises.

   ![](../media/Lab-03/image24.png)

## Summary

In this exercise, you have completed the following:

1. Configured **Azure Functions local settings** with the Storage Account connection string.
2. Updated **app_config.yaml** with real Azure resource endpoints and Key Vault secret references.
3. Retrieved **endpoints and keys** from deployed Azure resources (OpenAI, AI Services, Cosmos DB, Storage).
4. Created a **Python virtual environment** and installed all project dependencies.
5. Started the **Azure Function App** locally and verified all HTTP trigger routes are registered.
6. Verified **all five backend services** are healthy via the health check API endpoint.

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
