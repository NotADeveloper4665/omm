#!/usr/bin/env bash
# ollama-manager.sh
# Cross-platform: macOS, Linux, Windows (Git Bash / WSL)
#
# Usage:
#   ollama-manager              — show running processes + list models
#   ollama-manager -rm          — interactively remove models by number
#   ollama-manager -s           — show running models, interactively stop them
#   ollama-manager -purge       — delete ALL installed models (double confirmation)
#   ollama-manager -a           — add/pull a model (accepts run cmd, pull cmd, or bare model id)
#   ollama-manager -h           — show help

# ── platform detection ────────────────────────────────────────────────────────
detect_os() {
    case "$(uname -s 2>/dev/null)" in
        Darwin)  OS="macos" ;;
        Linux)   OS="linux" ;;
        MINGW*|MSYS*|CYGWIN*) OS="windows" ;;
        *)
            # uname may not exist on native Windows outside Git Bash
            if [[ -n "$WINDIR" || -n "$windir" ]]; then
                OS="windows"
            else
                OS="unknown"
            fi
            ;;
    esac
}

# ── colours (disable on Windows cmd/powershell outside Git Bash) ──────────────
setup_colours() {
    if [[ "$OS" == "windows" && -z "$TERM" ]]; then
        # Likely running in cmd.exe or PowerShell without ANSI support
        BOLD=''; DIM=''; RESET=''; GREEN=''; CYAN=''; YELLOW=''
        RED=''; MAGENTA=''; WHITE=''; BLUE=''
    else
        BOLD='\033[1m'
        DIM='\033[2m'
        RESET='\033[0m'
        GREEN='\033[0;32m'
        CYAN='\033[0;36m'
        YELLOW='\033[1;33m'
        RED='\033[0;31m'
        MAGENTA='\033[0;35m'
        WHITE='\033[1;37m'
        BLUE='\033[0;34m'
    fi
}

# ── helpers ───────────────────────────────────────────────────────────────────
hr() {
    printf "${DIM}%s${RESET}\n" "$(printf '─%.0s' $(seq 1 60))"
}

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
    hr
}

require_ollama() {
    if ! command -v ollama &>/dev/null; then
        printf "${RED}  ✗  ollama not found in PATH. Is it installed?${RESET}\n"
        printf "${DIM}     Download it at https://ollama.com${RESET}\n\n"
        exit 1
    fi
}

