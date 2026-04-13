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