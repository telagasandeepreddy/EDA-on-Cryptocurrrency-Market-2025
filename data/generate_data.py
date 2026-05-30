"""
generate_crypto_data.py
Generate realistic 2025 crypto market data for top 50 cryptos
covering daily OHLCV, market cap, sentiment, macro events
"""
import pandas as pd
import numpy as np
import os
from datetime import datetime, timedelta

np.random.seed(2025)
rng = np.random.default_rng(2025)

CRYPTOS = [
    ("BTC",   "Bitcoin",           94000, 1_850_000_000_000, "Layer-1"),
    ("ETH",   "Ethereum",          3400,  408_000_000_000,   "Layer-1"),
    ("BNB",   "BNB",               680,   98_000_000_000,    "Exchange"),
    ("SOL",   "Solana",            195,   92_000_000_000,    "Layer-1"),
    ("XRP",   "XRP",               0.62,  71_000_000_000,    "Payments"),
    ("USDC",  "USD Coin",          1.0,   62_000_000_000,    "Stablecoin"),
    ("ADA",   "Cardano",           0.58,  20_000_000_000,    "Layer-1"),
    ("AVAX",  "Avalanche",         42,    18_000_000_000,    "Layer-1"),
    ("DOGE",  "Dogecoin",          0.19,  27_000_000_000,    "Meme"),
    ("TRX",   "TRON",              0.14,  12_000_000_000,    "Layer-1"),
    ("DOT",   "Polkadot",          9.8,   13_000_000_000,    "Layer-0"),
    ("LINK",  "Chainlink",         18,    11_000_000_000,    "Oracle"),
    ("MATIC", "Polygon",           1.1,   11_000_000_000,    "Layer-2"),
    ("UNI",   "Uniswap",           12,    9_000_000_000,     "DeFi"),
    ("LTC",   "Litecoin",          88,    6_600_000_000,     "Payments"),
    ("ATOM",  "Cosmos",            11,    4_300_000_000,     "Layer-0"),
    ("XLM",   "Stellar",           0.14,  4_100_000_000,     "Payments"),
    ("NEAR",  "NEAR Protocol",     6.2,   6_800_000_000,     "Layer-1"),
    ("INJ",   "Injective",         34,    3_200_000_000,     "DeFi"),
    ("ARB",   "Arbitrum",          1.8,   4_500_000_000,     "Layer-2"),
    ("OP",    "Optimism",          2.6,   3_400_000_000,     "Layer-2"),
    ("HBAR",  "Hedera",            0.11,  4_000_000_000,     "Layer-1"),
    ("FIL",   "Filecoin",          6.5,   3_600_000_000,     "Storage"),
    ("APT",   "Aptos",             9.5,   4_200_000_000,     "Layer-1"),
    ("VET",   "VeChain",           0.038, 2_700_000_000,     "Supply Chain"),
    ("ALGO",  "Algorand",          0.19,  1_600_000_000,     "Layer-1"),
    ("SAND",  "The Sandbox",       0.52,  1_200_000_000,     "Metaverse"),
    ("AXS",   "Axie Infinity",     8.2,   1_400_000_000,     "Gaming"),
    ("MANA",  "Decentraland",      0.44,  820_000_000,       "Metaverse"),
    ("CRV",   "Curve DAO",         0.62,  700_000_000,       "DeFi"),
    ("AAVE",  "Aave",              105,   1_600_000_000,     "DeFi"),
    ("MKR",   "Maker",             1850,  1_700_000_000,     "DeFi"),
    ("RUNE",  "THORChain",         5.4,   1_900_000_000,     "DeFi"),
    ("GRT",   "The Graph",         0.22,  2_100_000_000,     "Infra"),
    ("SNX",   "Synthetix",         2.8,   920_000_000,       "DeFi"),
    ("LDO",   "Lido DAO",          2.1,   1_900_000_000,     "DeFi"),
    ("IMX",   "Immutable",         2.1,   3_200_000_000,     "Gaming"),
    ("FTM",   "Fantom",            0.88,  2_500_000_000,     "Layer-1"),
    ("EGLD",  "MultiversX",        42,    1_100_000_000,     "Layer-1"),
    ("FLOW",  "Flow",              0.92,  940_000_000,       "Layer-1"),
    ("ROSE",  "Oasis Network",     0.095, 400_000_000,       "Privacy"),
    ("ZIL",   "Zilliqa",           0.019, 310_000_000,       "Layer-1"),
    ("ENJ",   "Enjin Coin",        0.28,  470_000_000,       "Gaming"),
    ("CHZ",   "Chiliz",            0.092, 640_000_000,       "Sports"),
    ("BAT",   "Basic Attention",   0.24,  360_000_000,       "AdTech"),
    ("1INCH", "1inch",             0.42,  490_000_000,       "DeFi"),
    ("KAVA",  "Kava",              0.72,  600_000_000,       "DeFi"),
    ("WLD",   "Worldcoin",         2.8,   3_900_000_000,     "AI"),
    ("FET",   "Fetch.ai",          1.45,  3_100_000_000,     "AI"),
    ("RNDR",  "Render",            8.4,   3_500_000_000,     "AI"),
]

