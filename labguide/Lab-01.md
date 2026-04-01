# Exercise 1: Environment Setup and Architecture Overview

### Estimated Duration: 30 Minutes

## Overview

In this exercise, you will verify your lab environment, explore the pre-cloned project repository, and study the solution architecture. By the end of this exercise, you will have a clear understanding of the project structure, the Azure services involved, and the three core workflows — Document Enquiry, Configuration Upload, and Document Ingestion — that power the intelligent document extraction pipeline.

## Objectives

In this exercise, you will complete the following tasks:

- Task 1: Verify the lab environment
- Task 2: Explore the project structure
- Task 3: Review the solution architecture
- Task 4: Explore Azure Content Understanding concepts

### Task 1: Verify the lab environment

In this task, you will run a pre-built validation script to confirm that all required tools are installed and ready on your lab virtual machine.

1. On your lab VM desktop, right-click the **Validate-LabSetup.ps1** **(1)** file and select **Run with PowerShell** **(2)**.

   ![](../media/Lab-01/image01.png)

1. The script checks all required tools automatically. Verify that every item shows **[PASS]** in green:

   | Tool | Required Version |
   |---|---|
   | Python | 3.12 or later |
   | Azure CLI | 2.60 or later |
   | Terraform | 1.5.0 or later |
   | Azure Functions Core Tools | v4.x |
   | Git | Any |
   | Node.js | 18.x or later |
   | VS Code | Any |
   | Lab Repository | Present at `C:\LabFiles` |

   ![](../media/Lab-01/image02.png)

   >**Note:** If any item shows **[FAIL]**, contact your lab administrator. All tools have been pre-installed on your lab VM.

### Task 2: Explore the project structure

In this task, you will open the pre-cloned repository in Visual Studio Code and examine how the codebase is organized.

1. On the desktop, double-click the **Visual Studio Code** shortcut. It opens directly into the lab repository at `C:\LabFiles\data-extraction-using-azure-content-understanding`.

   ![](../media/Lab-01/image03.png)

1. In the VS Code **Explorer** panel on the left, review the top-level folder structure:

   | Folder/File | Purpose |
   |---|---|
   | `configs/` | Sample extraction configuration JSON files |
   | `docs/` | Architecture documentation and design decisions |
   | `document_samples/` | Sample PDF documents for testing |
   | `iac/` | Terraform infrastructure-as-code modules |
   | `src/` | Python source code (Azure Functions application) |
   | `tests/` | Unit and integration tests |
   | `deploy.sh` | One-click deployment script |
   | `requirements.txt` | Python package dependencies |

   ![](../media/Lab-01/image04.png)

