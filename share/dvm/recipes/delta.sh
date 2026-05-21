dvm_pkg git-delta
dvm_as_user git config --global core.pager delta || true
dvm_as_user git config --global interactive.diffFilter 'delta --color-only' || true
