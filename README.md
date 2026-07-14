# 🛠️ Moodle lab Infrastructure

## 📌 Description
This repository contains the Terraform code to set up the infrastructure for the Moodle lab. It includes the necessary configurations to deploy Moodle on a cloud platform, ensuring a scalable and reliable environment for testing and development.
- Testing and development environment for Moodle
- Integration with cloud services for scalability
- Support of plugins and custom configurations

## 🚀 Key Features
- Terraform + AzureRM: Infrastructure as Code, updated to version v3.117.0.
- Cloud-init: Automation of Moodle installation and initial configuration.
- GitHub Actions Workflows: Pipelines for testing, deployment, and code validation.
- Modularity: .tf files and reusable variables for different scenarios.
- Integrated documentation: Guides and notes to facilitate evaluation and use.

## 📂 Repository Structure
- `.github/workflows/`: Contains GitHub Actions workflows for CI/CD.
- `main.tf`: Main Terraform configuration file.
- `variables.tf`: Definition of variables used in the Terraform configuration.
- `outputs.tf`: Outputs from the Terraform deployment.
- `README.md`: This file, providing an overview and instructions for the repository.

## ⚙️ Requirements
- Terraform >= 1.5
- Azure CLI (for Azure deployments)
- GitHub account (for using GitHub Actions)
- Access to a cloud provider Azure subscription (for Azure deployments)
- Basic knowledge of Terraform and cloud infrastructure

## ▶️ Usage
1. Clone the repository:
   ```bash
   git clone https://github.com/RenzoMedina/moodle_lab_infra.git
    
   cd moodle_lab_infra
    ```
2. Configure your cloud provider credentials (e.g., Azure CLI login).
3. Initialize Terraform:
   ```bash
   terraform init
   ```
4. Review the Terraform plan:
   ```bash
   terraform plan 
    ```
5. Apply the Terraform configuration:
    ```bash
    terraform apply
    ```
6. Follow the prompts to confirm the deployment.
7. Monitor the deployment process and access the Moodle instance once the deployment is complete.

## 🔐 Required GitHub Secrets

Before running any workflow, configure these secrets in **Settings → Secrets and variables → Actions**:

| Secret | Description |
|---|---|
| `AZURE_CLIENT_ID` | Service Principal client ID |
| `AZURE_CLIENT_SECRET` | Service Principal client secret |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID |
| `AZURE_TENANT_ID` | Azure AD tenant ID |
| `AZURE_REGION` | Azure region (e.g. `eastus`) |
| `AZURE_RESOURCE_GROUP` | Resource group for the Terraform state backend |
| `AZURE_STORAGE_ACCOUNT` | Storage account name for the `tfstate` |
| `AZURE_STORAGE_CONTAINER` | Storage container name for the `tfstate` |
| `AZURE_RESOURCE_GROUP_VM` | Resource group where the Moodle VM is deployed |
| `AZURE_VM_NAME` | Name of the Moodle VM |
| `AZURE_DISK_NAME` | Name of the VM's OS disk |
| `AZURE_SNAPSHOT_NAME` | Name to assign to the disk snapshot |
| `AZURE_SNAPSHOT_RESOURCE_GROUP` | **Persistent** resource group where snapshots are stored (must be different from `AZURE_RESOURCE_GROUP_VM`) |
| `SSH_PUBLIC_KEY` | SSH public key injected into the VM |
| `DUCKDNS_DOMAIN` | DuckDNS subdomain |
| `DUCKDNS_TOKEN` | DuckDNS API token |
| `MOODLE_DB_PASSWORD` | Moodle database user password |

## ⚙️ Workflow Order (first-time setup)

Run these workflows manually, in this exact order, before using `spin-up.yml` day to day:

1. **`setup-backend.yml`** — creates the resource group + storage account/container for the Terraform state, **and** creates the persistent `AZURE_SNAPSHOT_RESOURCE_GROUP`. Run once per environment.
2. **`spin-up.yml`** — provisions the VM and Moodle via Terraform + cloud-init.
3. **`create-snapshot.yml`** — takes a disk snapshot for backup, whenever you need one.
4. **`teardown.yml`** — destroys the VM environment (runs automatically every night via cron, or manually).

## 💾 Snapshots & Backups

Snapshots are stored in a **separate, persistent resource group** (`AZURE_SNAPSHOT_RESOURCE_GROUP`), independent from the resource group Terraform manages (`AZURE_RESOURCE_GROUP_VM`).

**Why:** the `azurerm` Terraform provider defaults to `prevent_deletion_if_contains_resources = true`, which blocks deleting a resource group if it contains resources Terraform doesn't manage. Since `az snapshot create` is run outside Terraform (via Azure CLI), a snapshot left inside the VM's resource group causes `terraform destroy` to fail with:

```
Error: deleting Resource Group "...": the Resource Group still contains Resources.
```

Keeping snapshots in their own resource group avoids this conflict entirely, and — as a bonus — means backups survive even after the ephemeral VM environment is torn down.

**Troubleshooting:** if you hit the error above, check that `create-snapshot.yml` is targeting `AZURE_SNAPSHOT_RESOURCE_GROUP` (not `AZURE_RESOURCE_GROUP_VM`), and that this resource group was created via `setup-backend.yml` before the first snapshot was taken.

## 📖 Use Cases
- **Testing and Development**: Set up a Moodle environment for testing new features, plugins, and configurations without affecting production.
- **Educational Purposes**: Use the infrastructure as a learning tool for students and educators to understand cloud infrastructure and Moodle deployment.
- **Continuous Integration**: Integrate with CI/CD pipelines to automate testing and deployment of Moodle updates and customizations.

## 📌 Project Status

Currently in development, with ongoing updates to the Terraform configurations and GitHub Actions workflows. Contributions and feedback are welcome to enhance the functionality and usability of the infrastructure.

## 👤 Author
- [**Renzo Medina** ](https://github.com/RenzoMedina)
- Backend Developer & DevOps Jr.
- Passionate about cloud infrastructure and automation.
- Designed infrastructure for Moodle lab to facilitate testing and development.