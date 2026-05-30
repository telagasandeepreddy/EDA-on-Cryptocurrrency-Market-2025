-- ============================================================
-- crypto_schema.sql
-- Database schema for Crypto Market EDA 2025
-- Compatible with SQLite (used in Python pipeline)
-- ============================================================

-- Drop tables if re-running
DROP TABLE IF EXISTS macro_events;
DROP TABLE IF EXISTS daily_prices;
DROP TABLE IF EXISTS coins;

-- ── Coin master reference ──────────────────────────────────────
CREATE TABLE coins (
    symbol          TEXT PRIMARY KEY,
    name            TEXT NOT NULL,
    sector          TEXT NOT NULL,
    initial_price   REAL,
    initial_mcap    REAL
);

-- ── Daily OHLCV + derived metrics ─────────────────────────────
CREATE TABLE daily_prices (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    date            TEXT    NOT NULL,
    symbol          TEXT    NOT NULL REFERENCES coins(symbol),
    open            REAL,
    high            REAL,
    low             REAL,
    close           REAL,
    volume_usd      REAL,
    market_cap_usd  REAL,
    fear_greed_index INTEGER,
    sentiment       TEXT,
    rsi_14          REAL,
    return_1d_pct   REAL,
    return_7d_pct   REAL,
    return_30d_pct  REAL,
    macro_event     TEXT,
    UNIQUE(date, symbol)
);

-- ── Macro events reference ─────────────────────────────────────
CREATE TABLE macro_events (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    event_date      TEXT    NOT NULL,
    event_name      TEXT    NOT NULL,
    impact_type     TEXT    CHECK(impact_type IN ('Bullish','Bearish','Mixed')),
    affected_sectors TEXT,
    duration_days   INTEGER
);

-- ── Indexes for analytical query performance ───────────────────
CREATE INDEX idx_prices_date   ON daily_prices(date);
CREATE INDEX idx_prices_symbol ON daily_prices(symbol);
CREATE INDEX idx_prices_sector ON daily_prices(date, symbol);
CREATE INDEX idx_prices_sentiment ON daily_prices(sentiment);

-- ── Useful views ───────────────────────────────────────────────

-- Latest snapshot per coin (most recent date)
CREATE VIEW v_latest_snapshot AS
SELECT
    dp.symbol,
    c.name,
    c.sector,
    dp.date,
    dp.close             AS price_usd,
    dp.market_cap_usd,
    dp.volume_usd,
    dp.return_1d_pct,
    dp.return_7d_pct,
    dp.return_30d_pct,
    dp.rsi_14,
    dp.fear_greed_index,
    dp.sentiment
FROM daily_prices dp
JOIN coins c ON dp.symbol = c.symbol
WHERE dp.date = (SELECT MAX(date) FROM daily_prices WHERE symbol = dp.symbol);

-- Monthly aggregates per coin
CREATE VIEW v_monthly_summary AS
SELECT
    strftime('%Y-%m', date)   AS year_month,
    CAST(strftime('%m', date) AS INTEGER) AS month_num,
    symbol,
    ROUND(AVG(close), 6)      AS avg_close,
    ROUND(MAX(high),  6)      AS month_high,
    ROUND(MIN(low),   6)      AS month_low,
    ROUND(SUM(volume_usd)/1e9, 4) AS total_volume_bn,
    ROUND(AVG(market_cap_usd)/1e9,4) AS avg_mcap_bn,
    ROUND(AVG(return_1d_pct), 4) AS avg_daily_return,
    ROUND(AVG(fear_greed_index), 1) AS avg_fear_greed,
    COUNT(*) AS trading_days
FROM daily_prices
GROUP BY year_month, symbol;

-- Sector aggregates
CREATE VIEW v_sector_performance AS
SELECT
    c.sector,
    strftime('%Y-%m', dp.date) AS year_month,
    COUNT(DISTINCT dp.symbol)  AS coin_count,
    ROUND(AVG(dp.return_1d_pct), 4)   AS avg_daily_return,
    ROUND(AVG(dp.return_7d_pct), 4)   AS avg_7d_return,
    ROUND(AVG(dp.return_30d_pct), 4)  AS avg_30d_return,
    ROUND(SUM(dp.volume_usd)/1e9, 3)  AS total_volume_bn,
    ROUND(AVG(dp.fear_greed_index),1) AS avg_sentiment_score,
    ROUND(AVG(dp.rsi_14), 2)          AS avg_rsi
FROM daily_prices dp
JOIN coins c ON dp.symbol = c.symbol
GROUP BY c.sector, year_month;
