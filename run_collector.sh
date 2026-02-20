#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COLLECTOR_EXE="$SCRIPT_DIR/target/release/collector"
BASE_DATA_DIR="$SCRIPT_DIR/data/raw"
LOG_DIR="$SCRIPT_DIR/data/logs"
COINS=("btc" "eth" "sol")

MAPPINGS=(
    "binancespot:binance/spot"
    "binancefutures:binance/futures/um"
    "bybit:bybit"
    "hyperliquid:hyperliquid"
)

PID_FILE="$SCRIPT_DIR/data/collector.pids"

# --- Duration setting ---
# Usage: ./run_collector.sh 48h  or  ./run_collector.sh 90m  or  ./run_collector.sh 3600
# Default: 24h
DURATION_ARG="${1:-24h}"

parse_duration() {
    local arg="$1"
    if [[ "$arg" =~ ^([0-9]+)h$ ]]; then
        echo $(( ${BASH_REMATCH[1]} * 3600 ))
    elif [[ "$arg" =~ ^([0-9]+)m$ ]]; then
        echo $(( ${BASH_REMATCH[1]} * 60 ))
    elif [[ "$arg" =~ ^([0-9]+)s$ ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ "$arg" =~ ^[0-9]+$ ]]; then
        echo "$arg"
    else
        echo "Invalid duration: $arg. Use format like 48h, 90m, 3600s" >&2
        exit 1
    fi
}

DURATION_SECS=$(parse_duration "$DURATION_ARG")

# --- Cleanup function ---
cleanup() {
    echo ""
    echo "Stopping all collectors..."
    if [ -f "$PID_FILE" ]; then
        while read -r pid; do
            kill "$pid" 2>/dev/null
        done < "$PID_FILE"
        rm -f "$PID_FILE"
    fi
    echo "Done."
    exit 0
}
trap cleanup SIGINT SIGTERM

# --- Kill any previously running collectors ---
if [ -f "$PID_FILE" ]; then
    echo "Stopping previous collectors..."
    while read -r pid; do
        kill "$pid" 2>/dev/null
    done < "$PID_FILE"
    rm -f "$PID_FILE"
fi

mkdir -p "$LOG_DIR"

# --- Start collectors ---
for MAP in "${MAPPINGS[@]}"; do
    EXCH="${MAP%%:*}"
    SUBPATH="${MAP#*:}"
    TARGET_DIR="$BASE_DATA_DIR/$SUBPATH"

    mkdir -p "$TARGET_DIR"

    SYMBOLS_LIST=""
    for COIN in "${COINS[@]}"; do
        if [ "$EXCH" == "hyperliquid" ]; then
            S=$(echo "$COIN" | tr '[:lower:]' '[:upper:]')
        else
            S="${COIN}usdt"
        fi
        SYMBOLS_LIST+="$S "
    done

    CMD="$COLLECTOR_EXE $TARGET_DIR $EXCH $SYMBOLS_LIST"
    LOG_FILE="$LOG_DIR/$EXCH.log"

    echo "Starting $EXCH -> $TARGET_DIR"
    $CMD >> "$LOG_FILE" 2>&1 &
    echo $! >> "$PID_FILE"
done

END_TIME=$(( $(date +%s) + DURATION_SECS ))
echo ""
echo "All collectors started. Running for $DURATION_ARG"
echo "Stop time: $(date -r $END_TIME '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -d @$END_TIME '+%Y-%m-%d %H:%M:%S')"
echo "Press Ctrl+C to stop early."
echo ""

# --- Countdown ---
while true; do
    NOW=$(date +%s)
    REMAINING=$(( END_TIME - NOW ))

    if [ $REMAINING -le 0 ]; then
        break
    fi

    H=$(( REMAINING / 3600 ))
    M=$(( (REMAINING % 3600) / 60 ))
    S=$(( REMAINING % 60 ))

    printf "\rTime remaining: %02d:%02d:%02d " "$H" "$M" "$S"
    sleep 1
done

echo ""
echo "Duration reached. Stopping collectors..."
cleanup