MACRO_EVENTS = [
    ("2025-01-10", "Bitcoin ETF Inflows Record",        1.08, ["Layer-1","Exchange","DeFi"],        14),
    ("2025-01-20", "Trump Inauguration Crypto Boom",    1.12, ["ALL"],                              7),
    ("2025-02-03", "Fed Signals Rate Pause",             1.05, ["ALL"],                              10),
    ("2025-02-18", "Ethereum Pectra Upgrade Hype",      1.10, ["Layer-1","Layer-2","DeFi"],         12),
    ("2025-03-05", "SEC Approves Altcoin ETF Filings",  1.09, ["Layer-1","DeFi"],                   8),
    ("2025-03-22", "Global Equity Selloff",             0.88, ["ALL"],                              6),
    ("2025-04-01", "Bitcoin Halving Cycle Peak",        1.15, ["Layer-1","Payments","Meme"],        20),
    ("2025-04-19", "Altcoin Season Begins",             1.13, ["Layer-2","DeFi","Gaming","AI"],     18),
    ("2025-05-07", "Stablecoin Regulation Passed",      0.95, ["DeFi","Stablecoin","Payments"],     5),
    ("2025-05-25", "BTC Hits 110K All-Time High",       1.18, ["ALL"],                              10),
    ("2025-06-10", "China Relaxes Crypto Stance",       1.07, ["Layer-1","Exchange"],               12),
    ("2025-06-28", "Summer Low Volume Selloff",         0.91, ["ALL"],                              15),
    ("2025-07-04", "AI Tokens Surge (AGI Narrative)",   1.20, ["AI","Infra"],                       22),
    ("2025-07-20", "DeFi TVL Hits Record $200B",        1.12, ["DeFi","Layer-2"],                   10),
    ("2025-08-05", "Macro Uncertainty / Rate Hike Fear",0.85, ["ALL"],                              8),
    ("2025-08-18", "Gaming & Metaverse NFT Revival",    1.14, ["Gaming","Metaverse"],               16),
    ("2025-09-02", "Ethereum ETF Net Inflows Record",   1.11, ["Layer-1","Layer-2","DeFi"],         12),
    ("2025-09-20", "End-of-Q3 Institutional Rebalance", 0.93, ["ALL"],                              7),
    ("2025-10-05", "Bitcoin Dominance Hits 62%",        1.10, ["Layer-1"],                          14),
    ("2025-10-26", "Altcoins Catch-Up Rally",           1.16, ["Layer-0","Oracle","AI","DeFi"],     20),
    ("2025-11-08", "Post-Election Market Rally",        1.14, ["ALL"],                              12),
    ("2025-11-22", "BTC Crosses 130K",                  1.22, ["ALL"],                              10),
    ("2025-12-05", "Year-End Bull Run",                 1.18, ["ALL"],                              18),
    ("2025-12-24", "Christmas Profit Taking",           0.92, ["ALL"],                              8),
]

def get_event_multiplier(date_str, sector):
    mult = 1.0
    d_dt = datetime.strptime(date_str, "%Y-%m-%d")
    for ev_date, _, impact, sectors, duration in MACRO_EVENTS:
        ev_dt = datetime.strptime(ev_date, "%Y-%m-%d")
        delta = (d_dt - ev_dt).days
        if 0 <= delta < duration:
            if "ALL" in sectors or sector in sectors:
                decay = 1 - (delta / duration) * 0.5
                mult *= 1 + (impact - 1) * decay
    return mult

