#!/usr/bin/env bash
set -euo pipefail

# Pinned fallback release checked 2026-05-03:
# https://github.com/sxyazi/yazi/releases/tag/v26.1.22

install_yazi_pinned() {
	sudo dnf5 install -y ca-certificates curl unzip
	case "$(dvm_recipe_arch yazi)" in
	arm64)
		dvm_recipe_install_zip_bins yazi \
			"https://github.com/sxyazi/yazi/releases/download/v26.1.22/yazi-aarch64-unknown-linux-gnu.zip" \
			"f5a9d7062ae30b75c1e0481d3132aa54c14bacf76efb1b39b54b6d5d08b7c537" \
			yazi ya
		;;
	x86_64)
		dvm_recipe_install_zip_bins yazi \
			"https://github.com/sxyazi/yazi/releases/download/v26.1.22/yazi-x86_64-unknown-linux-gnu.zip" \
			"a136269b2d5fbb5fb43f3fac3391446e8fbc72aba1c4bb4fae6e6d1556420750" \
			yazi ya
		;;
	esac
}

dvm_recipe_dnf_or_pinned yazi yazi install_yazi_pinned
