# Future Development

DVM's strongest property is the default boundary: one project per VM, no host
mount, no host secrets, and code living inside the guest. Future work should
strengthen that boundary without turning DVM into a large framework.

## Safety Roadmap

1. Network policy per VM or recipe.

   Let a VM declare allowed outbound destinations for package mirrors, Git
   hosting, AI APIs, Tailscale, Cloudflare, or project-specific services.
   Unknown outbound traffic should be easy to block or inspect.

2. Secret broker instead of guest secret files.

   Keep long-lived secrets on the host and expose only short-lived, scoped
   credentials or proxied operations to the VM. The current `DVM_SECRETS`
   staging is simple and auditable, but a broker would reduce secret lifetime
   inside compromised guests.

3. Ephemeral agent mode.

   Add a workflow like `dvm agent <vm> <tool>` that creates a throwaway clone,
   runs Codex/Claude/opencode there, records changes, then lets the user
   review/apply the result to the main VM. This would make untrusted agent work
   easier to discard.

4. Session logs.

   Record generated guest scripts, agent commands, changed files, and useful
   service/network events per sync or agent run. Logs should help answer "what
   changed?" without creating a surveillance-heavy tool.

5. Trust tiers.

   Document and optionally automate separate VM roles:

   - `dev`: normal long-lived project VM
   - `agent`: disposable or easy-to-reset AI/package execution VM
   - `service`: VM that owns exposed tunnels or long-running services

6. Optional stricter service exposure.

   Keep Tailscale and Cloudflare Tunnel as the preferred sharing paths, but
   document direct Lima networking for users who intentionally need VM IP or
   LAN exposure.

## Non-Goals

- Supporting arbitrary guest distros. Built-ins target Lima's latest Fedora
  template with `dnf5`.
- Reintroducing host project mounts as a default.
- Building a large plugin framework or package manager.
- Managing users' long-lived production secrets directly.

## Evaluation Rule

New safety features should pass this test:

> Does this reduce host exposure or make risky behavior easier to see, without
> adding enough code that DVM stops being audit-friendly?

If the answer is no, prefer documentation or a user recipe over core behavior.
