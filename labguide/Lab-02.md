# Data Extraction Using Azure Content Understanding - Lab 02

![](../media/Lab-02/image01.png)

# Contents

- Introduction

- Deploying Azure Infrastructure with Terraform

    - Task 1: Authenticate with Azure CLI

    - Task 2: Configure Terraform variables

    - Task 3: Deploy the Azure infrastructure

    - Task 4: Verify deployed resources in the Azure Portal

    - Task 5: Explore Azure AI Foundry and Content Understanding

    - Task 6: Explore Azure Cosmos DB resources

- Summary

- References

# Introduction

In this lab, you will deploy the complete Azure infrastructure required by the document extraction solution using Terraform. The solution uses Infrastructure as Code (IaC) to ensure reproducible, consistent deployments across environments.

By the end of this lab, you will have learned:

- How to authenticate Azure CLI and set the correct subscription

- How to configure Terraform variables for your environment

- How to deploy Azure resources using `terraform init`, `plan`, and `apply`

- How to verify all deployed resources in the Azure Portal

- How to navigate Azure AI Foundry, Content Understanding, Cosmos DB, and Key Vault

# Deploying Azure Infrastructure with Terraform

The solution requires multiple Azure services working together. Rather than creating each resource manually in the Azure Portal, you will use modular Terraform configurations that provision everything in a single deployment.

The Terraform modules will create the following resources:

| Azure Resource | Purpose |
|---|---|
| **Resource Group** | Logical container for all resources |
| **Azure Key Vault** | Stores secrets (API keys, connection strings) |
| **Log Analytics Workspace** | Centralized logging and diagnostics |
| **Azure AI Hub** | Hosts Azure OpenAI (gpt-4o) and Azure Content Understanding |
| **Azure AI Foundry Project** | AI project for managing CU analyzers |
| **Azure Cosmos DB (Mongo API)** | Stores extraction configurations and extracted document data |
| **Azure Cosmos DB (SQL API)** | Stores chat history for conversational queries |
| **Azure Function App** | Serverless compute hosting all API endpoints |
| **Azure Storage Account** | Stores processed markdown documents |
| **Application Insights** | Application monitoring and tracing |

## Task 1: Authenticate with Azure CLI

In this task, you will sign in to Azure CLI and select the correct subscription for deployment.

1. Open **Windows Terminal** and run the following command to sign in to Azure:

    ```
    az login
    ```

    A browser window will open. Sign in with your Azure credentials.

    - Email/Username: <inject key="AzureAdUserEmail"></inject>
    - Password: <inject key="AzureAdUserPassword"></inject>

    ![](../media/Lab-02/image02.png)

2. After successful authentication, list all available subscriptions:

    ```
    az account list --output table
    ```

    ![](../media/Lab-02/image03.png)

3. Set the correct subscription for this lab:

    ```
    az account set --subscription "<inject key="AzureSubscriptionId"></inject>"
    ```

4. Verify the selected subscription:

    ```
    az account show --output table
    ```

    Confirm that the **SubscriptionId** and **Name** match your lab subscription.

    ![](../media/Lab-02/image04.png)

## Task 2: Configure Terraform variables

In this task, you will configure the Terraform variables that control resource naming, location, and environment settings.

1. In the terminal, navigate to the **iac** directory:

    ```
    cd C:\Users\LabUser\Desktop\data-extraction-using-azure-content-understanding\iac
    ```

2. Copy the sample variables file to create your own:

    ```
    copy terraform.tfvars.sample terraform.tfvars
    ```

    ![](../media/Lab-02/image05.png)

3. Open **terraform.tfvars** in VS Code:

    ```
    code terraform.tfvars
    ```

4. Update the variables with the following values:

    ```hcl
    # Azure subscription ID where resources will be deployed
    subscription_id = "<inject key="AzureSubscriptionId"></inject>"

    # Azure region for resource deployment
    resource_group_location = "westus"

    # Region abbreviation used in resource naming (keep it short, 2-3 chars)
    resource_group_location_abbr = "wu"

    # Environment name (dev, test, prod, etc.)
    environment_name = "dev"

    # Use case name for resource naming
    usecase_name = "dataext"
    ```

    ![](../media/Lab-02/image06.png)

5. **Save** the file (**Ctrl+S**) and close the editor tab.

>**Note:** The resource naming convention follows the pattern `{environment}{usecase}{location_abbr}` — for example, `devdataextwu`. All resources will include this prefix followed by a suffix indicating the resource type (e.g., `devdataextwuKv0` for Key Vault, `devdataextwucosmos0` for Cosmos DB).

6. Review the **variables.tf** file to understand all available configuration options:

    ```
    code variables.tf
    ```

    Notice the key variables:

    - **resource_group_location** — Azure region (must be a Content Understanding preview region: `westus`, `swedencentral`, or `australiaeast`).
    - **environment_name** — Environment identifier (dev, test, prod).
    - **usecase_name** — Short name for resource naming.
    - **cognitive_deployments** — Defines the Azure OpenAI model deployment (defaults to `gpt-4o`).

    ![](../media/Lab-02/image07.png)

## Task 3: Deploy the Azure infrastructure

In this task, you will initialize Terraform, review the deployment plan, and apply it to create all Azure resources.

1. Initialize Terraform to download provider plugins and modules:

    ```
    terraform init
    ```

    Wait for the initialization to complete. You should see the message **"Terraform has been successfully initialized!"**

    ![](../media/Lab-02/image08.png)

