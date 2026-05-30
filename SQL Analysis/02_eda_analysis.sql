-- ============================================================
-- 02_eda_analysis.sql
-- Exploratory Data Analysis Queries — Crypto Market 2025
-- Run against crypto_market_2025.db (SQLite)
-- ============================================================

-- ══════════════════════════════════════════════════════════════
-- SECTION 1 — MARKET OVERVIEW
-- ══════════════════════════════════════════════════════════════

-- 1a. Full-year summary: total market cap, volume, returns per coin
SELECT
    symbol,
    name,
    sector,
    ROUND(MIN(close), 6)                AS price_low,
    ROUND(MAX(close), 6)                AS price_high,
    ROUND(MAX(close)/MIN(close)-1, 4)   AS price_range_ratio,
    ROUND(AVG(market_cap_usd)/1e9, 2)   AS avg_mcap_bn,
    ROUND(SUM(volume_usd)/1e9, 2)       AS total_vol_bn,
    ROUND(AVG(return_1d_pct), 4)        AS avg_daily_return,
    ROUND(AVG(rsi_14), 2)               AS avg_rsi
FROM daily_prices
JOIN coins USING (symbol)
GROUP BY symbol
ORDER BY avg_mcap_bn DESC
LIMIT 50;

-- 1b. Total crypto market cap by month
SELECT
    strftime('%Y-%m', date)            AS month,
    ROUND(SUM(market_cap_usd)/1e12, 4) AS total_mcap_trillion,
    ROUND(SUM(volume_usd)/1e9, 2)      AS total_volume_bn,
    ROUND(AVG(fear_greed_index), 1)    AS avg_fear_greed
FROM daily_prices
GROUP BY month
ORDER BY month;

-- 1c. BTC dominance trend (BTC mcap / total mcap) by month
SELECT
    strftime('%Y-%m', date)  AS month,
    ROUND(
        SUM(CASE WHEN symbol='BTC' THEN market_cap_usd ELSE 0 END) /
        NULLIF(SUM(market_cap_usd),0) * 100, 2
    ) AS btc_dominance_pct,
    ROUND(
        SUM(CASE WHEN symbol='ETH' THEN market_cap_usd ELSE 0 END) /
        NULLIF(SUM(market_cap_usd),0) * 100, 2
    ) AS eth_dominance_pct
FROM daily_prices
GROUP BY month
ORDER BY month;


-- ══════════════════════════════════════════════════════════════
-- SECTION 2 — PRICE & RETURN ANALYSIS
-- ══════════════════════════════════════════════════════════════

