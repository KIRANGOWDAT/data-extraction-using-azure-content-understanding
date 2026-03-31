# CloudLabs ODL Setup Guide
## Data Extraction Using Azure Content Understanding

This guide walks you through deploying the ARM template and creating the On-Demand Lab (ODL) in CloudLabs admin portal.

---

## Prerequisites

Before starting, ensure you have:
- Access to **CloudLabs Admin Portal** ([admin.cloudlabs.ai](https://admin.cloudlabs.ai))
- All files pushed to a **public GitHub repository**:
  - `cloudlabs-setup/deploy-01.json` (ARM template)
  - `cloudlabs-setup/deploy-01.parameters.json` (Parameters file)
  - `cloudlabs-setup/psscript-labvm-setup.ps1` (VM setup script)
  - `cloudlabs-setup/masterdoc.json` (Lab guide manifest)
  - `labguide/Lab-01.md` through `labguide/Lab-05.md` (Lab guides)
- A valid **Azure subscription** linked to CloudLabs

---

## Step 1: Push Files to GitHub

1. Replace all `<YOUR-ORG>` placeholders in these files with your actual GitHub org/username:
   - `cloudlabs-setup/deploy-01.json` → `installscriptsUri` default value
   - `cloudlabs-setup/deploy-01.parameters.json` → `installscriptsUri` value
   - `cloudlabs-setup/masterdoc.json` → all `RawFilePath` URLs
   - `cloudlabs-setup/psscript-labvm-setup.ps1` → the `git clone` URL

2. Push everything to your GitHub repo's `main` branch.

3. Verify the raw URLs work by opening in a browser:
   ```
   https://raw.githubusercontent.com/<YOUR-ORG>/data-extraction-using-azure-content-understanding/main/cloudlabs-setup/deploy-01.json
   ```

---

## Step 2: Create Azure Template in CloudLabs

1. Log in to **[admin.cloudlabs.ai](https://admin.cloudlabs.ai)**

2. Navigate to **Templates** from the left sidebar menu

3. Click **+ ADD** to create a new template

4. Fill in the **Template Details**:

   | Field | Value |
   |-------|-------|
   | **Name** | `Data Extraction Using Azure Content Understanding` |
   | **Code** | `data-extraction-cu` |
   | **Cloud Platform** | `Azure` |
   | **Description** | `Hands-on lab for building document extraction pipelines using Azure Content Understanding, Azure OpenAI, Cosmos DB, and Azure Functions` |
   | **Subscription Type** | `Dedicated` (each user gets their own subscription) |

5. Under **Deployment Plan**, click **+ ADD DEPLOYMENT**:

   | Field | Value |
   |-------|-------|
   | **Deployment Name** | `LabVM Deployment` |
   | **ARM Template Link** | `https://raw.githubusercontent.com/<YOUR-ORG>/data-extraction-using-azure-content-understanding/main/cloudlabs-setup/deploy-01.json` |
   | **ARM Parameter Link** | `https://raw.githubusercontent.com/<YOUR-ORG>/data-extraction-using-azure-content-understanding/main/cloudlabs-setup/deploy-01.parameters.json` |
   | **Region** | Select your preferred regions (e.g., `East US`, `West US 2`, `West Europe`) |
   | **Deployment Wait Time** | `30` minutes (allows Custom Script Extension to finish) |

6. Under **Deployment Output Parameters** — these map ARM template outputs to CloudLabs environment variables that users see:
   - These are automatically picked up from the `outputs` section of `deploy-01.json`
   - Verify these outputs are listed:
     - `VM DNS Name`
     - `VM Admin Username`
     - `VM Admin Password`
     - `Trainer UserName`
     - `Trainer Password`
     - `Deployment ID`

7. Under **VM Configuration**, click **+ ADD VM**:

   | Field | Value |
   |-------|-------|
   | **VM Name** | `LabVM` |
   | **VM Access Type** | `RDP` |
   | **Server DNS Name** | Select output: `VM DNS Name` |
   | **Server Username** | Select output: `VM Admin Username` |
   | **Server Password** | Select output: `VM Admin Password` |
   | **Enable VM Access Over HTTP** | `Yes` ✅ (Enables RDP via browser—critical for CloudLabs) |

8. Under **Master Document** (for lab guide rendering):

   | Field | Value |
   |-------|-------|
   | **GitHub Master Document URL** | `https://raw.githubusercontent.com/<YOUR-ORG>/data-extraction-using-azure-content-understanding/main/cloudlabs-setup/masterdoc.json` |

9. Under **Permissions** (optional):
   - Set **Role** to `Contributor` on the resource group scope
   - This ensures users can deploy Terraform resources inside their lab

10. Click **SUBMIT** to save the template

---

## Step 3: Test the Template (IMPORTANT)

Before creating the ODL, test the template deployment:

1. Go to **Templates** → find your template → click **Test**
2. Select a region and click **Deploy**
3. Wait for deployment to complete (15-30 minutes)
4. Verify:
   - [ ] VM is created and accessible via RDP
   - [ ] All software is installed (run `Validate-LabSetup.ps1` on Desktop)
   - [ ] Repository is cloned to `C:\LabFiles\`
   - [ ] VS Code opens with the correct folder
   - [ ] Lab guide renders correctly in CloudLabs portal
5. **Delete** the test deployment after verification

---

## Step 4: Create On-Demand Lab (ODL)

1. In CloudLabs admin portal, navigate to **On Demand Labs** from the left sidebar

2. Click **+ ADD ON DEMAND LAB**

3. Fill in the **ODL Details**:

   | Field | Value |
   |-------|-------|
   | **Name** | `Data Extraction Using Azure Content Understanding` |
   | **Template** | Select: `Data Extraction Using Azure Content Understanding` (created in Step 2) |
   | **Description** | `Learn to build intelligent document extraction pipelines using Azure Content Understanding, Azure OpenAI, Cosmos DB, Azure Functions, and Terraform` |
   | **Tags** | `Azure`, `AI`, `Content Understanding`, `Terraform`, `Azure Functions` |

4. Configure **Registration Settings**:

   | Field | Value |
   |-------|-------|
   | **Status** | `Registration Open` |
   | **Approval Type** | `Automatic` (or `Registration Required` for controlled access) |
   | **Max Users** | Set based on your capacity (e.g., `50`) |

5. Configure **Duration & Scheduling**:

   | Field | Value |
   |-------|-------|
   | **Duration** | `480` minutes (8 hours — allows time for all 5 labs) |
   | **Running / Hot Instances** | `0` (deploy on demand) or `5` (pre-deployed for instant access) |
   | **VM Uptime** | `480` minutes |
   | **Expiry Date** | Set as needed |

6. Configure **Lab Guide**:

   | Field | Value |
   |-------|-------|
   | **GitHub Master Document URL** | `https://raw.githubusercontent.com/<YOUR-ORG>/data-extraction-using-azure-content-understanding/main/cloudlabs-setup/masterdoc.json` |

7. Configure **Custom Tabs / Output Variables** (optional):
   - Environment variables from ARM template outputs will be automatically displayed to users
   - Users will see: VM DNS Name, VM Admin Username, VM Admin Password, Deployment ID

8. Click **SUBMIT** to create the ODL

---

## Step 5: Generate Registration Link

1. Go to **On Demand Labs** → find your ODL
2. Click on the ODL name to open details
3. Copy the **Registration URL** — this is what you share with lab participants
4. Users who visit this URL will:
   - Register with their email
   - Get a dedicated Azure environment provisioned
   - See the lab guide in a side panel
   - Access the VM via browser-based RDP (no RDP client needed)

---

## File Summary

| File | Purpose |
|------|---------|
| `cloudlabs-setup/deploy-01.json` | ARM template — deploys Windows 11 VM with VNet, NSG, Public IP, NIC, and Custom Script Extension |
| `cloudlabs-setup/deploy-01.parameters.json` | Parameter defaults — CloudLabs overrides `adminPassword` and `deploymentId` at runtime |
| `cloudlabs-setup/psscript-labvm-setup.ps1` | VM bootstrap script — installs Python 3.12, Azure CLI, Terraform, Git, Node.js 18, Azure Functions Core Tools v4, VS Code + extensions, clones repo |
| `cloudlabs-setup/masterdoc.json` | Lab guide manifest — tells CloudLabs portal which markdown files to render and in what order |
| `labguide/Lab-01.md` through `Lab-05.md` | The 5 lab guide markdown files |

---

## Troubleshooting

### VM setup script fails
- Check logs at: `C:\WindowsAzure\Logs\LabSetup.log` on the VM
- Check if `C:\WindowsAzure\Logs\LabSetupComplete.txt` exists (indicates success)
- Common issues: GitHub raw URL unreachable, Chocolatey install timeout

### Lab guide not rendering
- Verify the `masterdoc.json` URL is accessible (paste raw GitHub URL in browser)
- Ensure all `RawFilePath` URLs in masterdoc.json are valid
- Check that markdown files use correct image paths: `../media/Lab-XX/image-name.png`

### VM not accessible via browser RDP
- Ensure **Enable VM Access Over HTTP** is set to `Yes` in the template VM configuration
- Verify NSG allows port 443 inbound
- Check that the VM DNS output is correctly mapped

### Deployment timeout
- Default Custom Script Extension timeout is 90 minutes
- If installations take too long, increase the **Deployment Wait Time** in the template
- Consider pre-baking a VM image with tools installed for faster deployment

---

## Architecture Overview

```
CloudLabs Admin Portal
├── Template (deploy-01.json)
│   ├── ARM Deployment
│   │   ├── Resource Group (auto-created)
│   │   ├── VNet + Subnet + NSG
│   │   ├── Public IP (with DNS label)
│   │   ├── NIC
│   │   └── Windows 11 VM (Standard_D4s_v3)
│   │       └── Custom Script Extension
│   │           └── psscript-labvm-setup.ps1
│   │               ├── Chocolatey
│   │               ├── Python 3.12
│   │               ├── Azure CLI
│   │               ├── Terraform
│   │               ├── Git + Node.js 18
│   │               ├── Azure Functions Core Tools v4
│   │               ├── VS Code + Extensions
│   │               └── Repo cloned to C:\LabFiles\
│   └── Lab Guide (masterdoc.json → Lab-01 to Lab-05)
└── ODL (Registration → User gets VM + Lab Guide)
```
