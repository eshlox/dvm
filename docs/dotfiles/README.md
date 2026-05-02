# Dotfiles

DVM does not require a dotfiles manager. Pick one workflow and call it from global setup
or from one VM config.

No dotfiles are synced by default.

Do not publish `~/.config/dvm` as-is. It is local machine state and can contain project
names, tunnel names, email, package choices, and VM-specific setup.

Options:

- [Snapshot directory](snapshot.md): copy a filtered host directory into the VM
- [Bare repo](bare-repo.md): manage real `$HOME` paths with a bare Git repo
- [yadm](yadm.md): use yadm alternate files
- [Chezmoi](chezmoi.md): use templates and local machine data

Public dotfiles examples use HTTPS clone URLs so a fresh VM does not need GitHub SSH
credentials. For a private repo, use an SSH clone URL, call
`dvm_recipe_record_ssh_host github.com` before cloning, run `dvm ssh-key <name>`, and
add the printed public key as a deploy key before setup.

Git signing:

- Do not track VM-specific signing config in public dotfiles.
- Prefer `dvm ssh-key <name>` for VM-local SSH commit signing.
- See [SSH, GPG, and signing](../keys.md).