2. Generate the execution plan to preview what resources will be created:

    ```
    terraform plan
    ```

    Review the output carefully. You should see approximately **30-40 resources** planned for creation, including:

    - 1 Resource Group
    - 1 Key Vault
    - 1 Log Analytics Workspace
    - 2 Cosmos DB accounts (Mongo API + SQL API)
    - 1 Azure OpenAI deployment (gpt-4o)
    - 1 AI Services instance (Content Understanding)
    - 1 Function App with App Service Plan
    - 1 Storage Account
    - 1 Application Insights
    - Multiple role assignments for RBAC

    ![](../media/Lab-02/image09.png)

3. Apply the Terraform plan to deploy all resources:

    ```
    terraform apply -auto-approve
    ```

    ![](../media/Lab-02/image10.png)

>**Note:** The deployment typically takes **15-25 minutes** to complete. The AI Hub and Cosmos DB resources take the longest to provision. Do not close the terminal during deployment.

4. Wait for the deployment to complete. When finished, you will see a summary of all created resources and the message **"Apply complete!"** with the count of resources added.

    ![](../media/Lab-02/image11.png)

5. Take note of any output values displayed at the end — these may include resource names and endpoints you will need in later labs.

## Task 4: Verify deployed resources in the Azure Portal

In this task, you will navigate to the Azure Portal and verify that all resources were created successfully.

1. Open a web browser and navigate to **https://portal.azure.com**. Sign in with your lab credentials if not already authenticated.

    - Email/Username: <inject key="AzureAdUserEmail"></inject>
    - Password: <inject key="AzureAdUserPassword"></inject>

2. In the Azure Portal, search for **Resource groups** in the top search bar and select it.

    ![](../media/Lab-02/image12.png)

3. Find and click on the resource group named **devdataextwuRg0** (or the name matching your Terraform prefix).

    ![](../media/Lab-02/image13.png)

4. Review the list of resources in the resource group. Verify that you see the following resources:

    | Resource Type | Expected Name Pattern |
    |---|---|
    | Key Vault | `devdataextwuKv0` |
    | Log Analytics Workspace | `devdataextwuLog0` |
    | Azure Cosmos DB account (Mongo) | `devdataextwucosmos0` |
    | Azure Cosmos DB account (SQL) | `devdataextwucosmoskb0` |
    | Azure OpenAI | `devdataextwuaoai0` |
    | AI services | `devdataextwuais0` |
    | Function App | `devdataextwufunc0` |
    | App Service Plan | (associated with Function App) |
    | Storage Account | `devdataextwuSa0` |
    | Application Insights | `devdataextwuAppi` |

    ![](../media/Lab-02/image14.png)

5. Click on the **Key Vault** resource (`devdataextwuKv0`). Navigate to **Secrets** in the left menu. Verify that secrets have been created for:

    - Cosmos DB connection string
    - Azure OpenAI API key
    - AI Services subscription key

    ![](../media/Lab-02/image15.png)

## Task 5: Explore Azure AI Foundry and Content Understanding

In this task, you will navigate to Azure AI Foundry to understand how Azure Content Understanding and Azure OpenAI are configured.

1. In the Azure Portal, go back to your resource group and click on the **AI services** resource (`devdataextwuais0`).

    ![](../media/Lab-02/image16.png)

2. In the AI Services overview, note the **Endpoint** URL and the **Location**. This endpoint will be used by the application to communicate with Azure Content Understanding.

    ![](../media/Lab-02/image17.png)

3. Go back to the resource group and click on the **Azure OpenAI** resource (`devdataextwuaoai0`).

4. Navigate to **Model deployments** and verify that the **gpt-4o** model has been deployed with the following settings:

    - Model: `gpt-4o`
    - Version: `2024-08-06`
    - Deployment type: Standard

    ![](../media/Lab-02/image18.png)

5. Note the **Endpoint** and **Keys** for the Azure OpenAI resource — you will need these in the next lab to configure the application.

    ![](../media/Lab-02/image19.png)

## Task 6: Explore Azure Cosmos DB resources

In this task, you will explore the two Cosmos DB accounts and understand their different roles.

1. In your resource group, click on the **Cosmos DB account** with the Mongo API (`devdataextwucosmos0`).

    ![](../media/Lab-02/image20.png)

2. In the left menu, navigate to **Data Explorer**. Notice that the database and collections will be created when the application first runs. This Cosmos DB (Mongo API) instance will store:

    - **Configurations** collection — Extraction configuration schemas
    - **Documents** collection — Extracted document data with fields, bounding boxes, and confidence scores

    ![](../media/Lab-02/image21.png)

3. Go back to the resource group and click on the **Cosmos DB account** with the SQL API (`devdataextwucosmoskb0`).

4. Open **Data Explorer**. Notice the **knowledge-base-db** database with the **chat-history** container. This stores conversational query history per user session.

    ![](../media/Lab-02/image22.png)

5. Click on the **chat-history** container and notice the partition key is set to `/id`. This allows efficient lookups by session and user.

    ![](../media/Lab-02/image23.png)

>**Note:** The Cosmos DB SQL API instance uses role-based access control (RBAC). The Terraform deployment automatically assigns the `DocumentDB Account Contributor` and `Cosmos DB Built-in Data Contributor` roles to both the Function App managed identity and your deploying user.

# Summary

In this lab, you authenticated with Azure CLI, configured Terraform variables, deployed the complete Azure infrastructure, and verified all resources in the Azure Portal. You explored Azure AI Foundry (OpenAI + Content Understanding), Key Vault, and both Cosmos DB instances.

In the next lab, you will configure the application settings and start the Azure Function App locally.

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