1. Click on the **src/** **(1)** folder to expand it. This is the main application code:

   | Subfolder | Purpose |
   |---|---|
   | `configs/` | Application configuration management (YAML loader) |
   | `controllers/` | API endpoint logic (health check, inference, ingestion) |
   | `decorators/` | Custom error handling decorators |
   | `models/` | Pydantic data models for requests, responses, and documents |
   | `routes/` | Azure Functions HTTP trigger route definitions |
   | `samples/` | Sample `.http` request files for testing APIs |
   | `services/` | Business logic (CU client, Cosmos DB, LLM manager, blob storage) |
   | `utils/` | Utility functions (citation cleaner, monitoring, singleton) |

   ![](../media/Lab-01/image05.png)

1. Click on the **iac/** **(1)** folder to expand it. Notice the modular Terraform structure with separate modules for each Azure service:

   | Module | Azure Resource |
   |---|---|
   | `modules/ai/` | AI Hub, AI Foundry Project, AI Services |
   | `modules/cosmos_db/` | Azure Cosmos DB (Mongo API and SQL API) |
   | `modules/function_app/` | Azure Function App (Python, Linux) |
   | `modules/keyvault/` | Azure Key Vault |
   | `modules/loganalytics/` | Azure Log Analytics Workspace |
   | `modules/storage_account/` | Azure Storage Account |
   | `modules/azure_openai/` | Azure OpenAI deployment (gpt-4o) |
   | `modules/appinsights/` | Application Insights |

   ![](../media/Lab-01/image06.png)

### Task 3: Review the solution architecture

In this task, you will open the architecture documentation from the repository and study the three core workflows that make up the solution.

1. In VS Code Explorer, expand the **docs** **(1)** folder and click on **architecture.md** **(2)** to open it.

   ![](../media/Lab-01/image07.png)

1. At the top of the file, you will find the **Table of Contents** listing the three main workflows. Scroll down to the **Proposed system architecture** section.

   ![](../media/Lab-01/image08.png)

1. Notice the **architecture diagram** image reference at line 13: `![architecture diagram](./images/simplified-arch.drawio.png)`. To view the actual diagram, expand the **docs** > **images** **(1)** folder in the Explorer panel and click on **simplified-arch.drawio.png** **(2)**.

   ![](../media/Lab-01/image09.png)

1. Review the architecture diagram. The solution implements three main workflows:

   - **Document Enquiry** — Users ask natural language questions about ingested documents. Azure OpenAI (via Semantic Kernel) retrieves data from Cosmos DB and returns a response with inline citations.

   - **Configuration Upload** — Administrators upload JSON extraction configurations. The system validates them and creates Azure Content Understanding analyzer schemas.

   - **Document Ingestion** — PDF documents are submitted for extraction. Azure Content Understanding extracts structured fields with bounding boxes and confidence scores, storing results in Cosmos DB.

   ![](../media/Lab-01/image10.png)

1. Scroll down in **architecture.md** to review the **Document enquiry workflow** sequence diagram written in Mermaid syntax. This flow shows:

   - The user submits a natural language query to the Azure Function.
   - Semantic Kernel extracts the collection ID from the query.
   - The system retrieves all extracted fields for that collection from Cosmos DB.
   - Azure OpenAI formulates a response with inline citations referencing source documents.

1. Continue scrolling to review the **Configuration upload workflow** sequence diagram. This flow shows:

   - The user uploads a JSON configuration file via the API.
   - The configuration is validated and stored in Cosmos DB.
   - An Azure Content Understanding analyzer schema is created for each collection row.

1. Scroll further to review the **Document Ingestion Flow** sequence diagram. This flow shows:

   - A PDF document is uploaded and triggers the ingestion function.
   - The extraction configuration is retrieved from Cosmos DB.
   - Azure Content Understanding extracts fields per the analyzer schema.
   - Extracted fields (with bounding boxes and confidence scores) are stored in Cosmos DB.

### Task 4: Explore Azure Content Understanding concepts

In this task, you will review key design decisions and explore the sample configuration and documents included in the repository.

1. In VS Code Explorer, expand **docs** > **design** > **decisions** **(1)** and click on **content-undestanding-vs-mllm-docint.md** **(2)**. This is an Architecture Decision Record (ADR) explaining why Azure Content Understanding was chosen over alternatives like Document Intelligence.

   ![](../media/Lab-01/image11.png)

1. Review the key advantages of Azure Content Understanding highlighted in the document:

   - **Multimodal ingestion** — Supports documents, images, video, and audio content.
   - **Strongly-typed schemas** — Define exact field names, types, and descriptions for extraction.
   - **Confidence scores** — Each extracted field includes a score indicating extraction reliability.
   - **Bounding boxes** — Precise document coordinates for every extracted field, enabling traceability.
   - **Analyzer schemas** — Reusable, versioned configurations that define what to extract.

1. Navigate back to the Explorer panel. Expand the **configs** **(1)** folder and click on **document-extraction-v1.0.json** **(2)** to open the sample extraction configuration.

   ![](../media/Lab-01/image12.png)

1. Review the configuration structure:

   - **id** and **version** — Uniquely identify this extraction configuration.
   - **collection_rows** — An array defining document types. Each row specifies a `data_type`, a `field_schema` (list of fields to extract), and an `analyzer_id` that maps to an Azure Content Understanding analyzer.
   - **field_schema** — Each field has a `name`, `type` (string, integer, float, etc.), a human-readable `description`, and a `method` (`extract` for CU extraction or `generate` for LLM generation).

   ![](../media/Lab-01/image13.png)

1. Expand the **document_samples** **(1)** folder. Notice the sample PDF — **Agreement_for_leasing_or_renting_certain_Microsoft_Software_Products.pdf** **(2)**. This is the lease agreement document you will ingest and query in later exercises.

   ![](../media/Lab-01/image14.png)

   >**Note:** In a production scenario, hundreds or thousands of such documents would be ingested automatically via blob storage triggers.

## Summary

In this exercise, you have completed the following:

1. Verified all lab prerequisites by running the **Validate-LabSetup.ps1** script.
2. Explored the **project repository structure** including `src/`, `iac/`, `configs/`, `docs/`, and `tests/` folders.
3. Reviewed the **solution architecture** and three core workflows — Document Enquiry, Configuration Upload, and Document Ingestion.
4. Explored **Azure Content Understanding** concepts, the ADR document, sample extraction configuration, and sample lease agreement PDF.

### You have successfully completed this exercise. Click **Next >>** to proceed to the next exercise.

© 2026 Microsoft Corporation. All rights reserved.

By using this demo/lab, you agree to the following terms:

The technology/functionality described in this demo/lab is provided by Microsoft Corporation for purposes of obtaining your feedback and to provide you with a learning experience. You may only use the demo/lab to evaluate such technology features and functionality and provide feedback to Microsoft. You may not use it for any other purpose. You may not modify, copy, distribute, transmit, display, perform, reproduce, publish, license, create derivative works from, transfer, or sell this demo/lab or any portion thereof.

COPYING OR REPRODUCTION OF THE DEMO/LAB (OR ANY PORTION OF IT) TO ANY OTHER SERVER OR LOCATION FOR FURTHER REPRODUCTION OR REDISTRIBUTION IS EXPRESSLY PROHIBITED.

THIS DEMO/LAB PROVIDES CERTAIN SOFTWARE TECHNOLOGY/PRODUCT FEATURES AND FUNCTIONALITY, INCLUDING POTENTIAL NEW FEATURES AND CONCEPTS, IN A SIMULATED ENVIRONMENT WITHOUT COMPLEX SET-UP OR INSTALLATION FOR THE PURPOSE DESCRIBED ABOVE. THE TECHNOLOGY/CONCEPTS REPRESENTED IN THIS DEMO/LAB MAY NOT REPRESENT FULL FEATURE FUNCTIONALITY AND MAY NOT WORK THE WAY A FINAL VERSION MAY WORK. WE ALSO MAY NOT RELEASE A FINAL VERSION OF SUCH FEATURES OR CONCEPTS. YOUR EXPERIENCE WITH USING SUCH FEATURES AND FUNCTIONALITY IN A PHYSICAL ENVIRONMENT MAY ALSO BE DIFFERENT.
