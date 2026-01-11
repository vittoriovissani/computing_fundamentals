# ==============================================================================
# TIME SERIES DATA EXTRACTION FOR GRETL PROJECT - VERSION 3 (SIMPLIFIED)
# ==============================================================================
# 
# Extracts time series data from EU procurement CSVs (2009-2024)
# for furniture sector (CPV 391*) to create monthly/quarterly aggregates
#
# KEY INSIGHT ON DEDUPLICATION:
# The dataset has multiple rows for the same bid due to multiple publications.
# Primary key for a unique bid: (tender_id, lot_lotId, bid_row_nr)
# To deduplicate: keep only the row with max(publication_row_nr) per bid.
#
# OUTPUT: Monthly and quarterly time series suitable for regression/forecasting
# ==============================================================================

import pandas as pd
import numpy as np
import os
from glob import glob

# ==============================================================================
# CONFIGURATION
# ==============================================================================

DATA_DIR = "/Users/vittoriovissani/Documents/Computing fundamentals/workspace esame/data-all-csv"
OUTPUT_DIR = "/Users/vittoriovissani/Documents/Computing fundamentals/workspace esame/repository"

# Columns needed for time series analysis
COLS_TO_LOAD = [
    "tender_id",
    "tender_mainCpv",
    "tender_country",
    "tender_awardDecisionDate",
    "tender_contractSignatureDate",
    "tender_publications_lastContractAwardDate",
    "tender_procedureType",
    "tender_size",
    "lot_lotId",
    "lot_bidsCount",
    "lot_validBidsCount",
    "lot_isAwarded",
    "bid_row_nr",
    "bid_price_EUR",
    "bid_isWinning",
    "publication_row_nr"
]

# Outlier thresholds
# Based on distribution analysis: 99.9th percentile ≈ 8M EUR
# We use 5M EUR as cutoff to exclude framework agreements where
# the maximum contract value is assigned to each lot, distorting averages.
# This also excludes data entry errors and placeholder values.
MAX_REASONABLE_PRICE_EUR = 5_000_000  # 5 million EUR


# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

def to_numeric_price(s: pd.Series) -> pd.Series:
    """Convert price string to numeric, handling European decimal format."""
    return pd.to_numeric(
        s.astype(str).str.replace(",", ".", regex=False), 
        errors="coerce"
    )


def choose_event_date(df: pd.DataFrame) -> pd.Series:
    """Pick the most suitable 'event date' for time aggregation.
    Priority: awardDecisionDate → contractSignatureDate → lastContractAwardDate
    """
    d1 = pd.to_datetime(df.get("tender_awardDecisionDate"), errors="coerce")
    d2 = pd.to_datetime(df.get("tender_contractSignatureDate"), errors="coerce")
    d3 = pd.to_datetime(df.get("tender_publications_lastContractAwardDate"), errors="coerce")
    return d1.fillna(d2).fillna(d3)


def load_year_file(filepath: str, year: str) -> pd.DataFrame:
    """Load a single year file in chunks, filtering for furniture sector."""
    print(f"  Loading {year}...", end=" ")
    
    chunks = []
    chunk_size = 500_000
    
    try:
        for chunk in pd.read_csv(
            filepath,
            sep=';',
            usecols=COLS_TO_LOAD,
            dtype=str,
            chunksize=chunk_size,
            on_bad_lines='skip'
        ):
            # Filter furniture sector (CPV 391*)
            furniture_chunk = chunk[
                chunk['tender_mainCpv'].str.startswith('391', na=False)
            ]
            if len(furniture_chunk) > 0:
                chunks.append(furniture_chunk)
                
    except Exception as e:
        print(f"Error: {e}")
        return pd.DataFrame()
    
    if chunks:
        result = pd.concat(chunks, ignore_index=True)
        print(f"{len(result):,} rows")
        return result
    else:
        print("No data")
        return pd.DataFrame()


# ==============================================================================
# MAIN EXTRACTION LOGIC
# ==============================================================================