# ── running processes (ollama ps) — plain display ─────────────────────────────
show_ps() {
    printf "\n${BOLD}${WHITE}  ▸ Running Processes${RESET}  ${DIM}(ollama ps)${RESET}\n"
    hr

    local ps_output
    ps_output=$(ollama ps 2>&1)

    if [[ -z "$ps_output" ]]; then
        printf "  ${DIM}No models currently loaded.${RESET}\n"
        return
    fi

    local first=true
    while IFS= read -r line; do
        if $first; then
            printf "  ${BOLD}${MAGENTA}%s${RESET}\n" "$line"
            first=false
        else
            local name rest
            name=$(echo "$line" | awk '{print $1}')
            rest=$(echo "$line" | cut -c${#name}- | cut -c2-)
            printf "  ${GREEN}%-30s${RESET}${DIM}%s${RESET}\n" "$name" " $rest"
        fi
    done <<< "$ps_output"
}

# ── running processes with numbers (for -s mode) ──────────────────────────────
declare -a RUNNING_NAMES

show_ps_numbered() {
    printf "\n${BOLD}${WHITE}  ▸ Running Models${RESET}  ${DIM}(ollama ps)${RESET}\n"
    hr

    local ps_output
    ps_output=$(ollama ps 2>&1)

    if [[ -z "$ps_output" ]]; then
        printf "  ${DIM}No models currently loaded.${RESET}\n"
        return 1
    fi

    local idx=0
    local first=true
    while IFS= read -r line; do
        if $first; then
            printf "  ${BOLD}${MAGENTA}%-4s %s${RESET}\n" "NUM" "$line"
            hr
            first=false
        else
            [[ -z "$line" ]] && continue
            idx=$((idx + 1))
            local name rest
            name=$(echo "$line" | awk '{print $1}')
            rest=$(echo "$line" | cut -c${#name}- | cut -c2-)
            RUNNING_NAMES[$idx]="$name"
            printf "  ${BOLD}${YELLOW}%-4s${RESET} ${GREEN}%-30s${RESET}${DIM}%s${RESET}\n" \
                "[$idx]" "$name" " $rest"
        fi
    done <<< "$ps_output"

    echo
    printf "  ${DIM}%d model(s) running.${RESET}\n" "$idx"
    return 0
}

# ── model list (ollama list) ───────────────────────────────────────────────────
declare -a MODEL_NAMES

show_list() {
    printf "\n${BOLD}${WHITE}  ▸ Available Models${RESET}  ${DIM}(ollama list)${RESET}\n"
    hr

    local list_output
    list_output=$(ollama list 2>&1)

    if [[ -z "$list_output" ]]; then
        printf "  ${DIM}No models installed.${RESET}\n"
        return
    fi

    local idx=0
    local first=true
    while IFS= read -r line; do
        if $first; then
            printf "  ${BOLD}${MAGENTA}%-4s %s${RESET}\n" "NUM" "$line"
            hr
            first=false
        else
            [[ -z "$line" ]] && continue
            idx=$((idx + 1))
            local name rest
            name=$(echo "$line" | awk '{print $1}')
            rest=$(echo "$line" | cut -c${#name}- | cut -c2-)
            MODEL_NAMES[$idx]="$name"
            printf "  ${BOLD}${YELLOW}%-4s${RESET} ${CYAN}%-30s${RESET}${DIM}%s${RESET}\n" \
                "[$idx]" "$name" " $rest"
        fi
    done <<< "$list_output"

    echo
    printf "  ${DIM}%d model(s) installed.${RESET}\n" "$idx"
}

# ── add / pull flow (-a) ──────────────────────────────────────────────────────
# Accepts any of:
#   ollama run  hf.co/org/model:tag   → converted to: ollama pull hf.co/org/model:tag
#   ollama pull hf.co/org/model:tag   → run as-is
#   hf.co/org/model:tag               → prefixed:     ollama pull hf.co/org/model:tag
#   llama3.2                          → prefixed:     ollama pull llama3.2
add_model() {
    printf "\n${BOLD}${WHITE}  ▸ Add Model${RESET}  ${DIM}(-a)${RESET}\n"
    hr
    printf "  ${DIM}Paste an ollama run/pull command, a Hugging Face model path, or a plain model name.${RESET}\n"
    printf "  ${DIM}Examples:${RESET}\n"
    printf "  ${DIM}  ollama run hf.co/unsloth/Qwen3-9B-GGUF:Q4_K_M${RESET}\n"
    printf "  ${DIM}  ollama pull llama3.2${RESET}\n"
    printf "  ${DIM}  hf.co/unsloth/Qwen3-9B-GGUF:Q4_K_M${RESET}\n"
    printf "  ${DIM}  llama3.2${RESET}\n"
    printf "  ${DIM}Press Enter with no input to cancel.${RESET}\n\n"
    printf "  ${BOLD}${WHITE}Input: ${RESET}"

    read -r raw_input

    # Trim leading/trailing whitespace
    local input
    input=$(echo "$raw_input" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    if [[ -z "$input" ]]; then
        printf "\n  ${DIM}Cancelled.${RESET}\n\n"
        return
    fi

    local pull_cmd=""

    # Case 1: starts with "ollama run " → swap run → pull
    if [[ "$input" =~ ^ollama[[:space:]]+run[[:space:]]+(.*) ]]; then
        local model_id="${BASH_REMATCH[1]}"
        pull_cmd="ollama pull ${model_id}"

    # Case 2: starts with "ollama pull " → use as-is
    elif [[ "$input" =~ ^ollama[[:space:]]+pull[[:space:]]+(.*) ]]; then
        pull_cmd="ollama pull ${BASH_REMATCH[1]}"

    # Case 3: starts with "ollama " but unknown subcommand
    elif [[ "$input" =~ ^ollama[[:space:]]+ ]]; then
        printf "\n  ${RED}  ✗  Unrecognised ollama subcommand. Use 'run' or 'pull', or paste just the model ID.${RESET}\n\n"
        return

    # Case 4: bare model id (no "ollama" prefix) → prefix with ollama pull
    else
        pull_cmd="ollama pull ${input}"
    fi

    # Strip any extra whitespace from the final command
    pull_cmd=$(echo "$pull_cmd" | sed 's/[[:space:]]\+/ /g;s/[[:space:]]*$//')

    echo
    printf "  ${CYAN}  ▸  Will run:${RESET} ${BOLD}%s${RESET}\n\n" "$pull_cmd"
    printf "  ${BOLD}${WHITE}Confirm? [y/N]: ${RESET}"
    read -r confirm
    echo

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        printf "  ${DIM}Cancelled — nothing pulled.${RESET}\n\n"
        return
    fi

    printf "\n  ${YELLOW}  ⟳  Pulling model...${RESET}\n\n"

    # Run the pull command, streaming output directly to terminal
    eval "$pull_cmd"
    local exit_code=$?

    echo
    if [[ $exit_code -eq 0 ]]; then
        printf "  ${GREEN}${BOLD}  ✓  Model pulled successfully.${RESET}\n\n"
    else
        printf "  ${RED}${BOLD}  ✗  Pull failed (exit code %d). Check the model name and try again.${RESET}\n\n" "$exit_code"
    fi
}

# ── stop flow (-s) ────────────────────────────────────────────────────────────
stop_models() {
    local total=${#RUNNING_NAMES[@]}

    if [[ $total -eq 0 ]]; then
        printf "\n  ${DIM}Nothing to stop — no models are running.${RESET}\n\n"
        return
    fi

    printf "\n${BOLD}${WHITE}  ▸ Stop Models${RESET}\n"
    hr
    printf "  ${DIM}Enter numbers separated by spaces (e.g. ${RESET}${YELLOW}1 3 5${RESET}${DIM}), then press Enter.${RESET}\n"
    printf "  ${DIM}Press Enter with no input to cancel.${RESET}\n\n"
    printf "  ${BOLD}${WHITE}Numbers: ${RESET}"

    read -r input

    if [[ -z "$input" ]]; then
        printf "\n  ${DIM}Cancelled — no models stopped.${RESET}\n\n"
        return
    fi

    declare -A seen
    local to_stop=()

    for token in $input; do
        if ! [[ "$token" =~ ^[0-9]+$ ]]; then
            printf "  ${RED}  ✗  '%s' is not a valid number — skipping.${RESET}\n" "$token"
            continue
        fi
        if [[ $token -lt 1 || $token -gt $total ]]; then
            printf "  ${RED}  ✗  %d is out of range (1–%d) — skipping.${RESET}\n" "$token" "$total"
            continue
        fi
        if [[ -n "${seen[$token]}" ]]; then
            continue
        fi
        seen[$token]=1
        to_stop+=("$token")
    done

    if [[ ${#to_stop[@]} -eq 0 ]]; then
        printf "\n  ${DIM}No valid selections. Nothing stopped.${RESET}\n\n"
        return
    fi

    echo
    printf "  ${BOLD}${YELLOW}  Models to stop:${RESET}\n"
    for idx in "${to_stop[@]}"; do
        printf "    ${YELLOW}⏹  %s${RESET}\n" "${RUNNING_NAMES[$idx]}"
    done
    echo

    printf "  ${BOLD}${WHITE}Confirm? [y/N]: ${RESET}"
    read -r confirm
    echo

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        printf "  ${DIM}Aborted — no models stopped.${RESET}\n\n"
        return
    fi

    for idx in "${to_stop[@]}"; do
        local model="${RUNNING_NAMES[$idx]}"
        printf "  ${YELLOW}  ⟳  Stopping ${BOLD}%s${RESET}${YELLOW}...${RESET}" "$model"
        if ollama stop "$model" &>/dev/null; then
            printf "\r  ${GREEN}  ✓  Stopped ${BOLD}%s${RESET}\n" "$model"
        else
            printf "\r  ${RED}  ✗  Failed to stop ${BOLD}%s${RESET}\n" "$model"
        fi
    done
    echo
}

# ── removal flow (-rm) ────────────────────────────────────────────────────────
remove_models() {
    local total=${#MODEL_NAMES[@]}

    if [[ $total -eq 0 ]]; then
        printf "\n  ${DIM}Nothing to remove — no models installed.${RESET}\n\n"
        return
    fi

    printf "\n${BOLD}${WHITE}  ▸ Remove Models${RESET}\n"
    hr
    printf "  ${DIM}Enter numbers separated by spaces (e.g. ${RESET}${YELLOW}1 3 5${RESET}${DIM}), then press Enter.${RESET}\n"
    printf "  ${DIM}Press Enter with no input to cancel.${RESET}\n\n"
    printf "  ${BOLD}${WHITE}Numbers: ${RESET}"

    read -r input

    if [[ -z "$input" ]]; then
        printf "\n  ${DIM}Cancelled — no models removed.${RESET}\n\n"
        return
    fi

    declare -A seen
    local to_remove=()

    for token in $input; do
        if ! [[ "$token" =~ ^[0-9]+$ ]]; then
            printf "  ${RED}  ✗  '%s' is not a valid number — skipping.${RESET}\n" "$token"
            continue
        fi
        if [[ $token -lt 1 || $token -gt $total ]]; then
            printf "  ${RED}  ✗  %d is out of range (1–%d) — skipping.${RESET}\n" "$token" "$total"
            continue
        fi
        if [[ -n "${seen[$token]}" ]]; then
            continue
        fi
        seen[$token]=1
        to_remove+=("$token")
    done

    if [[ ${#to_remove[@]} -eq 0 ]]; then
        printf "\n  ${DIM}No valid selections. Nothing removed.${RESET}\n\n"
        return
    fi

    echo
    printf "  ${BOLD}${RED}  Models to delete:${RESET}\n"
    for idx in "${to_remove[@]}"; do
        printf "    ${RED}✗  %s${RESET}\n" "${MODEL_NAMES[$idx]}"
    done
    echo

    printf "  ${BOLD}${WHITE}Confirm deletion? [y/N]: ${RESET}"
    read -r confirm
    echo

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        printf "  ${DIM}Aborted — no models removed.${RESET}\n\n"
        return
    fi

    for idx in "${to_remove[@]}"; do
        local model="${MODEL_NAMES[$idx]}"
        printf "  ${YELLOW}  ⟳  Removing ${BOLD}%s${RESET}${YELLOW}...${RESET}" "$model"
        if ollama rm "$model" &>/dev/null; then
            printf "\r  ${GREEN}  ✓  Removed ${BOLD}%s${RESET}\n" "$model"
        else
            printf "\r  ${RED}  ✗  Failed to remove ${BOLD}%s${RESET}\n" "$model"
        fi
    done
    echo
}

# ── purge flow (-purge) ───────────────────────────────────────────────────────
purge_models() {
    local list_output
    list_output=$(ollama list 2>&1)

    local idx=0
    local first=true
    while IFS= read -r line; do
        if $first; then
            first=false
            continue
        fi
        [[ -z "$line" ]] && continue
        idx=$((idx + 1))
        MODEL_NAMES[$idx]=$(echo "$line" | awk '{print $1}')
    done <<< "$list_output"

    local total=$idx

    printf "\n${BOLD}${RED}  ▸ PURGE — Delete ALL Models${RESET}\n"
    hr

    if [[ $total -eq 0 ]]; then
        printf "  ${DIM}No models installed. Nothing to purge.${RESET}\n\n"
        return
    fi

    printf "  ${RED}The following ${BOLD}%d${RESET}${RED} model(s) will be permanently deleted:${RESET}\n\n" "$total"
    for i in $(seq 1 $total); do
        printf "    ${RED}✗  %s${RESET}\n" "${MODEL_NAMES[$i]}"
    done

    echo
    printf "  ${BOLD}${RED}⚠️  Confirmation 1 of 2 — Are you sure? [y/N]: ${RESET}"
    read -r confirm1
    echo

    if [[ ! "$confirm1" =~ ^[Yy]$ ]]; then
        printf "  ${DIM}Purge aborted.${RESET}\n\n"
        return
    fi

    printf "  ${BOLD}${RED}⚠️  Confirmation 2 of 2 — Type ${RESET}${YELLOW}DELETE${RESET}${BOLD}${RED} to confirm: ${RESET}"
    read -r confirm2
    echo

    if [[ "$confirm2" != "DELETE" ]]; then
        printf "  ${DIM}Purge aborted — you did not type DELETE.${RESET}\n\n"
        return
    fi

    echo
    printf "  ${BOLD}${RED}  Purging all models...${RESET}\n\n"

    for i in $(seq 1 $total); do
        local model="${MODEL_NAMES[$i]}"
        printf "  ${YELLOW}  ⟳  Removing ${BOLD}%s${RESET}${YELLOW}...${RESET}" "$model"
        if ollama rm "$model" &>/dev/null; then
            printf "\r  ${GREEN}  ✓  Removed ${BOLD}%s${RESET}\n" "$model"
        else
            printf "\r  ${RED}  ✗  Failed to remove ${BOLD}%s${RESET}\n" "$model"
        fi
    done

    echo
    printf "  ${GREEN}${BOLD}  Purge complete.${RESET}\n\n"
}

# ── main ──────────────────────────────────────────────────────────────────────
main() {
    detect_os
    setup_colours

    local rm_mode=false
    local stop_mode=false
    local purge_mode=false
    local add_mode=false

    for arg in "$@"; do
        case "$arg" in
            -rm|--rm)       rm_mode=true ;;
            -s|--stop)      stop_mode=true ;;
            -purge|--purge) purge_mode=true ;;
            -a|--add)       add_mode=true ;;
            -h|--help)
                printf "\nUsage:\n"
                printf "  ollama-manager             List running processes and installed models\n"
                printf "  ollama-manager -a          Add (pull) a model interactively\n"
                printf "  ollama-manager -rm         Same as default, plus interactive removal\n"
                printf "  ollama-manager -s          List running models, interactively stop them\n"
                printf "  ollama-manager -purge      Delete ALL installed models (double confirmation)\n\n"
                printf "Platforms: macOS, Linux, Windows (Git Bash / WSL)\n\n"
                exit 0
                ;;
            *)
                printf "${RED}Unknown flag: %s  (run with -h for help)${RESET}\n" "$arg"
                exit 1
                ;;
        esac
    done

    require_ollama
    header

    # -a mode: add a model, then show the updated list
    if $add_mode; then
        add_model
        show_list
        exit 0
    fi

    # -s mode: only show running models + stop flow
    if $stop_mode; then
        show_ps_numbered
        stop_models
        exit 0
    fi

    # -purge mode: show full list then purge
    if $purge_mode; then
        show_list
        purge_models
        exit 0
    fi

    # default / -rm mode
    show_ps
    show_list

    if $rm_mode; then
        remove_models
    else
        echo
        printf "  ${DIM}Flags: ${RESET}${YELLOW}-a${RESET}${DIM} add  │  ${RESET}${YELLOW}-rm${RESET}${DIM} remove  │  ${RESET}${YELLOW}-s${RESET}${DIM} stop running  │  ${RESET}${YELLOW}-purge${RESET}${DIM} delete all${RESET}\n\n"
    fi
}

main "$@"
