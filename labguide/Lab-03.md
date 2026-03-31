# Data Extraction Using Azure Content Understanding - Lab 03

![](../media/Lab-03/image01.png)

# Contents

- Introduction

- Configuring the Application

    - Task 1: Configure local settings for Azure Functions

    - Task 2: Update app_config.yaml with Azure service endpoints

    - Task 3: Retrieve secrets and endpoints from deployed resources

    - Task 4: Set up the Python virtual environment and install dependencies

    - Task 5: Start the Azure Function App locally

    - Task 6: Verify the health check endpoint

- Summary

- References

# Introduction

In this lab, you will configure the document extraction application to connect to the Azure services you deployed in Lab 02. This involves setting up local Azure Functions settings, updating the application configuration YAML with your specific resource endpoints and Key Vault secret references, installing Python dependencies, and starting the Function App locally.

By the end of this lab, you will have learned:

- How to configure Azure Functions local settings for Python development

- How to update the multi-environment app_config.yaml with real Azure endpoints

- How to retrieve endpoints and keys from deployed Azure resources

- How to set up a Python virtual environment and install project dependencies

- How to start an Azure Function App locally using Azure Functions Core Tools

- How to verify application health by testing the health check API endpoint

# Configuring the Application

The application uses a layered configuration approach:

1. **local.settings.json** — Azure Functions runtime settings (environment variables)
2. **app_config.yaml** — Application-specific configuration (Azure service endpoints, secret references, database names)
3. **Azure Key Vault** — Stores sensitive values (API keys, connection strings) referenced from app_config.yaml

## Task 1: Configure local settings for Azure Functions

In this task, you will create the local Azure Functions settings file that defines runtime environment variables.

