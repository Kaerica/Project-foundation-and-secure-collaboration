# Changelog

This file summarizes the repository's progression from the project foundation
through containerization, DevSecOps, and the summative infrastructure work.

## Formative 1 — Project Foundation

- Defined the Inventory Manager problem, target users, product requirements,
  and team responsibilities.
- Established the Node.js application and core inventory features for listing,
  adding, and updating products, including low-stock detection and validation.
- Added application setup documentation and automated tests.
- Used Git branches and pull requests to combine team contributions.

## Formative 2 — Containerization and CI

- Added a non-root Docker setup and a Docker Compose environment with
  PostgreSQL-backed persistence.
- Added application health reporting and database integration checks.
- Added GitHub Actions CI for linting, tests, PostgreSQL integration, and image
  build checks.
- Added dependency, container image, and infrastructure security scans.

## Formative 3 — Security, CI, and DevSecOps

- Added GitHub Actions checks for dependency advisories, container image
  vulnerabilities, and Terraform, Dockerfile, and workflow configuration.
- Set CI thresholds for HIGH/CRITICAL dependency advisories and fixable
  HIGH/CRITICAL image vulnerabilities; documented accepted Checkov exceptions.
- Created SECURITY.md to record scan methods, findings, remediations, accepted
  risks, and responsible vulnerability reporting.
- Documented the security architecture, local/cloud setup, and deployment
  limitations in README.md.
- Verified a successful pull-request CI run: npm audit reported no
  vulnerabilities; Trivy reported 37 HIGH and 1 CRITICAL unfixable OS findings;
  Checkov reported zero failed checks. The live ruleset requires review but has
  no required CI status checks configured.

## Summative — Infrastructure as Code and Deployment

- Added Azure Terraform resources for a virtual network, Bastion, private
  application VM, private PostgreSQL Flexible Server, NAT Gateway, network
  security rules, and Azure Container Registry.
- Added cloud-init configuration for the VM to install and run the application
  container using a managed identity for ACR pulls.
- Defined a public Standard Load Balancer HTTP endpoint and database-backed
  health probe; cloud deployment runs the API read-only until HTTPS and
  authorization are available.
- Documented the current limitations: ACR uses a public endpoint, no public
  registry endpoint, the Load Balancer and endpoint still need to be applied
  and verified, and the proposed Ansible-based CD workflow is blocked by the
  current Basic Bastion SKU.
- Remaining work includes a compliant private registry path, Bastion/runner
  setup for CD, verified live deployment, and end-to-end deployment evidence.
