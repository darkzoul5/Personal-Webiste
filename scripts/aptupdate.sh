#!/usr/bin/env bash
set -Eeuo pipefail

VERBOSE=false

if [[ "${1:-}" == "-v" ]]; then
    VERBOSE=true
fi

echo "Requesting sudo access..."
sudo -v

export DEBIAN_FRONTEND=noninteractive

run_with_indicator() {
    local track_packages=false

    if [[ "${1:-}" == "--packages" ]]; then
        track_packages=true
        shift
    fi

    if $VERBOSE; then
        "$@"
        return
    fi

    local logfile
    local statusfile

    logfile=$(mktemp)
    statusfile=$(mktemp)

    if $track_packages; then
        "$@" -o Dpkg::Status-Fd=3 3>"$statusfile" >"$logfile" 2>&1 &
    else
        "$@" >"$logfile" 2>&1 &
    fi

    local pid=$!

    local symbols=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local i=0
    local package="Working..."
    local start_time=$SECONDS

    while kill -0 "$pid" 2>/dev/null; do
        local elapsed=$((SECONDS - start_time))

        if $track_packages; then
            local current
            current=$(
                grep '^processing:' "$statusfile" 2>/dev/null |
                tail -n 1 |
                sed -E 's/^processing: ([^:]+):.*/\1/' ||
                true
            )

            if [[ -n "$current" ]]; then
                package="$current"
            fi

            printf "\r%s %-45s [%ds]" \
                "${symbols[$i]}" \
                "$package" \
                "$elapsed"
        else
            printf "\r%s Working... [%ds]" \
                "${symbols[$i]}" \
                "$elapsed"
        fi

        i=$(( (i + 1) % ${#symbols[@]} ))
        sleep 0.1
    done

    local elapsed=$((SECONDS - start_time))

    if wait "$pid"; then
        printf "\033[2K\r✓ Done.                              [%ds]\n" "$elapsed"
    else
        printf "\033[2K\r✗ Failed.                            [%ds]\n" "$elapsed"
        echo
        cat "$logfile"
        rm -f "$logfile" "$statusfile"
        return 1
    fi

    rm -f "$logfile" "$statusfile"
}

echo
echo "[1/4] Updating package lists..."
run_with_indicator sudo apt-get update

echo "[2/4] Upgrading installed packages..."
run_with_indicator --packages sudo apt-get upgrade -y

echo "[3/4] Removing unused packages..."
run_with_indicator sudo apt-get autoremove -y

echo "[4/4] Cleaning package cache..."
run_with_indicator sudo apt-get autoclean

echo
echo "✓ System packages updated successfully."

if [[ -f /var/run/reboot-required ]]; then
    echo "⚠ A system reboot is required."
fi