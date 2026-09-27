# Security policy

PSIV is experimental research software. It is not production-qualified. The Lean specification has checked theorems, but the Rust runtime is not formally proved equivalent to Lean, and compiled constant-time behavior is not established. See [the security case](docs/SECURITY_CASE.md) and [verification report](docs/VERIFICATION.md).

For suspected vulnerabilities, use the repository's **Security → Report a vulnerability** option when available. If private reporting is unavailable, contact the repository owner through their public GitHub profile to arrange a private channel before sharing exploit details. Do not include real secret keys, private plaintext or credentials in a public issue.

Include the affected commit, platform/compiler, a minimal example using synthetic data, and the suspected impact. Reports may concern correctness, authentication failure behavior, memory safety, timing leakage or proof assumptions. The experimental `main` branch is the development target; no response-time or backport guarantee is offered.
