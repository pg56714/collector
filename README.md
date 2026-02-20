# collector

High-performance market data collector written in Rust. Subscribes to WebSocket feeds from multiple exchanges and writes raw tick data to gzip-compressed files, rotated daily.

## Supported Exchanges

| Exchange | Argument | Data streams |
|----------|----------|-------------|
| Binance Spot | `binancespot` | trade, bookTicker, depth (100ms) |
| Binance Futures (UM) | `binancefutures` | trade, bookTicker, depth (0ms) |
| Binance Futures (CM) | `binancefuturescm` | trade, bookTicker, depth (0ms) |
| Bybit | `bybit` | orderbook (1/50/200), publicTrade |
| Hyperliquid | `hyperliquid` | trades, l2Book, bbo |

## Build

```bash
cargo build --release
```

## Usage

```bash
./target/release/collector <output_dir> <exchange> <symbol> [<symbol> ...]
```

**Examples:**

```bash
# Binance Spot — BTC, ETH, SOL
./target/release/collector data/raw/binance/spot binancespot btcusdt ethusdt solusdt

# Binance Futures (UM)
./target/release/collector data/raw/binance/futures/um binancefutures btcusdt ethusdt solusdt

# Bybit
./target/release/collector data/raw/bybit bybit btcusdt ethusdt solusdt

# Hyperliquid (symbols are uppercase)
./target/release/collector data/raw/hyperliquid hyperliquid BTC ETH SOL
```

Press `Ctrl+C` to stop gracefully.

## Run All Exchanges

Use the provided script to start all exchanges in parallel:

```bash
# Default: run for 24 hours
./run_collector.sh

# Specify duration
./run_collector.sh 48h     # 48 hours
./run_collector.sh 90m     # 90 minutes
./run_collector.sh 3600s   # 3600 seconds
```

The script shows a live countdown and stops all collectors automatically when the duration is reached. Press `Ctrl+C` to stop early.

**Logs:** `data/logs/<exchange>.log`
**PIDs:** `data/collector.pids`

Stop manually:
```bash
kill $(cat data/collector.pids)
```

## Output Format

Each symbol gets its own file per day:

```
data/raw/<exchange>/<symbol>_YYYYMMDD.gz
```

Each line inside the gzip file:

```
<unix_timestamp_nanoseconds> <raw_json_payload>
```

Example:
```
1708425600000000000 {"e":"trade","s":"BTCUSDT","p":"52341.10","q":"0.003",...}
```

Files rotate at **midnight UTC**.

## Data Directory Structure

```
data/
├── raw/
│   ├── binance/
│   │   ├── spot/
│   │   │   ├── btcusdt_20260220.gz
│   │   │   └── ethusdt_20260220.gz
│   │   └── futures/um/
│   │       └── btcusdt_20260220.gz
│   ├── bybit/
│   │   └── btcusdt_20260220.gz
│   └── hyperliquid/
│       └── btc_20260220.gz
├── logs/
│   ├── binancespot.log
│   ├── binancefutures.log
│   ├── bybit.log
│   └── hyperliquid.log
└── collector.pids
```
