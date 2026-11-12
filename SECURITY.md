# Security

This document describes the security scanning built into the Inventory Manager CI pipeline, what the scans found, how each finding was handled, and the risks the team has accepted.

## Security Scans in CI

All scans run in [.github/workflows/ci.yml](.github/workflows/ci.yml) on every push to a non-main branch and on every pull request targeting `main`. Any scan that fails also fails the pipeline, and branch protection then blocks the merge.

| # | Scan type | Tool | CI job / step | Failure threshold |
|---|-----------|------|---------------|-------------------|
| 1 | Dependency scanning | `npm audit` | `build` → *Dependency scan (npm audit)* | Fails on any **HIGH** or **CRITICAL** advisory |
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

The application has no runtime npm dependencies. Its only dev dependency is `standard` (the linter).

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

**Initial result:** Terraform had 13 passed checks and 2 failed. GitHub Actions had 31 passed and 1 failed. The Dockerfile had 53 passed and 0 failed.

| Check | Resource | Result |
|-------|----------|--------|
| **CKV2_GHA_1**: top-level workflow permissions not restricted | `.github/workflows/ci.yml` | **FIXED**: added `permissions: contents: read` so the `GITHUB_TOKEN` is read-only |
| **CKV_AZURE_50**: VM extensions should not be installed | `azurerm_linux_virtual_machine.inventory` | **ACCEPTED** (see below) |
| **CKV_AZURE_119**: network interface should not use a public IP | `azurerm_network_interface.inventory` | **ACCEPTED** (see below) |

**After remediation:** Terraform passes 13/13, the Dockerfile passes 53/53 and GitHub Actions passes 60/60. The 2 accepted checks are skipped explicitly in CI with `--skip-check`.

## Accepted Risks

| ID | Risk | Why it is accepted | Mitigations / follow-up |
|----|------|--------------------|-------------------------|
| Trivy OS CVEs (Finding 2b) | 34 HIGH and 1 CRITICAL vulnerability in Debian base packages | Debian has **no fixed version** for any of them (`will_not_fix`, `fix_deferred` or `affected`), so rebuilding can't remove them. Most are in tools the app never calls (`mount`, `perl`, `gzip`, `ncurses`), and several (util-linux mount TOCTOU, systemd-homed) need local privileged access, which the container doesn't give: it runs as non-root `node`. The zlib CVE-2023-45853 is in `minizip`, which neither Node nor the app uses. | The CI gate fails as soon as Debian publishes a fix, because those findings then count as "fixable". The full report is uploaded on every run. Future option: move to a distroless or Alpine runtime image to remove most OS packages. |
| CKV_AZURE_119 | The VM's network interface has a public IP | This is a single-VM student deployment with no load balancer or bastion. The public IP is the only way for Ansible to reach the VM over SSH and for users to reach the app on port 3000. | The NSG allows SSH (22) **only from `allowed_ssh_cidr`** (one `/32` admin IP). Password login is disabled (`disable_password_authentication = true`) and only key-based SSH works. Ansible applies extra SSH hardening and a host firewall. Production would use Azure Bastion and a load balancer or Application Gateway in front of a VM with no public IP. |
| CKV_AZURE_50 | VM extension operations are left enabled (Azure default) | The VM was already provisioned with this setting. Changing it now would change live infrastructure that another team member owns. Extensions can be installed only by someone with Azure RBAC rights on the resource group. | Access to the Azure subscription is limited to the team. Follow-up: set `allow_extension_operations = false` on the VM in a future Terraform change. |
| App port 3000 open to `*` | The NSG rule `allow-application` accepts traffic from any source | The app is meant to be publicly reachable. Checkov has no rule for this, but it is recorded here for completeness. | The container runs as non-root, has a health check, and the app validates its input. Follow-up: put a reverse proxy with TLS (HTTPS on 443) in front of the app and close port 3000 to the internet. |

## Other Security Practices

- **Non-root container:** the runtime image runs as the `node` user.
- **Multi-stage build:** build tooling stays in the `builder` stage, and only the app files and production `node_modules` are copied into the runtime image.
- **No secrets in the repository:** `.env` and `*.tfvars` are git-ignored, and only `.env.example` and `terraform.tfvars.example` with placeholders are committed.
- **Least-privilege CI token:** the workflow's `GITHUB_TOKEN` has read-only `contents` permission.
- **Branch protection:** `main` requires a pull request with passing CI checks before merging.

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
  --skip-check CKV_AZURE_50,CKV_AZURE_119 --compact
```

On Git Bash for Windows, put `MSYS_NO_PATHCONV=1` in front of the `docker run` commands.

## Reporting a Vulnerability

If you find a security issue in this project, please don't open a public issue. Contact the repository maintainers directly through GitHub and include steps to reproduce it.
