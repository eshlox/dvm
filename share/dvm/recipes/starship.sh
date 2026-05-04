#!/usr/bin/env bash
set -euo pipefail

# Pinned fallback release checked 2026-05-03:
# https://github.com/starship/starship/releases/tag/v1.25.1

install_starship_pinned() {
	sudo dnf5 install -y ca-certificates curl tar gzip
	case "$(dvm_recipe_arch starship)" in
	arm64)
		dvm_recipe_install_tar_bin starship \
			"https://github.com/starship/starship/releases/download/v1.25.1/starship-aarch64-unknown-linux-musl.tar.gz" \
			"01517aab398959ea9ea73bdb4f032ea4dbb51dff5c8e5eb05b4a1b9b7ab872b8" \
			starship
		;;
	x86_64)
		dvm_recipe_install_tar_bin starship \
			"https://github.com/starship/starship/releases/download/v1.25.1/starship-x86_64-unknown-linux-gnu.tar.gz" \
			"4488c11ca632327d1f1f16fb2f102c0646094c35479cd5435991385da43c61ac" \
			starship
		;;
	esac
}

dvm_recipe_dnf_or_pinned starship starship install_starship_pinned
