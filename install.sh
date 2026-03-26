#!/usr/bin/env bash
# install.sh — Ollama Model Manager installer
# Supports: macOS, Linux, Windows (Git Bash / WSL)

# ── colours ───────────────────────────────────────────────────────────────────
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
WHITE='\033[1;37m'

# Disable colours on Windows cmd/PowerShell without ANSI
if [[ -z "$TERM" && ( -n "$WINDIR" || -n "$windir" ) ]]; then
    BOLD=''; DIM=''; RESET=''; GREEN=''; CYAN=''; YELLOW=''; RED=''; WHITE=''
fi

# ── helpers ───────────────────────────────────────────────────────────────────
hr() {
    printf "${DIM}%s${RESET}\n" "$(printf '─%.0s' $(seq 1 60))"
}

info()    { printf "  ${CYAN}  ▸  %s${RESET}\n" "$1"; }
success() { printf "  ${GREEN}  ✓  %s${RESET}\n" "$1"; }
warn()    { printf "  ${YELLOW}  ⚠  %s${RESET}\n" "$1"; }
error()   { printf "  ${RED}  ✗  %s${RESET}\n" "$1"; }
step()    { printf "\n${BOLD}${WHITE}  %s${RESET}\n" "$1"; hr; }

# ── banner ────────────────────────────────────────────────────────────────────
header() {
    echo
    printf "${BOLD}${CYAN}"
    cat << 'EOF'
  /$$$$$$  /$$ /$$                                         /$$      /$$                 /$$           /$$       /$$      /$$
 /$$__  $$| $$| $$                                        | $$$    /$$$                | $$          | $$      | $$$    /$$$
| $$  \ $$| $$| $$  /$$$$$$  /$$$$$$/$$$$   /$$$$$$       | $$$$  /$$$$  /$$$$$$   /$$$$$$$  /$$$$$$ | $$      | $$$$  /$$$$  /$$$$$$  /$$$$$$$   /$$$$$$   /$$$$$$   /$$$$$$   /$$$$$$
| $$  | $$| $$| $$ |____  $$| $$_  $$_  $$ |____  $$      | $$ $$/$$ $$ /$$__  $$ /$$__  $$ /$$__  $$| $$      | $$ $$/$$ $$ |____  $$| $$__  $$ |____  $$ /$$__  $$ /$$__  $$ /$$__  $$
| $$  | $$| $$| $$  /$$$$$$$| $$ \ $$ \ $$  /$$$$$$$      | $$  $$$| $$| $$  \ $$| $$  | $$| $$$$$$$$| $$      | $$  $$$| $$  /$$$$$$$| $$  \ $$  /$$$$$$$| $$  \ $$| $$$$$$$$| $$  \__/
| $$  | $$| $$| $$ /$$__  $$| $$ | $$ | $$ /$$__  $$      | $$\  $ | $$| $$  | $$| $$  | $$| $$_____/| $$      | $$\  $ | $$ /$$__  $$| $$  | $$ /$$__  $$| $$  | $$| $$_____/| $$
|  $$$$$$/| $$| $$|  $$$$$$$| $$ | $$ | $$|  $$$$$$$      | $$ \/  | $$|  $$$$$$/|  $$$$$$$|  $$$$$$$| $$      | $$ \/  | $$|  $$$$$$$| $$  | $$|  $$$$$$$|  $$$$$$$|  $$$$$$$| $$
 \______/ |__/|__/ \_______/|__/ |__/ |__/ \_______/      |__/     |__/ \______/  \_______/ \_______/|__/      |__/     |__/ \_______/|__/  |__/ \_______/ \____  $$ \_______/|__/
                                                                                                                                                            /$$  \ $$
                                                                                                                                                           |  $$$$$$/
                                                                                                                                                            \______/
EOF
    printf "${RESET}"
    printf "${DIM}%s${RESET}\n" "$(printf '─%.0s' $(seq 1 60))"
    printf "\n  ${BOLD}${WHITE}Installer${RESET}  ${DIM}v1.0${RESET}\n\n"
}

# ── detect OS ─────────────────────────────────────────────────────────────────
detect_os() {
    case "$(uname -s 2>/dev/null)" in
        Darwin)              OS="macos" ;;
        Linux)               OS="linux" ;;
        MINGW*|MSYS*|CYGWIN*) OS="windows_bash" ;;
        *)
            if [[ -n "$WINDIR" || -n "$windir" ]]; then
                OS="windows_bash"
            else
                OS="unknown"
            fi
            ;;
    esac
}

# ── find the script ───────────────────────────────────────────────────────────
find_script() {
    # Always look relative to install.sh's own directory first
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    SCRIPT_SRC="$SCRIPT_DIR/ollama-manager.sh"

    if [[ ! -f "$SCRIPT_SRC" ]]; then
        error "Cannot find ollama-manager.sh next to this installer."
        error "Make sure both files are in the same folder."
        exit 1
    fi
}

