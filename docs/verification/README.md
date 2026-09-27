# Verification evidence

- [Verification report](../VERIFICATION.md): results and their limits.
- [security.json](security.json): established and unproved security properties.
- [results.json](results.json): portable summary of the local pre-publication runs.
- [GitHub Actions](https://github.com/moritayasuaki/psiv/actions/workflows/ci.yml): checks and retained report artifacts for subsequent commits.

A CI pass covers the specified builds, tests and Lean declarations. It is not a proof of Rust-to-Lean equivalence, compiled constant-time behavior or production security.

Original `v0.5.0/` and `layout/` logs, the host-specific summary, and archive checksum manifests are kept locally and ignored by Git. Their recorded paths refer to their original build environment. The [historical archive index](../../releases/README.md) identifies the preserved full release. Local snapshot manifests describe their associated source archives, not later Git commits.

Fresh runs write reports under `build/reports/`; CI uploads them as workflow artifacts. `scripts/archive.py` can create a separate source snapshot and checksum manifest. Source changes are tracked by Git and reviewed against the commit being checked.