1. In VS Code, open the integrated terminal (**Ctrl+`**) and navigate to the **src** directory:

    ```
    cd C:\Users\LabUser\Desktop\data-extraction-using-azure-content-understanding\src
    ```

2. Copy the sample settings file to create your local configuration:

    ```
    copy local.settings.sample.json local.settings.json
    ```

    ![](../media/Lab-03/image02.png)

3. Open **local.settings.json** in VS Code:

    ```
    code local.settings.json
    ```

4. Review the contents of the file:

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

5. Notice the key settings:

    - **FUNCTIONS_WORKER_RUNTIME** — Set to `python` for the Python Azure Functions runtime.
    - **AzureWebJobsStorage** — Set to `UseDevelopmentStorage=true` for local development (uses the Azurite storage emulator).
    - **ENVIRONMENT** — Set to `local` which tells the application to load the `local:` section from `app_config.yaml`.
    - **FUNCTIONS_EXTENSION_VERSION** — Uses Azure Functions v4 runtime.

6. Update the **AzureWebJobsStorage** value with your actual Azure Storage connection string. Navigate to the Azure Portal, open your **Storage Account** (`devdataextwuSa0`), go to **Access keys**, and copy the **Connection string**.

    ![](../media/Lab-03/image04.png)

7. Replace the `UseDevelopmentStorage=true` value with the copied connection string:

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

8. **Save** the file (**Ctrl+S**).

>**Note:** The `local.settings.json` file is excluded from version control via `.gitignore` as it contains sensitive connection strings. Never commit this file to a repository.

## Task 2: Update app_config.yaml with Azure service endpoints

In this task, you will update the application configuration file with the actual endpoints and Key Vault secret references for your deployed Azure resources.

1. Open the file **src/resources/app_config.yaml** in VS Code:

    ```
    code resources/app_config.yaml
    ```

    ![](../media/Lab-03/image05.png)

2. The file has a `local:` section at the top that corresponds to the `ENVIRONMENT=local` setting. Review its structure — it contains configuration for:

    - **key_vault_uri** — Azure Key Vault endpoint (for resolving secrets)
    - **cosmosdb** — Database name, connection string (from Key Vault), collection names
    - **llm** — Azure OpenAI model name, endpoint, API key (from Key Vault)
    - **content_understanding** — CU endpoint, subscription key (from Key Vault), timeout, project ID
    - **chat_history** — Cosmos DB SQL API endpoint, database and container names
    - **blob_storage** — Storage account URL and container name

3. You will now update each section with values from your deployed resources. Start with the **Key Vault URI**. In the Azure Portal, open your Key Vault (`devdataextwuKv0`), go to **Overview**, and copy the **Vault URI**.

    ![](../media/Lab-03/image06.png)

4. Update the `key_vault_uri` value in the `local:` section:

    ```yaml
    local:
      key_vault_uri: "https://devdataextwuKv0.vault.azure.net/"
    ```

5. Update the **tenant_id** with your Azure AD tenant ID. You can find this by running:

    ```
    az account show --query tenantId -o tsv
    ```

    ![](../media/Lab-03/image07.png)

## Task 3: Retrieve secrets and endpoints from deployed resources

In this task, you will gather all the remaining endpoints and configuration values from your deployed Azure resources and complete the app_config.yaml file.

1. Get the **Azure OpenAI endpoint**. In the Azure Portal, navigate to your Azure OpenAI resource (`devdataextwuaoai0`), go to **Keys and Endpoint**, and copy the **Endpoint** URL.

    ![](../media/Lab-03/image08.png)

2. Update the `llm` section in app_config.yaml. The `endpoint` value should point to your specific deployment:

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

>**Note:** The `access_key` field uses `type: "secret"` which means the application will resolve the value from Azure Key Vault using the key name `open-ai-key`. The Terraform deployment automatically stored this secret in Key Vault.

3. Get the **Content Understanding endpoint**. In the Azure Portal, navigate to your AI Services resource (`devdataextwuais0`), go to **Keys and Endpoint**, and copy the **Endpoint**.

    ![](../media/Lab-03/image09.png)

4. Get the **AI Foundry Project ID**. Navigate to the **AI Foundry project** in the Azure Portal. The project ID can be found in the project overview or properties.

    ![](../media/Lab-03/image10.png)

5. Update the `content_understanding` section:

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

6. Get the **Cosmos DB SQL API endpoint** for chat history. Navigate to your Cosmos DB SQL API account (`devdataextwucosmoskb0`) and copy the **URI** from the overview page.

    ![](../media/Lab-03/image11.png)

7. Update the `chat_history` section:

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

8. Get the **Storage Account URL**. Navigate to your Storage Account (`devdataextwuSa0`) and copy the **Blob service endpoint** from the overview page.

    ![](../media/Lab-03/image12.png)

9. Update the `blob_storage` section:

    ```yaml
    blob_storage:
      account_url:
        value: "https://devdataextwusa0.blob.core.windows.net/"
      container_name:
        value: "processed"
    ```

10. **Save** the file (**Ctrl+S**). Your `local:` section should now have all real values for Key Vault URI, tenant ID, OpenAI endpoint, Content Understanding endpoint, Cosmos DB endpoints, and Storage Account URL.

    ![](../media/Lab-03/image13.png)

>**Note:** Secret values (Cosmos DB connection string, OpenAI API key, AI Services subscription key) are NOT stored directly in this file. They are referenced by Key Vault secret names (e.g., `key: "cosmosdb-connection-string"`, `type: "secret"`). The application resolves them at runtime using the Key Vault URI. This is a security best practice.

## Task 4: Set up the Python virtual environment and install dependencies

In this task, you will create a Python virtual environment and install all required packages.

1. In the terminal, navigate to the **project root** directory:

    ```
    cd C:\Users\LabUser\Desktop\data-extraction-using-azure-content-understanding
    ```

2. Create a Python virtual environment:

    ```
    python -m venv .venv
    ```

    ![](../media/Lab-03/image14.png)

3. Activate the virtual environment:

    ```
    .venv\Scripts\activate
    ```

    You should see `(.venv)` appear at the beginning of your terminal prompt.

    ![](../media/Lab-03/image15.png)

4. Install the project dependencies:

    ```
    pip install -r requirements.txt
    ```

    This will install all required packages including:

    - **azure-functions** — Azure Functions SDK
    - **azure-keyvault-secrets** — Key Vault secret client
    - **azure-storage-blob** — Blob storage client
    - **azure-identity** — Azure authentication (DefaultAzureCredential)
    - **semantic-kernel** — Microsoft Semantic Kernel for LLM orchestration
    - **pymongo** — MongoDB driver for Cosmos DB (Mongo API)
    - **pyyaml** — YAML configuration parser
    - **requests** — HTTP client for Content Understanding API
    - **cachetools** — TTL caching for health checks and collection data

    ![](../media/Lab-03/image16.png)

5. Wait for the installation to complete. You should see **"Successfully installed"** followed by a list of all installed packages.

    ![](../media/Lab-03/image17.png)

6. Configure VS Code to use the virtual environment. Open **VS Code Settings** (`.vscode/settings.json`) and verify the following setting exists:

    ```json
    {
      "azureFunctions.pythonVenv": ".venv"
    }
    ```

    ![](../media/Lab-03/image18.png)

## Task 5: Start the Azure Function App locally

In this task, you will start the Azure Functions application locally and verify it runs without errors.

1. Ensure your virtual environment is activated (you should see `(.venv)` in the terminal prompt).

2. Start the Azure Function App using Azure Functions Core Tools:

    ```
    func start --script-root ./src/
    ```

    ![](../media/Lab-03/image19.png)

3. Wait for the Function App to initialize. You should see output indicating that the following HTTP trigger functions have been registered:

    ```
    Functions:

        health_check: [GET] http://localhost:7071/api/v1/health
        startup_check: [GET] http://localhost:7071/api/v1/startup
        put_config: [PUT] http://localhost:7071/api/configs/{name}/versions/{version}
        get_config: [GET] http://localhost:7071/api/configs/{name}/versions/{version}
        get_default_config: [GET] http://localhost:7071/api/configs/default
        query: [POST] http://localhost:7071/api/v1/query
        ingest_documents: [POST] http://localhost:7071/api/ingest-documents/{collection_id}/{lease_id}/{document_name}
    ```

    ![](../media/Lab-03/image20.png)

>**Note:** If you see errors related to Key Vault authentication, ensure you are logged in to Azure CLI (`az login`) in the same terminal session. The application uses `DefaultAzureCredential` which falls back to Azure CLI credentials for local development.

4. Keep the terminal running — the Function App must remain active for the next task.

## Task 6: Verify the health check endpoint

In this task, you will test the health check endpoint to verify that the application can connect to all backend services.

1. Open a **new terminal tab** (**Ctrl+Shift+`**) in VS Code while keeping the Function App running in the first tab.

