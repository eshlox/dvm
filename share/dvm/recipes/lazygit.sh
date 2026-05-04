#!/usr/bin/env bash
set -euo pipefail

# Pinned fallback release checked 2026-05-03:
# https://github.com/jesseduffield/lazygit/releases/tag/v0.61.1

install_lazygit_pinned() {
	sudo dnf5 install -y ca-certificates curl tar gzip
	case "$(dvm_recipe_arch lazygit)" in
	arm64)
		dvm_recipe_install_tar_bin lazygit \
			"https://github.com/jesseduffield/lazygit/releases/download/v0.61.1/lazygit_0.61.1_linux_arm64.tar.gz" \
			"20b1abb2bee5dfd46173b9047353eb678bc51a23839e821958d0b1863ab1655e" \
			lazygit
		;;
	x86_64)
		dvm_recipe_install_tar_bin lazygit \
			"https://github.com/jesseduffield/lazygit/releases/download/v0.61.1/lazygit_0.61.1_linux_x86_64.tar.gz" \
			"1b91e660700f2332696726b635202576b543e2bc49b639830dccd26bc5160d5d" \
			lazygit
		;;
	esac
}

dvm_recipe_dnf_or_pinned lazygit lazygit install_lazygit_pinned