# ── install on macOS / Linux ──────────────────────────────────────────────────
install_unix() {
    local dest="/usr/local/bin/ollama-manager"

    # Try /usr/local/bin first; fall back to ~/.local/bin (no sudo needed)
    if [[ ! -w "/usr/local/bin" ]]; then
        if sudo -n true 2>/dev/null; then
            : # sudo available without password, proceed
        else
            warn "/usr/local/bin requires sudo. You may be prompted for your password."
        fi
    fi

    info "Installing to ${dest}"

    if cp "$SCRIPT_SRC" "$dest" 2>/dev/null || sudo cp "$SCRIPT_SRC" "$dest"; then
        sudo chmod +x "$dest" 2>/dev/null || chmod +x "$dest"
        success "Installed to ${dest}"
    else
        # Fallback: install to ~/.local/bin (no sudo required)
        warn "Could not write to /usr/local/bin. Falling back to ~/.local/bin"
        mkdir -p "$HOME/.local/bin"
        dest="$HOME/.local/bin/ollama-manager"
        cp "$SCRIPT_SRC" "$dest"
        chmod +x "$dest"
        success "Installed to ${dest}"

        # Check if ~/.local/bin is in PATH
        if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
            warn "~/.local/bin is not in your PATH."
            add_to_path_unix
        fi
    fi

    INSTALL_DEST="$dest"
}

add_to_path_unix() {
    local shell_rc=""

    if [[ "$OS" == "macos" ]]; then
        # macOS default shell is zsh since Catalina
        if [[ "$SHELL" == *"zsh"* ]]; then
            shell_rc="$HOME/.zshrc"
        else
            shell_rc="$HOME/.bash_profile"
        fi
    else
        shell_rc="$HOME/.bashrc"
    fi

    local path_line='export PATH="$HOME/.local/bin:$PATH"'

    if ! grep -qF "$path_line" "$shell_rc" 2>/dev/null; then
        echo "" >> "$shell_rc"
        echo "# Added by ollama-manager installer" >> "$shell_rc"
        echo "$path_line" >> "$shell_rc"
        success "Added ~/.local/bin to PATH in ${shell_rc}"
        warn "Run: source ${shell_rc}   (or open a new terminal) to apply."
    else
        info "PATH already contains ~/.local/bin — no changes made."
    fi
}

# ── install on Windows (Git Bash / MSYS) ─────────────────────────────────────
install_windows() {
    # Git Bash ships with /usr/local/bin on the PATH by default
    local dest="/usr/local/bin/ollama-manager"

    info "Detected Windows (Git Bash / MSYS)"
    info "Installing to ${dest}"

    if cp "$SCRIPT_SRC" "$dest" 2>/dev/null; then
        chmod +x "$dest"
        success "Installed to ${dest}"
    else
        # Fallback: user's home bin
        warn "Could not write to /usr/local/bin. Falling back to ~/bin"
        mkdir -p "$HOME/bin"
        dest="$HOME/bin/ollama-manager"
        cp "$SCRIPT_SRC" "$dest"
        chmod +x "$dest"
        success "Installed to ${dest}"

        if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
            warn "~/bin is not in your PATH."
            local path_line='export PATH="$HOME/bin:$PATH"'
            echo "" >> "$HOME/.bashrc"
            echo "# Added by ollama-manager installer" >> "$HOME/.bashrc"
            echo "$path_line" >> "$HOME/.bashrc"
            success "Added ~/bin to PATH in ~/.bashrc"
            warn "Restart Git Bash or run: source ~/.bashrc"
        fi
    fi

    INSTALL_DEST="$dest"
}

# ── verify install ────────────────────────────────────────────────────────────
verify() {
    step "Verifying installation"

    if command -v ollama-manager &>/dev/null; then
        success "ollama-manager is available in your PATH"
        info    "Installed at: $(command -v ollama-manager)"
    else
        warn "ollama-manager was copied but is not yet in your PATH."
        info "Installed at: ${INSTALL_DEST}"
        info "Either open a new terminal or run the full path:"
        printf "\n    ${BOLD}${YELLOW}%s${RESET}\n\n" "$INSTALL_DEST"
    fi
}

# ── check for ollama ──────────────────────────────────────────────────────────
check_ollama() {
    step "Checking for Ollama"

    if command -v ollama &>/dev/null; then
        success "Ollama found: $(command -v ollama)"
    else
        warn "Ollama is not installed or not in PATH."
        info "Download it at: https://ollama.com"
        info "ollama-manager will not work without it."
    fi
}

# ── already installed? ────────────────────────────────────────────────────────
check_existing() {
    if command -v ollama-manager &>/dev/null; then
        local existing
        existing=$(command -v ollama-manager)
        warn "ollama-manager is already installed at: ${existing}"
        printf "  ${BOLD}${WHITE}  Overwrite? [y/N]: ${RESET}"
        read -r overwrite
        echo
        if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
            info "Installation cancelled."
            exit 0
        fi
    fi
}

# ── main ──────────────────────────────────────────────────────────────────────
main() {
    header
    detect_os
    find_script
    check_existing

    step "Installing ollama-manager"

    case "$OS" in
        macos|linux)    install_unix ;;
        windows_bash)   install_windows ;;
        *)
            error "Unsupported platform: $(uname -s 2>/dev/null)"
            error "Please manually copy ollama-manager.sh to a directory in your PATH."
            exit 1
            ;;
    esac

    check_ollama
    verify

    printf "\n${BOLD}${GREEN}  All done!${RESET}  Run ${BOLD}${YELLOW}ollama-manager${RESET} to get started.\n\n"
}

main "$@"
