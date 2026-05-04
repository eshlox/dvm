# shellcheck shell=bash

render_ports() {
	local item host_ip host_port guest_port
	for item in ${DVM_PORTS:-}; do
		IFS=: read -r host_ip host_port guest_port <<EOF
$(normalize_port "$item")
EOF
		printf '  - guestPort: %s\n' "$guest_port"
		printf '    hostPort: %s\n' "$host_port"
		printf '    hostIP: "%s"\n' "$host_ip"
		printf '    static: true\n'
	done
}

validate_host_ip() {
	case "$1" in
	'' | *[!A-Za-z0-9._-]*) die "invalid host IP: $1" ;;
	esac
}

validate_port_number() {
	local label="$1"
	local port="$2"
	case "$port" in
	'' | *[!0-9]*) die "invalid $label port: $port" ;;
	esac
	if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
		die "invalid $label port: $port"
	fi
}

normalize_port() {
	local item="$1"
	local host_ip host_port guest_port
	IFS=: read -r host_ip host_port guest_port <<EOF
$item
EOF
	if [ -z "${guest_port:-}" ]; then
		guest_port="$host_port"
		host_port="$host_ip"
		host_ip="$DVM_HOST_IP"
	fi
	[ -n "$host_ip" ] || die "invalid port forward: $item"
	validate_host_ip "$host_ip"
	validate_port_number host "$host_port"
	validate_port_number guest "$guest_port"
	printf '%s:%s:%s\n' "$host_ip" "$host_port" "$guest_port"
}

json_string() {
	local value="$1"
	value="${value//\\/\\\\}"
	value="${value//\"/\\\"}"
	printf '"%s"' "$value"
}

port_set_expr() {
	local expr item host_ip host_port guest_port
	expr='.portForwards = [{"guestPort":5355,"proto":"any","ignore":true}'
	for item in ${DVM_PORTS:-}; do
		IFS=: read -r host_ip host_port guest_port <<EOF
$(normalize_port "$item")
EOF
		expr="$expr,{\"guestPort\":$guest_port,\"hostPort\":$host_port,\"hostIP\":$(json_string "$host_ip"),\"static\":true}"
	done
	printf '%s]\n' "$expr"
}

configured_ports_canonical() {
	local item
	{
		printf 'ignore:5355:5355\n'
		for item in ${DVM_PORTS:-}; do
			normalize_port "$item"
		done
	} | sort
}

ports_canonical_from_yaml() {
	local file="$1"
	[ -f "$file" ] || return 0
	awk '
		function reset() { host = ""; host_ip = ""; guest = ""; ignore = "" }
		function value(line, key, tmp) {
			tmp = line
			gsub(/"/, "", tmp)
			sub("^.*" key ":[[:space:]]*", "", tmp)
			sub("[[:space:]]*#.*$", "", tmp)
			sub("[[:space:]].*$", "", tmp)
			return tmp
		}
		function emit() {
			if (guest == "") return
			if (ignore == "true") {
				print "ignore:" guest ":" guest
			} else if (host != "") {
				if (host_ip == "") host_ip = "127.0.0.1"
				print host_ip ":" host ":" guest
			}
		}
		BEGIN { reset() }
		/^[[:space:]]*portForwards:/ { in_ports = 1; next }
		in_ports && /^[^[:space:]-]/ { emit(); reset(); in_ports = 0 }
		!in_ports { next }
		/^[[:space:]]*-/ { emit(); reset() }
		/hostPort:[[:space:]]*/ { host = value($0, "hostPort") }
		/hostIP:[[:space:]]*/ { host_ip = value($0, "hostIP") }
		/guestPort:[[:space:]]*/ { guest = value($0, "guestPort") }
		/ignore:[[:space:]]*true/ { ignore = "true" }
		END { if (in_ports) emit() }
	' "$file" | sort
}