def price_series(base, n=365, sector="Layer-1"):
    vol_map = {
        "Stablecoin":0.0002,"Payments":0.028,"Layer-1":0.038,"Layer-2":0.045,
        "DeFi":0.052,"Gaming":0.060,"Metaverse":0.062,"Exchange":0.032,
        "Oracle":0.042,"Layer-0":0.040,"Storage":0.048,"Supply Chain":0.038,
        "Infra":0.044,"Privacy":0.050,"AI":0.065,"AdTech":0.045,
        "Sports":0.055,"Meme":0.075,
    }
    daily_vol = vol_map.get(sector, 0.04)
    dates  = [datetime(2025,1,1) + timedelta(days=i) for i in range(n)]
    prices = [float(base)]
    for i in range(1, n):
        date_str = dates[i].strftime("%Y-%m-%d")
        ev_mult  = get_event_multiplier(date_str, sector)
        month    = dates[i].month
        seasonal = {1:1.003,2:1.002,3:1.001,4:1.004,5:1.001,6:0.999,
                    7:0.998,8:0.997,9:1.000,10:1.003,11:1.005,12:1.004}[month]
        drift = np.log(seasonal)
        shock = float(rng.normal(drift, daily_vol))
        new_p = prices[-1] * np.exp(shock) * (ev_mult ** (1/max(1,int(daily_vol*100))))
        if sector == "Stablecoin":
            new_p = 1.0 + float(rng.normal(0, 0.0003))
        prices.append(max(new_p, base * 0.05))
    return prices, dates

rows = []
for sym, name, base_price, base_mcap, sector in CRYPTOS:
    prices, dates = price_series(base_price, 365, sector)
    supply = base_mcap / base_price if base_price > 0 else 0

    for i, (price, dt) in enumerate(zip(prices, dates)):
        date_str = dt.strftime("%Y-%m-%d")
        if sector == "Stablecoin":
            high  = price * (1 + abs(float(rng.normal(0, 0.001))))
            low   = price * (1 - abs(float(rng.normal(0, 0.001))))
            open_ = price * (1 + float(rng.normal(0, 0.0005)))
        else:
            iv    = price * float(rng.uniform(0.01, 0.07))
            high  = price + abs(float(rng.normal(0, iv)))
            low   = max(price - abs(float(rng.normal(0, iv*0.8))), price*0.85)
            open_ = price * (1 + float(rng.normal(0, 0.015)))

        volume_usd = base_mcap * float(rng.uniform(0.01, 0.12))
        for ev_date, _, impact, sectors, _ in MACRO_EVENTS:
            if ev_date == date_str and ("ALL" in sectors or sector in sectors):
                volume_usd *= (1 + (impact-1)*5)

        market_cap = price * supply
        pct_chg    = (prices[i]-prices[i-1])/max(prices[i-1],0.0001) if i>0 else 0.0

        fg_raw  = 50 + pct_chg*400 + float(rng.normal(0,8))
        fg      = int(np.clip(fg_raw, 0, 100))
        if   fg < 20: sentiment = "Extreme Fear"
        elif fg < 40: sentiment = "Fear"
        elif fg < 60: sentiment = "Neutral"
        elif fg < 80: sentiment = "Greed"
        else:         sentiment = "Extreme Greed"

        rsi = float(np.clip(30 + 40*(price/base_price)**0.3 + float(rng.normal(0,8)), 10, 90))

        # 7-day and 30-day rolling returns (approx via index offsets)
        ret_7d  = (prices[i]/prices[max(0,i-7)]  - 1)*100 if i>=7  else 0.0
        ret_30d = (prices[i]/prices[max(0,i-30)] - 1)*100 if i>=30 else 0.0

        rows.append({
            "date":             date_str,
            "symbol":           sym,
            "name":             name,
            "sector":           sector,
            "open":             round(float(open_), 6),
            "high":             round(float(high),  6),
            "low":              round(float(low),   6),
            "close":            round(float(price), 6),
            "volume_usd":       round(float(volume_usd), 2),
            "market_cap_usd":   round(float(market_cap), 2),
            "fear_greed_index": fg,
            "sentiment":        sentiment,
            "rsi_14":           round(rsi, 2),
            "return_1d_pct":    round(float(pct_chg*100), 4),
            "return_7d_pct":    round(float(ret_7d), 4),
            "return_30d_pct":   round(float(ret_30d), 4),
            "macro_event":      next((e[1] for e in MACRO_EVENTS if e[0]==date_str and
                                     ("ALL" in e[3] or sector in e[3])), None),
        })

df = pd.DataFrame(rows)
out = "/home/claude/crypto-eda-2025/data/raw/crypto_market_2025.csv"
df.to_csv(out, index=False)
print(f"Rows: {len(df):,}  |  Cryptos: {df['symbol'].nunique()}  |  Dates: {df['date'].min()} → {df['date'].max()}")
