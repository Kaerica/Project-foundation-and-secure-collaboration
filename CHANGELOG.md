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
- Added an opt-in application read-only guard for POST and PATCH inventory
  routes, with tests ensuring rejected writes never reach the store. Terraform
  cloud-init enables the guard for newly provisioned VMs.
- Added Terraform configuration for public HTTP load-balancer ingress and
  health probes. Applied and verified the public endpoint
  `http://172.202.88.20`; GET `/health` and `/` both returned HTTP 200.
- Upgraded Bastion to Standard and enabled native client tunnelling for Ansible
  CD; Terraform state confirms both settings. Standard Bastion may incur
  higher ongoing cost.
- Updated architecture and setup documentation, including the HTTP-only
  ingress limitation and the fact that Terraform ignores changes to VM
  `custom_data`.
- Updated Ansible to install Docker and Compose, then verify that the healthy
  application is running the requested image ID.
- Made CD call the reusable CI workflow and wait for it to pass; added Linux
  Ansible syntax validation to CI and limited CD to pushes to `main`.
- Validation of the current local source: 26 application tests pass, lint
  passes, and the Linux Ansible syntax check and GitHub workflow YAML parsing
  pass. Terraform was unchanged in this follow-up; earlier Terraform format,
  validation, and plan results remain as previously recorded. The apply's
  attempt to disable VM extension operations failed because Azure extensions
  were present; no extensions were removed. Terraform now ignores this field
  for the existing VM.
- Remaining integration work includes verifying or updating the existing
  production VM startup wrapper, adding required GitHub deployment secrets,
  deciding whether a private ACR path is required, and demonstrating a
  successful end-to-end deployment. No changes in this worktree have been
  applied to Azure or committed/pushed.
