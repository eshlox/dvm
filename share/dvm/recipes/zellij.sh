# Description: Zellij terminal multiplexer (pinned binary install)
# Verified 2026-05-07: https://github.com/zellij-org/zellij/releases/tag/v0.44.2
dvm_install_pinned zellij \
    "https://github.com/zellij-org/zellij/releases/download/v0.44.2/zellij-aarch64-unknown-linux-musl.tar.gz" \
    "e0b2ddbf050d58577b09b2a032a54f1a3fac0e214d1605c5969e8936340fff6b" \
    "https://github.com/zellij-org/zellij/releases/download/v0.44.2/zellij-x86_64-unknown-linux-musl.tar.gz" \
    "26e1753b4c8451912523c7d8700c5aed75392ea57f0b1c988560f3bbc7775744" \
    tar zellij
