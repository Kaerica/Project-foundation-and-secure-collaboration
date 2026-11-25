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
- **Checkov exclusions.** The workflow skips `CKV_AZURE_136`, `CKV_AZURE_166`, `CKV_AZURE_165`, `CKV_AZURE_167`, `CKV_AZURE_237`, `CKV_AZURE_233`, `CKV_AZURE_164`, and `CKV2_AZURE_57`. These are explicit exceptions, not passing checks; review them before production or infrastructure changes.

### Reports

- The **full Trivy report** (all severities, including unfixed) is uploaded as the `trivy-report` build artifact on every run. You can download it from the Actions run summary.
- `npm audit` and Checkov results are printed in the job logs.

### Latest verified pull-request run

The latest run checked during this review was [CI Pipeline run 45286941188](https://github.com/Kaerica/Project-foundation-and-secure-collaboration/actions/runs/45286941188), triggered by pull request #37 on November 23, 2026, for commit `716c11be3dc90fa4d87fe6228bf4ba22a359166e`. All three jobs succeeded:

| Job / check | Verified result |
|---|---|
| `dependency-scan` | `npm audit` reported 0 vulnerabilities. |
| Trivy in `build` | The report contained 37 HIGH and 1 CRITICAL Debian 12.15 OS findings; all 38 had no fixed version. The gate passed because it rejects only fixable HIGH/CRITICAL findings. The Node package scan had no HIGH/CRITICAL findings. |
| `iac-scan` | Checkov reported 24 Terraform, 53 Dockerfile, and 132 GitHub Actions checks passed, with 0 failed checks. |

The full Trivy report is available as the `trivy-report` artifact on that run. These results describe that pull-request commit; they do not certify every later commit or a live Azure deployment.

The local `npm audit --json` check during this review also reported 0 vulnerabilities (280 dependencies: 14 production, 266 development, and 1 optional).

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

**Earlier unfiltered run:** Terraform passed 24 checks and failed 10; Dockerfile passed 53/53; GitHub Actions passed 76/76. The VM extension and database-subnet NSG findings were fixed. The remaining 10 findings are the documented service-tier and PostgreSQL network-model exceptions below. With the exclusions listed above, the latest verified pull-request Checkov run had no failed checks. Checkov also reported that it could not resolve its optional Prisma Cloud guidelines host; the scan still produced results.

## Accepted Risks

| ID | Risk | Why it is accepted | Mitigations / follow-up |
|----|------|--------------------|-------------------------|
| Trivy OS CVEs (Finding 2b) | The initial scan found 34 HIGH and 1 CRITICAL Debian base-package vulnerabilities. The latest verified PR report found 37 HIGH and 1 CRITICAL OS findings in Debian 12.15. | The latest report lists no fixed version for any of those 38 findings, so the configured fixable-only gate does not fail on them. Most are in OS packages rather than application dependencies; the container runs as non-root `node`. These remain known findings, not proof of zero image vulnerabilities. | Recheck the uploaded full report regularly and when the base image changes. The CI gate fails on fixable HIGH/CRITICAL findings. Consider a supported minimal runtime image to reduce OS packages. |
| PostgreSQL resilience | `CKV_AZURE_136`: geo-redundant backups are disabled. | This is a single-region development database; enabling cross-region backup has additional cost and requires a supported region/configuration. | Public access is disabled, the database is on its delegated private subnet, private DNS is linked to the VNet, and the application subnet is explicitly allowed to reach PostgreSQL. Revisit backups for production. |
| PostgreSQL private-network model | `CKV2_AZURE_57` expects a Private Link endpoint. | This server uses PostgreSQL Flexible Server's delegated-subnet (VNet integration) mode, an Azure-supported private-access model with no public endpoint; it is not the public-access-plus-private-endpoint mode. | See [Azure PostgreSQL private access networking](https://learn.microsoft.com/azure/postgresql/network/concepts-networking-private). |
| Private ACR and publishing runner | Terraform now configures Premium ACR with public network access disabled, a Private Link endpoint and private DNS, plus a VNet runner with registry-scoped managed-identity permissions. The runner must be registered and safely restricted in GitHub manually. | Premium ACR, Private Link, and a dedicated VM cost more than Basic ACR and GitHub-hosted CI. No Azure deployment or cost approval is implied by these code changes. | The CD runner verifies private ACR DNS and disabled public access before pushing. Restrict its runner group to this repository's trusted `cd.yml` workflow on `main`; never allow PR workflows on it. Verify the deployment and its actual network controls after an approved apply. |

## Other Security Practices

- **Non-root container:** the runtime image runs as the `node` user.
- **Multi-stage build:** build tooling stays in the `builder` stage, and only the app files and production `node_modules` are copied into the runtime image.
- **No secrets in the repository:** `.env` and `*.tfvars` are git-ignored, and only `.env.example` and `terraform.tfvars.example` with placeholders are committed.
- **Least-privilege CI token:** the workflow's `GITHUB_TOKEN` has read-only `contents` permission.
- **Branch protection:** The active `foundation ruleset` requires pull requests and one approving review. The live ruleset checked on November 24, 2026 has no required status checks configured. Therefore, the successful CI jobs do **not** currently block merging. Configure `ansible-check`, `dependency-scan`, `build`, and `iac-scan` as required checks in the ruleset before relying on them as merge gates.
- **Private runner isolation:** The workflow targets the `private-acr` organization runner group only for the main-branch CD publisher. An organization administrator must restrict that group to this repository and the trusted CD workflow before registering or using the runner.

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
  --skip-check CKV_AZURE_136,CKV_AZURE_166,CKV_AZURE_165,CKV_AZURE_167,CKV_AZURE_237,CKV_AZURE_233,CKV_AZURE_164,CKV2_AZURE_57 --compact
```

On Git Bash for Windows, put `MSYS_NO_PATHCONV=1` in front of the `docker run` commands.

## Reporting a Vulnerability

If you find a security issue in this project, please don't open a public issue. Contact the repository maintainers directly through GitHub and include steps to reproduce it.
