dvm_pkg git-delta
# Git config can fail in unusual bare/home-less setups; the package is still installed.
dvm_as_user git config --global core.pager delta || true
dvm_as_user git config --global interactive.diffFilter 'delta --color-only' || true