-- 2a. Top 10 best performing coins (YTD return)
WITH ytd AS (
    SELECT
        symbol, name, sector,
        FIRST_VALUE(close) OVER (PARTITION BY symbol ORDER BY date)       AS price_jan1,
        LAST_VALUE(close)  OVER (PARTITION BY symbol ORDER BY date
                                 ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS price_dec31
    FROM daily_prices
    JOIN coins USING (symbol)
)
SELECT DISTINCT
    symbol, name, sector,
    ROUND(price_jan1, 6)                            AS start_price,
    ROUND(price_dec31, 6)                           AS end_price,
    ROUND((price_dec31/price_jan1 - 1)*100, 2)      AS ytd_return_pct
FROM ytd
ORDER BY ytd_return_pct DESC
LIMIT 10;

-- 2b. Most volatile coins (std dev of daily returns)
SELECT
    dp.symbol,
    c.name,
    c.sector,
    ROUND(AVG(dp.return_1d_pct), 4)            AS avg_daily_return,
    -- SQLite has no STDDEV; we compute manually
    ROUND(
        SQRT(AVG(dp.return_1d_pct * dp.return_1d_pct) -
             AVG(dp.return_1d_pct) * AVG(dp.return_1d_pct)), 4
    )                                           AS volatility_1d,
    ROUND(MAX(dp.return_1d_pct), 2)            AS best_day_pct,
    ROUND(MIN(dp.return_1d_pct), 2)            AS worst_day_pct
FROM daily_prices dp
JOIN coins c ON dp.symbol = c.symbol
WHERE c.sector != 'Stablecoin'
GROUP BY dp.symbol
ORDER BY volatility_1d DESC
LIMIT 15;

-- 2c. Quarterly return breakdown
SELECT
    dp.symbol,
    c.sector,
    CASE
        WHEN CAST(strftime('%m',date) AS INT) BETWEEN 1 AND 3  THEN 'Q1'
        WHEN CAST(strftime('%m',date) AS INT) BETWEEN 4 AND 6  THEN 'Q2'
        WHEN CAST(strftime('%m',date) AS INT) BETWEEN 7 AND 9  THEN 'Q3'
        ELSE 'Q4'
    END AS quarter,
    ROUND(AVG(dp.return_1d_pct), 4)  AS avg_daily_return,
    ROUND(AVG(dp.return_7d_pct), 4)  AS avg_7d_return,
    ROUND(SUM(dp.volume_usd)/1e9, 3) AS total_vol_bn
FROM daily_prices dp
JOIN coins c ON dp.symbol = c.symbol
WHERE c.sector != 'Stablecoin'
GROUP BY dp.symbol, quarter
ORDER BY dp.symbol, quarter;

-- 2d. Day-of-week effect on returns
SELECT
    CASE strftime('%w', date)
        WHEN '0' THEN 'Sunday'
        WHEN '1' THEN 'Monday'
        WHEN '2' THEN 'Tuesday'
        WHEN '3' THEN 'Wednesday'
        WHEN '4' THEN 'Thursday'
        WHEN '5' THEN 'Friday'
        WHEN '6' THEN 'Saturday'
    END AS day_of_week,
    strftime('%w', date) AS dow_num,
    ROUND(AVG(return_1d_pct), 4)   AS avg_return,
    ROUND(AVG(volume_usd)/1e9, 3)  AS avg_volume_bn,
    COUNT(*)                        AS observations
FROM daily_prices
WHERE symbol = 'BTC'
GROUP BY dow_num
ORDER BY dow_num;


-- ══════════════════════════════════════════════════════════════
-- SECTION 3 — SECTOR ANALYSIS
-- ══════════════════════════════════════════════════════════════

-- 3a. Sector performance ranking full year
SELECT
    c.sector,
    COUNT(DISTINCT dp.symbol)               AS coins,
    ROUND(AVG(dp.return_1d_pct), 4)         AS avg_daily_return,
    ROUND(AVG(dp.return_30d_pct), 4)        AS avg_monthly_return,
    ROUND(
        SQRT(AVG(dp.return_1d_pct * dp.return_1d_pct) -
             AVG(dp.return_1d_pct)*AVG(dp.return_1d_pct)), 4
    )                                        AS volatility,
    ROUND(SUM(dp.volume_usd)/1e9, 2)        AS total_vol_bn,
    ROUND(AVG(dp.rsi_14), 2)               AS avg_rsi
FROM daily_prices dp
JOIN coins c ON dp.symbol = c.symbol
WHERE c.sector != 'Stablecoin'
GROUP BY c.sector
ORDER BY avg_daily_return DESC;

-- 3b. Sector returns by quarter (heat-map data)
SELECT
    c.sector,
    CASE
        WHEN CAST(strftime('%m',dp.date) AS INT) BETWEEN 1 AND 3  THEN 'Q1'
        WHEN CAST(strftime('%m',dp.date) AS INT) BETWEEN 4 AND 6  THEN 'Q2'
        WHEN CAST(strftime('%m',dp.date) AS INT) BETWEEN 7 AND 9  THEN 'Q3'
        ELSE 'Q4'
    END AS quarter,
    ROUND(AVG(dp.return_1d_pct), 4)         AS avg_return,
    ROUND(AVG(dp.return_7d_pct), 4)         AS avg_7d_return,
    ROUND(SUM(dp.volume_usd)/1e9, 3)        AS vol_bn
FROM daily_prices dp
JOIN coins c ON dp.symbol = c.symbol
WHERE c.sector NOT IN ('Stablecoin')
GROUP BY c.sector, quarter
ORDER BY c.sector, quarter;


-- ══════════════════════════════════════════════════════════════
-- SECTION 4 — MACRO EVENT IMPACT
-- ══════════════════════════════════════════════════════════════

-- 4a. Average returns on macro event days vs normal days
SELECT
    CASE WHEN macro_event IS NOT NULL THEN 'Event Day' ELSE 'Normal Day' END AS day_type,
    ROUND(AVG(return_1d_pct), 4)   AS avg_return,
    ROUND(AVG(volume_usd)/1e9, 3)  AS avg_volume_bn,
    ROUND(AVG(fear_greed_index), 1) AS avg_fg_index,
    COUNT(*)                        AS observations
FROM daily_prices
WHERE symbol = 'BTC'
GROUP BY day_type;

-- 4b. Impact of each macro event on BTC return (event day + 3 days after)
SELECT
    macro_event,
    date,
    ROUND(return_1d_pct, 4)   AS return_1d,
    ROUND(return_7d_pct, 4)   AS return_7d,
    ROUND(volume_usd/1e9, 3)  AS volume_bn,
    fear_greed_index,
    sentiment
FROM daily_prices
WHERE macro_event IS NOT NULL
  AND symbol = 'BTC'
ORDER BY date;

-- 4c. Fear & Greed index distribution and average returns by sentiment bucket
SELECT
    sentiment,
    COUNT(*)                        AS days,
    ROUND(AVG(return_1d_pct), 4)   AS avg_1d_return,
    ROUND(AVG(return_7d_pct), 4)   AS avg_7d_return,
    ROUND(AVG(volume_usd)/1e9, 3)  AS avg_volume_bn,
    ROUND(MIN(return_1d_pct), 2)   AS worst_day,
    ROUND(MAX(return_1d_pct), 2)   AS best_day
FROM daily_prices
WHERE symbol = 'BTC'
GROUP BY sentiment
ORDER BY AVG(fear_greed_index);

-- 4d. Correlation proxy: Fear/Greed buckets vs 7d forward return
SELECT
    CASE
        WHEN fear_greed_index < 20 THEN '0-19 Extreme Fear'
        WHEN fear_greed_index < 40 THEN '20-39 Fear'
        WHEN fear_greed_index < 60 THEN '40-59 Neutral'
        WHEN fear_greed_index < 80 THEN '60-79 Greed'
        ELSE '80-100 Extreme Greed'
    END AS fg_bucket,
    ROUND(AVG(return_7d_pct), 4)  AS avg_7d_forward_return,
    COUNT(*)                       AS observations
FROM daily_prices
WHERE symbol IN ('BTC','ETH','SOL')
GROUP BY fg_bucket
ORDER BY MIN(fear_greed_index);


-- ══════════════════════════════════════════════════════════════
-- SECTION 5 — SEASONALITY & CALENDAR EFFECTS
-- ══════════════════════════════════════════════════════════════

-- 5a. Monthly seasonality — all coins
SELECT
    CAST(strftime('%m', date) AS INT)  AS month_num,
    CASE strftime('%m', date)
        WHEN '01' THEN 'January'  WHEN '02' THEN 'February'
        WHEN '03' THEN 'March'    WHEN '04' THEN 'April'
        WHEN '05' THEN 'May'      WHEN '06' THEN 'June'
        WHEN '07' THEN 'July'     WHEN '08' THEN 'August'
        WHEN '09' THEN 'September'WHEN '10' THEN 'October'
        WHEN '11' THEN 'November' WHEN '12' THEN 'December'
    END AS month_name,
    ROUND(AVG(return_1d_pct), 4)    AS avg_daily_return,
    ROUND(AVG(return_7d_pct), 4)    AS avg_7d_return,
    ROUND(AVG(fear_greed_index),1)  AS avg_sentiment,
    ROUND(SUM(volume_usd)/1e9, 2)   AS total_vol_bn
FROM daily_prices
WHERE symbol NOT IN ('USDC')
GROUP BY month_num
ORDER BY month_num;

-- 5b. Quarter-over-quarter volume growth
SELECT
    q.quarter,
    ROUND(SUM(q.vol)/1e9,2)   AS total_vol_bn,
    ROUND(AVG(q.ret),4)        AS avg_return,
    ROUND(AVG(q.fg),1)         AS avg_fear_greed
FROM (
    SELECT
        CASE
            WHEN CAST(strftime('%m',date) AS INT) BETWEEN 1 AND 3  THEN 'Q1'
            WHEN CAST(strftime('%m',date) AS INT) BETWEEN 4 AND 6  THEN 'Q2'
            WHEN CAST(strftime('%m',date) AS INT) BETWEEN 7 AND 9  THEN 'Q3'
            ELSE 'Q4'
        END AS quarter,
        volume_usd AS vol,
        return_1d_pct AS ret,
        fear_greed_index AS fg
    FROM daily_prices
    WHERE symbol NOT IN ('USDC')
) q
GROUP BY q.quarter
ORDER BY q.quarter;

-- 5c. Weekend vs weekday market behaviour
SELECT
    CASE WHEN strftime('%w',date) IN ('0','6') THEN 'Weekend' ELSE 'Weekday' END AS day_type,
    ROUND(AVG(return_1d_pct), 4)    AS avg_return,
    ROUND(AVG(volume_usd)/1e9, 3)   AS avg_volume_bn,
    ROUND(AVG(rsi_14), 2)           AS avg_rsi,
    COUNT(*)                         AS observations
FROM daily_prices
WHERE symbol NOT IN ('USDC')
GROUP BY day_type;


-- ══════════════════════════════════════════════════════════════
-- SECTION 6 — VOLUME & LIQUIDITY ANALYSIS
-- ══════════════════════════════════════════════════════════════

-- 6a. Top 10 coins by total 2025 trading volume
SELECT
    dp.symbol,
    c.name,
    c.sector,
    ROUND(SUM(dp.volume_usd)/1e9, 2)   AS total_vol_bn,
    ROUND(AVG(dp.volume_usd)/1e6, 2)   AS avg_daily_vol_mn,
    ROUND(AVG(dp.volume_usd/dp.market_cap_usd)*100, 4) AS avg_vol_to_mcap_pct
FROM daily_prices dp
JOIN coins c ON dp.symbol = c.symbol
GROUP BY dp.symbol
ORDER BY total_vol_bn DESC
LIMIT 10;

-- 6b. Months with highest trading volume (all coins)
SELECT
    strftime('%Y-%m', date)          AS month,
    ROUND(SUM(volume_usd)/1e9, 2)   AS total_vol_bn,
    ROUND(AVG(fear_greed_index),1)   AS avg_fg,
    COUNT(DISTINCT CASE WHEN macro_event IS NOT NULL THEN date END) AS event_days
FROM daily_prices
GROUP BY month
ORDER BY total_vol_bn DESC
LIMIT 12;

-- 6c. RSI overbought/oversold days and subsequent returns
SELECT
    CASE
        WHEN rsi_14 >= 70 THEN 'Overbought (RSI≥70)'
        WHEN rsi_14 <= 30 THEN 'Oversold (RSI≤30)'
        ELSE 'Neutral (30<RSI<70)'
    END AS rsi_zone,
    COUNT(*)                          AS observations,
    ROUND(AVG(return_1d_pct),4)      AS avg_next_day_return,
    ROUND(AVG(return_7d_pct),4)      AS avg_next_7d_return,
    ROUND(AVG(volume_usd)/1e9, 3)    AS avg_volume_bn
FROM daily_prices
WHERE symbol = 'BTC'
GROUP BY rsi_zone
ORDER BY MIN(rsi_14);


-- ══════════════════════════════════════════════════════════════
-- SECTION 7 — CORRELATION & INTER-MARKET
-- ══════════════════════════════════════════════════════════════

-- 7a. BTC vs ETH monthly return comparison
SELECT
    strftime('%Y-%m', b.date)        AS month,
    ROUND(AVG(b.return_1d_pct),4)   AS btc_avg_return,
    ROUND(AVG(e.return_1d_pct),4)   AS eth_avg_return,
    ROUND(AVG(b.return_1d_pct) - AVG(e.return_1d_pct), 4) AS btc_vs_eth_spread,
    ROUND(AVG(b.fear_greed_index),1) AS avg_sentiment
FROM daily_prices b
JOIN daily_prices e ON b.date = e.date AND e.symbol = 'ETH'
WHERE b.symbol = 'BTC'
GROUP BY month
ORDER BY month;

-- 7b. AI token sector vs BTC during AI narrative events
SELECT
    dp.date,
    c.sector,
    ROUND(AVG(dp.return_1d_pct),4)   AS sector_avg_return,
    MAX(CASE WHEN dp.symbol='BTC' THEN dp.return_1d_pct END) AS btc_return,
    dp.macro_event
FROM daily_prices dp
JOIN coins c ON dp.symbol = c.symbol
WHERE dp.date BETWEEN '2025-07-01' AND '2025-07-31'
  AND (c.sector = 'AI' OR dp.symbol = 'BTC')
GROUP BY dp.date, c.sector
ORDER BY dp.date, c.sector;

-- 7c. High-fear days: which sectors hold value best
SELECT
    c.sector,
    ROUND(AVG(dp.return_1d_pct),4)   AS avg_return_on_fear_days,
    COUNT(*)                          AS observations
FROM daily_prices dp
JOIN coins c ON dp.symbol = c.symbol
WHERE dp.sentiment IN ('Extreme Fear','Fear')
  AND c.sector != 'Stablecoin'
GROUP BY c.sector
ORDER BY avg_return_on_fear_days DESC;
