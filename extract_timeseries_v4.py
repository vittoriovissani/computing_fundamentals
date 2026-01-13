# ==============================================================================
# TIME SERIES DATA EXTRACTION FOR GRETL PROJECT - VERSION 4
# ==============================================================================
# 
# Extracts monthly time series data from EU procurement CSVs (2008-2024)
# for furniture sector (CPV 391*) with focus on share_one_bid_value analysis.
#
# KEY VARIABLES:
# - share_one_bid_num:   n_lots_one_bid / n_lots (share by count)
# - share_one_bid_value: total_value_one_bid / total_value (share by value)
#
# OUTPUT: Monthly CSV (2008-04 to 2024-04) for Gretl regression/forecasting
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
    "lot_row_nr",
    "lot_bidsCount",
    "lot_isAwarded",
    "bid_price_EUR",
    "bid_isWinning"
]

# Outlier thresholds
# Based on distribution analysis: 99.9th percentile ≈ 8M EUR
# We use 5M EUR as cutoff to exclude framework agreements
MAX_REASONABLE_PRICE_EUR = 5_000_000  # 5 million EUR

# Time range for output
START_PERIOD = "2008-04"
END_PERIOD = "2024-04"


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


def create_full_month_range(start: str, end: str) -> pd.DataFrame:
    """Create a DataFrame with all months from start to end (inclusive)."""
    periods = pd.period_range(start=start, end=end, freq='M')
    df = pd.DataFrame({'year_month': periods.astype(str)})
    df['year'] = periods.year
    df['month'] = periods.month
    return df


# ==============================================================================
# MAIN EXTRACTION LOGIC
# ==============================================================================