2. Test the **startup liveness probe**:

    ```
    curl http://localhost:7071/api/v1/startup
    ```

    You should receive a simple **200 OK** response. This endpoint always returns healthy and confirms the Function App is running.

    ![](../media/Lab-03/image21.png)

3. Test the **full health check** that verifies connectivity to all backend services:

    ```
    curl http://localhost:7071/api/v1/health
    ```

    ![](../media/Lab-03/image22.png)

4. Review the health check response. When all services are healthy, you will see:

    ```json
    {
      "status": "healthy",
      "checks": {
        "mongo_db": {
          "status": "healthy",
          "details": "mongo_db is running as expected."
        },
        "cosmos_db": {
          "status": "healthy",
          "details": "cosmos_db is running as expected."
        },
        "key_vault": {
          "status": "healthy",
          "details": "key_vault is running as expected."
        },
        "content_understanding": {
          "status": "healthy",
          "details": "content_understanding is running as expected."
        },
        "azure_openai": {
          "status": "healthy",
          "details": "azure_openai is running as expected."
        }
      }
    }
    ```

5. Verify that all five services show **"status": "healthy"**:

    - **mongo_db** — Cosmos DB (Mongo API) connectivity
    - **cosmos_db** — Cosmos DB (SQL API) for chat history
    - **key_vault** — Azure Key Vault secret resolution
    - **content_understanding** — Azure Content Understanding API
    - **azure_openai** — Azure OpenAI gpt-4o model

>**Note:** If any service shows "unhealthy", double-check the corresponding endpoint and secret name in `app_config.yaml`. The health check results are cached for 300 seconds (5 minutes), so you may need to wait after making configuration changes.

6. Alternatively, you can use the **REST Client** extension in VS Code. Open the file **src/samples/health_check_sample.http** and click **Send Request** on the local health check line.

    ![](../media/Lab-03/image23.png)

7. The REST Client will display the response inline in VS Code, which is convenient for testing APIs throughout the remaining labs.

    ![](../media/Lab-03/image24.png)

# Summary

In this lab, you configured the Azure Functions local settings, updated the app_config.yaml with real Azure resource endpoints and Key Vault secret references, installed all Python dependencies in a virtual environment, started the Function App locally, and verified that all five backend services are healthy.

In the next lab, you will upload extraction configurations and ingest your first document using Azure Content Understanding.

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
