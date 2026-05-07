#!/usr/bin/env bash
# Description: Zellij terminal multiplexer
set -euo pipefail

# Pinned fallback release checked 2026-05-07:
# https://github.com/zellij-org/zellij/releases/tag/v0.44.2

install_zellij_pinned() {
	sudo dnf5 install -y ca-certificates curl tar gzip
	case "$(dvm_recipe_arch zellij)" in
	arm64)
		dvm_recipe_install_tar_bin zellij \
			"https://github.com/zellij-org/zellij/releases/download/v0.44.2/zellij-aarch64-unknown-linux-musl.tar.gz" \
			"e0b2ddbf050d58577b09b2a032a54f1a3fac0e214d1605c5969e8936340fff6b" \
			zellij
		;;
	x86_64)
		dvm_recipe_install_tar_bin zellij \
			"https://github.com/zellij-org/zellij/releases/download/v0.44.2/zellij-x86_64-unknown-linux-musl.tar.gz" \
			"26e1753b4c8451912523c7d8700c5aed75392ea57f0b1c988560f3bbc7775744" \
			zellij
		;;
	esac
}

dvm_recipe_dnf_or_pinned zellij zellij install_zellij_pinned