def extract_time_series():
    """Main extraction function with correct deduplication logic."""
    
    print("=" * 70)
    print("TIME SERIES EXTRACTION FOR FURNITURE SECTOR (CPV 391*)")
    print("=" * 70)
    
    # =========================================================================
    # STEP 1: Load all year files
    # =========================================================================
    print("\n[1] Loading data files...")
    
    files = sorted(glob(os.path.join(DATA_DIR, "data-all-20*.csv")))
    print(f"Found {len(files)} files")
    
    all_data = []
    for filepath in files:
        year = os.path.basename(filepath).replace("data-all-", "").replace(".csv", "")
        if year.isdigit():
            year_data = load_year_file(filepath, year)
            if len(year_data) > 0:
                all_data.append(year_data)
    
    if not all_data:
        print("ERROR: No data found!")
        return None, None
    
    # Combine all years
    print("\n[2] Combining all years...")
    df = pd.concat(all_data, ignore_index=True)
    print(f"  Total rows: {len(df):,}")
    
    # =========================================================================
    # STEP 2: Convert numeric fields
    # =========================================================================
    print("\n[3] Converting fields...")
    df["publication_row_nr"] = pd.to_numeric(df["publication_row_nr"], errors="coerce")
    df["bid_price_EUR"] = to_numeric_price(df["bid_price_EUR"])
    df["lot_bidsCount"] = pd.to_numeric(df["lot_bidsCount"], errors="coerce")
    df["lot_validBidsCount"] = pd.to_numeric(df["lot_validBidsCount"], errors="coerce")
    df["event_date"] = choose_event_date(df)
    
    # =========================================================================
    # STEP 3: Filter winning bids only
    # =========================================================================
    print("\n[4] Filtering winning bids...")
    winners = df[df["bid_isWinning"] == "yes"].copy()
    print(f"  Winner rows: {len(winners):,}")
    
    # Drop rows with missing keys
    winners = winners.dropna(subset=["tender_id", "lot_lotId"])
    print(f"  After dropping missing keys: {len(winners):,}")
    
    # =========================================================================
    # STEP 4: DEDUPLICATION - Key insight!
    # A lot can have only ONE winning bid. The unique identifier for a 
    # winning bid is (tender_id, lot_lotId). Multiple rows exist due to:
    # 1) Multiple publications (publication_row_nr)
    # 2) Same tender appearing in multiple year files
    # We keep only the row with the highest publication_row_nr per lot.
    # =========================================================================
    print("\n[5] Deduplicating (one row per lot)...")
    
    n_before = len(winners)
    
    # Sort by publication_row_nr and keep last (highest) per lot
    winners = winners.sort_values("publication_row_nr", na_position="first")
    winners = winners.drop_duplicates(
        subset=["tender_id", "lot_lotId"], 
        keep="last"
    )
    
    n_after = len(winners)
    print(f"  Before: {n_before:,} → After: {n_after:,} (removed {n_before - n_after:,} duplicates)")
    
    # =========================================================================
    # STEP 5: Filter outliers
    # =========================================================================
    print("\n[6] Filtering outliers...")
    
    valid_price = (
        winners["bid_price_EUR"].notna() & 
        (winners["bid_price_EUR"] > 0) & 
        (winners["bid_price_EUR"] <= MAX_REASONABLE_PRICE_EUR)
    )
    
    n_outliers = (~valid_price).sum()
    if n_outliers > 0:
        # Show some outliers
        outliers = winners[~valid_price & winners["bid_price_EUR"].notna()]
        if len(outliers) > 0:
            print(f"  Price outliers (>{MAX_REASONABLE_PRICE_EUR/1e6:.0f}M EUR):")
            for _, row in outliers.head(5).iterrows():
                print(f"    - {row['tender_country']}: {row['bid_price_EUR']:,.0f} EUR")
    
    winners = winners[valid_price].copy()
    print(f"  Valid rows after outlier removal: {len(winners):,}")
    
    # =========================================================================
    # STEP 6: Filter rows without dates
    # =========================================================================
    print("\n[7] Filtering rows without dates...")
    n_before = len(winners)
    winners = winners[winners["event_date"].notna()].copy()
    print(f"  Rows with valid date: {len(winners):,} (removed {n_before - len(winners):,})")
    
    # =========================================================================
    # STEP 7: Create lot_key for aggregation
    # =========================================================================
    winners["lot_key"] = winners["tender_id"].astype(str) + "::" + winners["lot_lotId"].astype(str)
    
    # =========================================================================
    # STEP 8: Create time series aggregates
    # =========================================================================
    print("\n[8] Creating time series...")
    
    # Monthly
    winners["year_month"] = winners["event_date"].dt.to_period("M")
    
    monthly = winners.groupby("year_month").agg(
        n_tenders=("tender_id", "nunique"),
        n_lots=("lot_key", "nunique"),
        total_value=("bid_price_EUR", "sum"),
        avg_lot_price=("bid_price_EUR", "mean"),
        median_lot_price=("bid_price_EUR", "median"),
        avg_bids=("lot_bidsCount", "mean"),
        avg_valid_bids=("lot_validBidsCount", "mean"),
    ).reset_index()
    
    # Competition indicator: share of lots with exactly one bid
    winners["one_bid"] = (winners["lot_bidsCount"] == 1).astype(float)
    competition = winners.groupby("year_month").agg(
        n_lots_one_bid=("one_bid", "sum"),
        share_one_bid=("one_bid", "mean"),
    ).reset_index()
    
    monthly = monthly.merge(competition, on="year_month", how="left")
    monthly = monthly.sort_values("year_month")
    monthly["year_month"] = monthly["year_month"].astype(str)
    
    # Quarterly
    winners["year_quarter"] = winners["event_date"].dt.to_period("Q")
    
    quarterly = winners.groupby("year_quarter").agg(
        n_tenders=("tender_id", "nunique"),
        n_lots=("lot_key", "nunique"),
        total_value=("bid_price_EUR", "sum"),
        avg_lot_price=("bid_price_EUR", "mean"),
        median_lot_price=("bid_price_EUR", "median"),
        avg_bids=("lot_bidsCount", "mean"),
        avg_valid_bids=("lot_validBidsCount", "mean"),
    ).reset_index()
    
    competition_q = winners.groupby("year_quarter").agg(
        n_lots_one_bid=("one_bid", "sum"),
        share_one_bid=("one_bid", "mean"),
    ).reset_index()
    
    quarterly = quarterly.merge(competition_q, on="year_quarter", how="left")
    quarterly = quarterly.sort_values("year_quarter")
    quarterly["year_quarter"] = quarterly["year_quarter"].astype(str)
    
    print(f"  Monthly: {len(monthly)} observations")
    print(f"  Quarterly: {len(quarterly)} observations")
    
    # =========================================================================
    # STEP 9: Validation
    # =========================================================================
    print("\n[9] Validation checks...")
    
    # Check for unreasonable values
    max_monthly = monthly["total_value"].max()
    max_avg = monthly["avg_lot_price"].max()
    
    if max_monthly > 500_000_000:
        print(f"  ⚠ WARNING: Max monthly total > 500M EUR ({max_monthly:,.0f})")
    else:
        print(f"  ✓ Max monthly total: {max_monthly:,.0f} EUR (reasonable)")
    
    if max_avg > 10_000_000:
        print(f"  ⚠ WARNING: Max avg lot price > 10M EUR ({max_avg:,.0f})")
    else:
        print(f"  ✓ Max avg lot price: {max_avg:,.0f} EUR (reasonable)")
    
    # =========================================================================
    # STEP 10: Save
    # =========================================================================
    print("\n[10] Saving outputs...")
    
    monthly_path = os.path.join(OUTPUT_DIR, "furniture_monthly_ts.csv")
    quarterly_path = os.path.join(OUTPUT_DIR, "furniture_quarterly_ts.csv")
    
    monthly.to_csv(monthly_path, index=False)
    quarterly.to_csv(quarterly_path, index=False)
    
    print(f"  → {monthly_path}")
    print(f"  → {quarterly_path}")
    
    # =========================================================================
    # Summary
    # =========================================================================
    print("\n" + "=" * 70)
    print("EXTRACTION COMPLETE")
    print("=" * 70)
    print(f"Date range: {monthly['year_month'].min()} to {monthly['year_month'].max()}")
    print(f"\nSample data (2017):")
    print(monthly[monthly['year_month'].str.startswith('2017')][
        ['year_month', 'n_lots', 'total_value', 'avg_lot_price', 'median_lot_price']
    ].to_string(index=False))
    
    return monthly, quarterly


if __name__ == "__main__":
    monthly, quarterly = extract_time_series()
