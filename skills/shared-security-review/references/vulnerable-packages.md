<!-- last-verified: 2026-07-26 -->
# Dependency Advisory Sources and High-Risk Signals

Load this during Step 2 (Dependency Audit).

**Do not decide that a dependency is safe from a version floor in this file.**
New advisories invalidate static “safe version” tables. Resolve the installed
version from the lock file, then query a live advisory source.

## Required live checks

**REQUIRED SUB-SKILL:** Use `dependency-security-scan` for the project ecosystem.
Prefer the repository's existing audit command; otherwise use the matching
official or maintained scanner.

| Ecosystem | Lock files | Live check |
|-----------|------------|------------|
| npm / Node.js | `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock` | `npm audit`, `pnpm audit`, or the package manager's current audit command |
| Python | `requirements.txt`, `pyproject.toml`, lock file | `pip-audit` or OSV-Scanner |
| Java | `pom.xml`, `build.gradle`, lock/dependency report | OSV-Scanner or OWASP Dependency-Check |
| Ruby | `Gemfile.lock` | `bundle audit check --update` |
| Rust | `Cargo.lock` | `cargo audit` / RustSec |
| Go | `go.sum` | `govulncheck ./...` |

If a scanner is unavailable, query the
[GitHub Advisory Database](https://github.com/advisories),
[OSV](https://osv.dev/), and the package maintainer's security advisories.
Record the advisory ID, affected range, installed version, and fixed version
used for the finding.

## Packages requiring special handling

These are review signals, not a complete vulnerability list:

- `vm2` — deprecated after repeated sandbox escapes. Treat every use as high
  risk and verify whether process or container isolation can replace it.
- Legacy `node-fetch` — on supported Node.js releases, prefer the native Fetch
  API unless the project has a documented compatibility requirement.
- Parsers, archive tools, template engines, serializers, auth libraries, and
  cryptography packages — always check live advisories even when recently
  updated because input-handling flaws recur across releases.
- Native addons downloaded through install scripts — verify publisher,
  checksums/provenance, supported platforms, and install-time network access.

## Supply-chain red flags

Flag a dependency for manual review when it:

1. Is deprecated or archived by its maintainer.
2. Has been transferred to a new owner or suddenly changed publisher.
3. Is a fork or near-spelling of a popular package.
4. Has install scripts, bundled binaries, or unexplained native addons.
5. Has very low usage but is required in a production trust boundary.
6. Is pinned outside the scanner's supported ecosystem or excluded from its
   result.

Do not turn age, download count, or ownership change into a vulnerability by
itself. Use those signals to deepen provenance and code review.

## Authoritative ecosystem sources

- Rust: [RustSec Advisory Database](https://rustsec.org/advisories/)
- Go: [Go Vulnerability Database](https://vuln.go.dev/) and
  [pkg.go.dev/vuln](https://pkg.go.dev/vuln/)
- Python: [PyPA pip-audit](https://github.com/pypa/pip-audit)
- Cross-ecosystem: [OSV-Scanner](https://google.github.io/osv-scanner/)
