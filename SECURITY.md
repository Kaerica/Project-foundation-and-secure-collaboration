# Security

This document describes the security scanning built into the Inventory Manager CI pipeline, what the scans found, how each finding was handled, and the risks the team has accepted.

## Security Scans in CI

All scans run in [.github/workflows/ci.yml](.github/workflows/ci.yml) on every push to a non-main branch and on every pull request targeting `main`. If a scan fails, its CI job fails. A failing job blocks a merge into `main` only if that job is set as a required status check in branch protection (see [Branch protection](#other-security-practices)).

| # | Scan type | Tool | CI job / step | Failure threshold |
|---|-----------|------|---------------|-------------------|
| 1 | Dependency scanning | `npm audit` | `dependency-scan` → *Dependency scan (npm audit)* | Fails on any **HIGH** or **CRITICAL** advisory |
| 2 | Container image scanning | Trivy `0.58.1` | `build` → *Container scan (Trivy) - enforce* | Fails on **HIGH/CRITICAL** vulnerabilities **that have a fix available** (`--ignore-unfixed`) |
| 3 | IaC / config scanning | Checkov `3.2.500` | `iac-scan` | Fails on any failed check (Terraform, Dockerfile, GitHub Actions), except the documented accepted risks |

### Why these thresholds

- **HIGH/CRITICAL only.** LOW and MEDIUM findings are reported but don't block merges. Blocking on every finding would make the pipeline fail all the time over issues that can't be exploited here, and people would start ignoring it.
- **`--ignore-unfixed` for Trivy.** A vulnerability with no published fix can't be fixed by changing our code or rebuilding the image. Blocking on it would stop every merge without making anything safer. Unfixed vulnerabilities still show up in the full report (see below) so we can track them.
- **Pinned scanner versions.** Trivy and Checkov run from pinned Docker images, not floating `@latest` tags or third-party wrapper actions. Results stay reproducible, and the risk of a compromised action tag running in our pipeline goes down.

### Reports

- The **full Trivy report** (all severities, including unfixed) is uploaded as the `trivy-report` build artifact on every run. You can download it from the Actions run summary.
- `npm audit` and Checkov results are printed in the job logs.

## Findings and Remediation

Scans were run against the `main` branch at commit `54e4bf5` before any changes were made.

### 1. Dependency scan (`npm audit`)

| Result | Action |
|--------|--------|
| **0 vulnerabilities** in production or development dependencies | None needed. The scan stays in CI to catch new advisories. |

The application uses the `pg` runtime dependency to connect to PostgreSQL. Its only dev dependency is `standard` (the linter).

### 2. Container image scan (Trivy)

**Initial result:** 45 HIGH/CRITICAL findings in `inventory-manager` built from `node:22-bookworm-slim`.

#### Finding 2a: 10 HIGH vulnerabilities in Node packages (FIXED)

| Package | CVE(s) | Location |
|---------|--------|----------|
| brace-expansion 2.0.2 | CVE-2026-102276, CVE-2026-102278, CVE-2026-13149, CVE-2026-14257, CVE-2026-69152 | `/usr/local/lib/node_modules/npm/...` |
| ip-address 10.1.0 | CVE-2026-69192 | `/usr/local/lib/node_modules/npm/...` |
| pacote 19.0.2 / 20.0.1 | CVE-2026-9496 | `/usr/local/lib/node_modules/npm/...` |
| picomatch 4.0.3 | CVE-2026-33671 | `/usr/local/lib/node_modules/npm/...` |
| sigstore 3.1.0 | CVE-2026-48815 | `/usr/local/lib/node_modules/npm/...` |

**Root cause:** None of these packages belong to our application. They all come from the **npm CLI that ships inside the official Node base image**. The application needs npm only at build time (in the `builder` stage) and never at runtime.

**Remediation:** In the `runtime` stage of the [Dockerfile](Dockerfile):

- The bundled `npm`, `npx`, `corepack` and `yarn` are deleted.
- The container starts with `CMD ["node", "index.js"]` instead of `npm start`.

**Verification:** After rebuilding, the image has **0 Node package vulnerabilities**. The container starts, `/health` returns `{"status":"ok"}`, it still runs as the non-root `node` user, and `npm` is no longer on the PATH.

This change also shrinks the attack surface: anyone who gets into the container no longer has a package manager to pull in extra tools.

#### Finding 2b: 35 OS package vulnerabilities in Debian 12 (ACCEPTED, monitored)

| Package(s) | CVE | Severity | Debian status |
|------------|-----|----------|---------------|
| zlib1g | CVE-2023-45853 | CRITICAL | `will_not_fix` |
| util-linux family (mount, libmount1, libblkid1, libuuid1, bsdutils, ...) | CVE-2026-53613 | HIGH | `affected` (no fix) |
| libsystemd0, libudev1 | CVE-2026-16742 | HIGH | `fix_deferred` |
| ncurses (libtinfo6, ncurses-base, ncurses-bin) | CVE-2025-69720 | HIGH | `affected` (no fix) |
| gzip, libacl1, perl-base, others | various | HIGH | `fix_deferred` / `affected` |

See [Accepted Risks](#accepted-risks) for the reasoning.

### 3. IaC scan (Checkov)

**Initial result on `main`:** Terraform had 13 passed checks and 2 failed. GitHub Actions had 31 passed and 1 failed. The Dockerfile had 53 passed and 0 failed.

| Check | Resource | Result |
|-------|----------|--------|
| **CKV2_GHA_1**: top-level workflow permissions not restricted | `.github/workflows/ci.yml` | **FIXED**: added `permissions: contents: read` so the `GITHUB_TOKEN` is read-only |
| **CKV_AZURE_119**: network interface should not use a public IP | `azurerm_network_interface.inventory` | **FIXED**: the application VM has no public IP and is reached through Azure Bastion |

**Current unfiltered run:** Terraform passed 24 checks and failed 10; Dockerfile passed 53/53; GitHub Actions passed 76/76. The VM extension and database-subnet NSG findings were fixed. The remaining 10 findings are the documented service-tier and PostgreSQL network-model exceptions below. With the CI exclusions listed below, the Checkov run has no failed checks. Checkov also reported that it could not resolve its optional Prisma Cloud guidelines host; the scan still produced results.

## Accepted Risks

| ID | Risk | Why it is accepted | Mitigations / follow-up |
|----|------|--------------------|-------------------------|
| Trivy OS CVEs (Finding 2b) | 34 HIGH and 1 CRITICAL vulnerability in Debian base packages | Debian has **no fixed version** for any of them (`will_not_fix`, `fix_deferred` or `affected`), so rebuilding can't remove them. Most are in tools the app never calls (`mount`, `perl`, `gzip`, `ncurses`), and several (util-linux mount TOCTOU, systemd-homed) need local privileged access, which the container doesn't give: it runs as non-root `node`. The zlib CVE-2023-45853 is in `minizip`, which neither Node nor the app uses. | The CI gate fails as soon as Debian publishes a fix, because those findings then count as "fixable". The full report is uploaded on every run. Future option: move to a distroless or Alpine runtime image to remove most OS packages. |
| PostgreSQL resilience | `CKV_AZURE_136`: geo-redundant backups are disabled. | This is a single-region development database; enabling cross-region backup has additional cost and requires a supported region/configuration. | Public access is disabled, the database is on its delegated private subnet, private DNS is linked to the VNet, and the application subnet is explicitly allowed to reach PostgreSQL. Revisit backups for production. |
| PostgreSQL private-network model | `CKV2_AZURE_57` expects a Private Link endpoint. | This server uses PostgreSQL Flexible Server's delegated-subnet (VNet integration) mode, an Azure-supported private-access model with no public endpoint; it is not the public-access-plus-private-endpoint mode. | See [Azure PostgreSQL private access networking](https://learn.microsoft.com/azure/postgresql/network/concepts-networking-private). |
| Basic ACR limitations | `CKV_AZURE_139` and several other checks flag public access and Premium security/resilience features. The current registry is Basic and public. | Premium Private Link, dedicated data endpoints, zone/geo redundancy, quarantine, and trusted-image controls increase cost. The team has not selected or approved that upgrade. | Admin access is disabled and the VM receives `AcrPull` via managed identity, but the registry is **not private**. This remains an assignment gap until Premium Private Link and an in-network publishing path are approved and implemented. |

## Other Security Practices

- **Non-root container:** the runtime image runs as the `node` user.
- **Multi-stage build:** build tooling stays in the `builder` stage, and only the app files and production `node_modules` are copied into the runtime image.
- **No secrets in the repository:** `.env` and `*.tfvars` are git-ignored, and only `.env.example` and `terraform.tfvars.example` with placeholders are committed.
- **Least-privilege CI token:** the workflow's `GITHUB_TOKEN` has read-only `contents` permission.
- **Branch protection:** Changes reach `main` through pull requests. The `build` and `iac-scan` checks run on every PR, but they block merges only when they are set as required status checks under Settings → Branches.

## Running the Scans Locally

You need Docker and Node.js installed.

```bash
# 1. Dependency scan
npm ci
npm audit --audit-level=high

# 2. Container scan
docker build -t inventory-manager:local .
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:0.58.1 image --severity HIGH,CRITICAL --ignore-unfixed inventory-manager:local

# 3. IaC scan (run from the repository root)
docker run --rm -v "$(pwd)":/repo -w /repo bridgecrew/checkov:3.2.500 \
  --directory . --framework terraform dockerfile github_actions \
  --skip-check CKV_AZURE_136,CKV_AZURE_166,CKV_AZURE_163,CKV_AZURE_139,CKV_AZURE_165,CKV_AZURE_167,CKV_AZURE_237,CKV_AZURE_233,CKV_AZURE_164,CKV2_AZURE_57 --compact
```

On Git Bash for Windows, put `MSYS_NO_PATHCONV=1` in front of the `docker run` commands.

## Reporting a Vulnerability

If you find a security issue in this project, please don't open a public issue. Contact the repository maintainers directly through GitHub and include steps to reproduce it.
