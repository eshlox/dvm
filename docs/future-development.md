# Future development

Keep DVM small. Prefer docs and examples over runtime framework code.

Possible future work:

- better setup script examples
- documented single-VM, per-project-user workflow
- optional real-Lima integration test
- release checksums and signed tags

Non-goals:

- plugin framework
- default host project mounts
- package-manager abstraction
- managing production secrets

Rule: add core behavior only when it preserves DVM's simple security story and
does not turn setup examples into runtime policy.
