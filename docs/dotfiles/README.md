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

Git signing:

- Do not track a VM-specific Git `user.signingkey` in shared dotfiles.
- See [SSH and GPG](../keys.md).
