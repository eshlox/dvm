#!/usr/bin/env bash
set -euo pipefail

: "${DVM_AI_AGENT_USER:=dvm-agent}"
command -v dvm_agent_write_wrapper >/dev/null 2>&1 || {
	printf 'dvm: recipe codex requires use agent-user before use codex\n' >&2
	exit 1
}
case "${DVM_CODEX_YOLO:-1}" in
1 | true | yes) dvm_codex_yolo=1 ;;
0 | false | no) dvm_codex_yolo=0 ;;
*)
	printf 'dvm: recipe codex: DVM_CODEX_YOLO must be 1 or 0\n' >&2
	exit 1
	;;
esac

sudo dnf5 install -y nodejs npm
sudo -H -u "$DVM_AI_AGENT_USER" bash -lc 'npm config set prefix "$HOME/.local" && npm install -g @openai/codex@latest'

sudo tee /usr/local/libexec/dvm-codex >/dev/null <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [ "$dvm_codex_yolo" = "1" ]; then
	exec /home/$DVM_AI_AGENT_USER/.local/bin/codex --dangerously-bypass-approvals-and-sandbox "\$@"
fi
exec /home/$DVM_AI_AGENT_USER/.local/bin/codex "\$@"
EOF
sudo chmod 0755 /usr/local/libexec/dvm-codex
dvm_agent_write_wrapper codex /usr/local/libexec/dvm-codex
