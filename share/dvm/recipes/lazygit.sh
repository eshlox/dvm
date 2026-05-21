dvm_pkg curl git tar

if ! dvm_has lazygit; then
    version=0.61.1
    case "$(uname -m)" in
        x86_64)
            arch=x86_64
            sha256=1b91e660700f2332696726b635202576b543e2bc49b639830dccd26bc5160d5d
            ;;
        aarch64|arm64)
            arch=arm64
            sha256=20b1abb2bee5dfd46173b9047353eb678bc51a23839e821958d0b1863ab1655e
            ;;
        *)
            dvm_recipe_die "$DVM_RECIPE" "unsupported lazygit architecture: $(uname -m)"
            ;;
    esac

    url="https://github.com/jesseduffield/lazygit/releases/download/v${version}/lazygit_${version}_linux_${arch}.tar.gz"
    archive="$(mktemp)"
    extract_dir="$(mktemp -d)"
    dvm_download_verified lazygit "$url" "$sha256" "$archive"
    tar -xzf "$archive" -C "$extract_dir" lazygit
    sudo install -m 0755 "$extract_dir/lazygit" /usr/local/bin/lazygit
    rm -rf "$archive" "$extract_dir"
fi