def extract_time_series():
    """Main extraction function with share_one_bid_value as target variable."""
    
    print("=" * 70)
    print("TIME SERIES EXTRACTION FOR FURNITURE SECTOR (CPV 391*)")
    print("VERSION 4: Focus on share_one_bid_value")
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
        return None
    
    # Combine all years
    print("\n[2] Combining all years...")
    df = pd.concat(all_data, ignore_index=True)
    print(f"  Total rows: {len(df):,}")
    
    # =========================================================================
    # STEP 2: Convert numeric fields
    # =========================================================================
    print("\n[3] Converting fields...")
    df["bid_price_EUR"] = to_numeric_price(df["bid_price_EUR"])
    df["lot_bidsCount"] = pd.to_numeric(df["lot_bidsCount"], errors="coerce")
    df["event_date"] = choose_event_date(df)
    
    # =========================================================================
    # STEP 3: Filter winning bids only
    # =========================================================================
    print("\n[4] Filtering winning bids...")
    winners = df[df["bid_isWinning"] == "yes"].copy()
    print(f"  Winner rows: {len(winners):,}")
    
    # Drop rows with missing keys
    winners = winners.dropna(subset=["tender_id", "lot_row_nr"])
    print(f"  After dropping missing keys: {len(winners):,}")
    
    # =========================================================================
    # STEP 4: DEDUPLICATION - One row per lot
    # =========================================================================
    print("\n[5] Deduplicating (one row per lot)...")
    
    n_before = len(winners)
    winners = winners.drop_duplicates(
        subset=["tender_id", "lot_row_nr"], 
        keep="first"
    )
    n_after = len(winners)
    print(f"  Before: {n_before:,} → After: {n_after:,} (removed {n_before - n_after:,} duplicates)")
    
    # =========================================================================
    # STEP 5: Apply cleaning rules
    # =========================================================================
    print("\n[6] Applying cleaning rules...")
    
    # Rule 1: lot_value > 0
    valid_price = (
        winners["bid_price_EUR"].notna() & 
        (winners["bid_price_EUR"] > 0)
    )
    n_invalid_price = (~valid_price).sum()
    print(f"  Rows with invalid price (<=0 or missing): {n_invalid_price:,}")
    
    # Rule 2: lot_value <= MAX threshold (outliers)
    price_outliers = winners["bid_price_EUR"] > MAX_REASONABLE_PRICE_EUR
    n_outliers = price_outliers.sum()
    print(f"  Price outliers (>{MAX_REASONABLE_PRICE_EUR/1e6:.0f}M EUR): {n_outliers:,}")
    
    # Rule 3: n_bids > 0
    valid_bids = (
        winners["lot_bidsCount"].notna() & 
        (winners["lot_bidsCount"] > 0)
    )
    n_invalid_bids = (~valid_bids).sum()
    print(f"  Rows with invalid n_bids (<=0 or missing): {n_invalid_bids:,}")
    
    # Rule 4: valid date
    valid_date = winners["event_date"].notna()
    n_invalid_date = (~valid_date).sum()
    print(f"  Rows with missing date: {n_invalid_date:,}")
    
    # Apply all filters
    valid_mask = valid_price & ~price_outliers & valid_bids & valid_date
    winners = winners[valid_mask].copy()
    print(f"  Valid rows after cleaning: {len(winners):,}")
    
    # =========================================================================
    # STEP 6: Create lot-level variables
    # =========================================================================
    print("\n[7] Creating lot-level variables...")
    
    # Rename for clarity
    winners = winners.rename(columns={
        "bid_price_EUR": "lot_value",
        "lot_bidsCount": "n_bids"
    })
    
    # Create indicator for single-bid lots
    winners["is_one_bid"] = (winners["n_bids"] == 1).astype(int)
    
    # Value conditional on single bid
    winners["value_one_bid"] = winners["lot_value"] * winners["is_one_bid"]
    
    # Create year_month period
    winners["year_month_period"] = winners["event_date"].dt.to_period("M")
    
    # Create lot_key for counting unique lots
    winners["lot_key"] = winners["tender_id"].astype(str) + "::" + winners["lot_row_nr"].astype(str)
    
    # =========================================================================
    # STEP 7: Monthly aggregation
    # =========================================================================
    print("\n[8] Creating monthly aggregates...")
    
    # Group by year_month
    agg_dict = {
        "lot_key": "nunique",           # n_lots
        "lot_value": ["sum", "mean", "median"],
        "is_one_bid": "sum",            # n_lots_one_bid
        "value_one_bid": "sum",         # total_value_one_bid
        "n_bids": ["mean", "median"],
    }
    
    monthly_agg = winners.groupby("year_month_period").agg(agg_dict).reset_index()
    
    # Flatten column names
    monthly_agg.columns = [
        "year_month_period",
        "n_lots",
        "total_value",
        "avg_lot_value",
        "median_lot_value",
        "n_lots_one_bid",
        "total_value_one_bid",
        "avg_bids",
        "median_bids"
    ]
    
    # =========================================================================
    # STEP 8: Create full date range and merge
    # =========================================================================
    print("\n[9] Creating full date range...")
    
    # Create complete month range
    full_range = create_full_month_range(START_PERIOD, END_PERIOD)
    
    # Convert period to string for merge
    monthly_agg["year_month"] = monthly_agg["year_month_period"].astype(str)
    
    # Merge with full range (left join to keep all months)
    monthly = full_range.merge(
        monthly_agg.drop(columns=["year_month_period"]),
        on="year_month",
        how="left"
    )
    
    print(f"  Full range: {len(full_range)} months")
    print(f"  Months with data: {monthly['n_lots'].notna().sum()}")
    print(f"  Months without data: {monthly['n_lots'].isna().sum()}")
    
    # =========================================================================
    # STEP 9: Calculate derived variables
    # =========================================================================
    print("\n[10] Calculating derived variables...")
    
    # Fill missing values for count columns with 0 for calculation purposes
    # But we'll track zero_lots_month separately
    
    # Zero lots flag
    monthly["zero_lots_month"] = (monthly["n_lots"].isna() | (monthly["n_lots"] == 0)).astype(int)
    
    # Share by number of lots
    monthly["share_one_bid_num"] = np.where(
        monthly["n_lots"] > 0,
        monthly["n_lots_one_bid"] / monthly["n_lots"],
        np.nan  # NA when n_lots == 0
    )
    
    # Share by value (TARGET VARIABLE)
    monthly["share_one_bid_value"] = np.where(
        monthly["total_value"] > 0,
        monthly["total_value_one_bid"] / monthly["total_value"],
        np.nan  # NA when total_value == 0
    )
    
    # Ensure shares are in [0, 1] range
    monthly["share_one_bid_num"] = monthly["share_one_bid_num"].clip(0, 1)
    monthly["share_one_bid_value"] = monthly["share_one_bid_value"].clip(0, 1)
    
    # Recalculate avg_lot_value to ensure consistency
    monthly["avg_lot_value"] = np.where(
        monthly["n_lots"] > 0,
        monthly["total_value"] / monthly["n_lots"],
        np.nan
    )
    
    # =========================================================================
    # STEP 10: Quality flags
    # =========================================================================
    print("\n[11] Creating quality flags...")
    
    # Calculate percentiles for outlier detection (excluding NA)
    total_value_p99 = monthly["total_value"].quantile(0.99)
    share_value_p01 = monthly["share_one_bid_value"].quantile(0.01)
    share_value_p99 = monthly["share_one_bid_value"].quantile(0.99)
    
    print(f"  total_value P99: {total_value_p99:,.0f} EUR")
    print(f"  share_one_bid_value P01: {share_value_p01:.3f}")
    print(f"  share_one_bid_value P99: {share_value_p99:.3f}")
    
    # Outlier flags
    monthly["outlier_total_value"] = (monthly["total_value"] > total_value_p99).astype(int)
    monthly["outlier_share_value"] = (
        (monthly["share_one_bid_value"] < share_value_p01) | 
        (monthly["share_one_bid_value"] > share_value_p99)
    ).astype(int)
    
    # =========================================================================
    # STEP 11: Finalize column order and types
    # =========================================================================
    print("\n[12] Finalizing output...")
    
    # Define final column order
    final_columns = [
        "year_month",
        "year",
        "month",
        "n_lots",
        "total_value",
        "n_lots_one_bid",
        "total_value_one_bid",
        "share_one_bid_num",
        "share_one_bid_value",
        "avg_bids",
        "median_bids",
        "avg_lot_value",
        "median_lot_value",
        "zero_lots_month",
        "outlier_total_value",
        "outlier_share_value"
    ]
    
    # Select and order columns
    monthly = monthly[final_columns].copy()
    
    # Convert integer columns
    int_cols = ["year", "month", "zero_lots_month", "outlier_total_value", "outlier_share_value"]
    for col in int_cols:
        monthly[col] = monthly[col].astype(int)
    
    # Fill NA in count columns with 0 for months with no data
    count_cols = ["n_lots", "n_lots_one_bid"]
    for col in count_cols:
        monthly[col] = monthly[col].fillna(0).astype(int)
    
    # Fill NA in value columns with 0 for months with no data
    value_cols = ["total_value", "total_value_one_bid"]
    for col in value_cols:
        monthly[col] = monthly[col].fillna(0)
    
    # Sort by date
    monthly = monthly.sort_values("year_month").reset_index(drop=True)
    
    # =========================================================================
    # STEP 12: Validation
    # =========================================================================
    print("\n[13] Validation checks...")
    
    # Check for duplicates
    n_duplicates = monthly.duplicated(subset=["year_month"]).sum()
    print(f"  Duplicate year_month: {n_duplicates}")
    
    # Check date range
    print(f"  Date range: {monthly['year_month'].min()} to {monthly['year_month'].max()}")
    print(f"  Total months: {len(monthly)}")
    
    # Check share_one_bid_value range
    valid_share = monthly["share_one_bid_value"].dropna()
    print(f"  share_one_bid_value: min={valid_share.min():.3f}, max={valid_share.max():.3f}")
    print(f"  share_one_bid_value NA count: {monthly['share_one_bid_value'].isna().sum()}")
    
    # Summary statistics
    print("\n  Summary statistics for key variables:")
    summary_vars = ["n_lots", "total_value", "share_one_bid_num", "share_one_bid_value", "avg_bids"]
    print(monthly[summary_vars].describe().round(3).to_string())
    
    # =========================================================================
    # STEP 13: Save
    # =========================================================================
    print("\n[14] Saving output...")
    
    output_path = os.path.join(OUTPUT_DIR, "furniture_monthly_ts_v4.csv")
    
    # Save with proper NA handling
    monthly.to_csv(output_path, index=False, na_rep="NA")
    
    print(f"  → {output_path}")
    
    # =========================================================================
    # Summary
    # =========================================================================
    print("\n" + "=" * 70)
    print("EXTRACTION COMPLETE")
    print("=" * 70)
    print(f"Output file: {output_path}")
    print(f"Date range: {monthly['year_month'].min()} to {monthly['year_month'].max()}")
    print(f"Total observations: {len(monthly)}")
    print(f"Months with data: {(monthly['n_lots'] > 0).sum()}")
    print(f"Months without data (zero_lots_month=1): {monthly['zero_lots_month'].sum()}")
    
    # Sample output
    print("\nSample data (first 5 rows):")
    print(monthly.head().to_string(index=False))
    
    print("\nSample data (2020):")
    sample_2020 = monthly[monthly['year'] == 2020][
        ['year_month', 'n_lots', 'total_value', 'share_one_bid_num', 'share_one_bid_value']
    ]
    print(sample_2020.to_string(index=False))
    
    return monthly


if __name__ == "__main__":
    monthly = extract_time_series()
