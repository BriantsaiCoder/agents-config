# Tool Matrix

Pick **one secret scan + one dep scan per language + one container scan + one SBOM tool**. Two overlapping tools doubles noise and triage cost.

| Layer | Recommended | Alternative | Where it runs |
|---|---|---|---|
| Secret scan | gitleaks | trufflehog | pre-commit + CI (full history) |
| Dependency (Node) | `npm audit` + Snyk | Socket.dev / OSV-Scanner | CI on every PR |
| Dependency (.NET) | `dotnet list package --vulnerable --include-transitive` | Snyk / OSV-Scanner | CI on every PR |
| Dependency (Python) | `pip-audit` | Snyk / Safety | CI on every PR |
| Dependency (Go) | `govulncheck` | Snyk | CI on every PR |
| Container image | Trivy (fast, multi-source) | Grype | CI after image build |
| SBOM | Syft (SPDX / CycloneDX) | Trivy SBOM mode | CI release artifact |

## CLI Reference

- Secret scan full history: `gitleaks git --log-opts="--all" .` — the scan target is a positional argument; there is no `--source` flag. `detect` / `protect` were deprecated in v8.19.0 and hidden from `--help` (still functional, so older pipelines keep working — migrate them). Files not yet tracked by git: `gitleaks dir .`
- Container scan blocking on critical/high: `trivy image --severity CRITICAL,HIGH --exit-code 1 <image>`
- SBOM generation (CycloneDX JSON): `syft <image> -o cyclonedx-json > sbom.json`
- .NET transitive vuln check: requires `--include-transitive` flag (default omits transitives)

Consult each tool's `--help` for full flag set; this matrix only lists the gate-defining defaults.
