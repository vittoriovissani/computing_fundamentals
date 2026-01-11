# ==============================================================================
# TIME SERIES DATA EXTRACTION FOR GRETL PROJECT - VERSION 2 (CORRECTED)
# ==============================================================================
# 
# Extracts time series data from EU procurement CSVs (2009-2024)
# for furniture sector (CPV 391*) to create monthly/quarterly aggregates
#
# CHANGES FROM V1:
# - Fixed deduplication: now operates at (tender_id, lot_lotId) level, not tender_id
# - Global deduplication AFTER combining all years (fixes cross-year duplicates)
# - Stricter outlier filter: excludes prices > 100M EUR and placeholder values
# - Correct operation order: filter winners → dedup → filter outliers → aggregate
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
    "lot_contractSignatureDate",
    "bid_row_nr",
    "bid_price_EUR",
    "bid_isWinning",
    "publication_row_nr"
]

# Outlier thresholds for price filtering
MAX_REASONABLE_PRICE_EUR = 100_000_000  # 100 million EUR
PLACEHOLDER_VALUES = [999_999_999, 999_999_999.99, 9_999_999_999]  # Common placeholder values


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

    Priority (most meaningful for awarded outcomes):
    1) tender_awardDecisionDate
    2) tender_contractSignatureDate  
    3) tender_publications_lastContractAwardDate

    Returns a datetime Series (may contain NaT).
    """
    d1 = pd.to_datetime(df.get("tender_awardDecisionDate"), errors="coerce")
    d2 = pd.to_datetime(df.get("tender_contractSignatureDate"), errors="coerce")
    d3 = pd.to_datetime(df.get("tender_publications_lastContractAwardDate"), errors="coerce")

    event_date = d1.fillna(d2).fillna(d3)
    return event_date


def is_outlier_price(price: pd.Series) -> pd.Series:
    """Identify outlier/placeholder prices that should be excluded.
    
    Returns a boolean Series: True = outlier (should be excluded)
    """
    is_missing = price.isna()
    is_non_positive = price <= 0
    is_too_high = price > MAX_REASONABLE_PRICE_EUR
    is_placeholder = price.isin(PLACEHOLDER_VALUES)
    
    return is_missing | is_non_positive | is_too_high | is_placeholder


def load_year_file(filepath: str, year: str) -> pd.DataFrame:
    """Load a single year file in chunks, filtering for furniture sector."""
    print(f"  Loading {year}...")
    
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
                furniture_chunk = furniture_chunk.copy()
                furniture_chunk['source_year'] = year  # Track source file
                chunks.append(furniture_chunk)
                
    except Exception as e:
        print(f"    Error: {e}")
        return pd.DataFrame()
    
    if chunks:
        result = pd.concat(chunks, ignore_index=True)
        print(f"    Found {len(result):,} furniture rows")
        return result
    else:
        print(f"    No furniture data found")
        return pd.DataFrame()


def dedup_winners_global(df: pd.DataFrame) -> pd.DataFrame:
    """
    Global deduplication of winning bids at the lot level.
    
    For each unique (tender_id, lot_lotId) combination:
    - Keep only the row with the highest publication_row_nr
    - This ensures we use the most recent publication data
    
    This function should be called AFTER:
    1. Combining all year files
    2. Filtering for winning bids only
    
    Returns: DataFrame with one row per unique lot
    """
    if df.empty:
        return df
    
    out = df.copy()
    
    # Convert publication_row_nr to numeric for sorting
    out["publication_row_nr"] = pd.to_numeric(out["publication_row_nr"], errors="coerce")
    
    # Create composite lot key
    out["lot_key"] = out["tender_id"].astype(str) + "::" + out["lot_lotId"].astype(str)
    
    # Sort by lot_key and publication_row_nr, then keep last (highest pub nr) per lot
    out = out.sort_values(["lot_key", "publication_row_nr"], na_position="first")
    out = out.drop_duplicates(subset=["lot_key"], keep="last")
    
    return out


def aggregate_to_period(winners: pd.DataFrame, period: str = "M") -> pd.DataFrame:
    """
    Aggregate winning bid data to monthly (M) or quarterly (Q) time series.
    
    Parameters:
        winners: DataFrame of deduplicated winning bids with columns:
                 - lot_key, tender_id, event_date, bid_price_EUR, lot_bidsCount, etc.
        period: "M" for monthly, "Q" for quarterly
        
    Returns: Aggregated time series DataFrame
    """
    if winners.empty:
        return pd.DataFrame()
    
    df = winners.copy()
    
    # Create period column
    period_col = "year_month" if period == "M" else "year_quarter"
    df[period_col] = df["event_date"].dt.to_period(period)
    
    # Aggregate winners (value metrics)
    agg_winners = df.groupby(period_col).agg(
        n_tenders=("tender_id", "nunique"),
        n_lots=("lot_key", "nunique"),
        total_value=("bid_price_EUR", "sum"),
        avg_lot_price=("bid_price_EUR", "mean"),
        median_lot_price=("bid_price_EUR", "median"),
        avg_bids=("lot_bidsCount", "mean"),
        avg_valid_bids=("lot_validBidsCount", "mean"),
    ).reset_index()
    
    # Competition indicators: lots with exactly one bid
    df["one_bid_lot"] = (df["lot_bidsCount"] == 1).astype(float)
    
    agg_competition = df.groupby(period_col).agg(
        n_lots_one_bid=("one_bid_lot", "sum"),
        share_one_bid=("one_bid_lot", "mean"),
    ).reset_index()
    
    # Merge
    result = agg_winners.merge(agg_competition, on=period_col, how="left")
    
    # Add n_lots_all (same as n_lots for winners, but useful for award_rate calculation)
    result["n_lots_all"] = result["n_lots"]
    
    return result


# ==============================================================================
# MAIN EXTRACTION LOGIC
# ==============================================================================

def extract_time_series():
    """Main extraction function with corrected logic."""
    
    print("=" * 70)
    print("TIME SERIES EXTRACTION FOR FURNITURE SECTOR (CPV 391*)")
    print("Version 2 - Corrected deduplication and outlier handling")
    print("=" * 70)
    
    # -------------------------------------------------------------------------
    # STEP 1: Load all year files
    # -------------------------------------------------------------------------
    print("\n[STEP 1] Loading all year files...")
    
    files = sorted(glob(os.path.join(DATA_DIR, "data-all-20*.csv")))
    print(f"Found {len(files)} data files")
    
    # Check for quick mode (single year for testing)
    quick_year = os.environ.get("TS_YEAR")
    if quick_year:
        print(f"  QUICK MODE: Processing only year {quick_year}")
    
    all_data = []
    for filepath in files:
        year = os.path.basename(filepath).replace("data-all-", "").replace(".csv", "")
        if year.isdigit():
            if quick_year and year != quick_year:
                continue
            year_data = load_year_file(filepath, year)
            if len(year_data) > 0:
                all_data.append(year_data)
    
    if not all_data:
        print("ERROR: No data found!")
        return None, None
    
    # Combine all years into single DataFrame
    print("\n[STEP 2] Combining all years...")
    combined = pd.concat(all_data, ignore_index=True)
    print(f"  Total raw rows: {len(combined):,}")
    print(f"  Unique tender_id values: {combined['tender_id'].nunique():,}")
    
    # -------------------------------------------------------------------------
    # STEP 3: Parse dates and convert numeric fields
    # -------------------------------------------------------------------------
    print("\n[STEP 3] Parsing dates and converting fields...")
    
    combined["event_date"] = choose_event_date(combined)
    combined["bid_price_EUR"] = to_numeric_price(combined["bid_price_EUR"])
    combined["lot_bidsCount"] = pd.to_numeric(combined["lot_bidsCount"], errors="coerce")
    combined["lot_validBidsCount"] = pd.to_numeric(combined["lot_validBidsCount"], errors="coerce")
    
    n_with_date = combined["event_date"].notna().sum()
    n_with_price = combined["bid_price_EUR"].notna().sum()
    print(f"  Rows with valid date: {n_with_date:,} ({100*n_with_date/len(combined):.1f}%)")
    print(f"  Rows with valid price: {n_with_price:,} ({100*n_with_price/len(combined):.1f}%)")
    
    # -------------------------------------------------------------------------
    # STEP 4: Filter for winning bids only
    # -------------------------------------------------------------------------
    print("\n[STEP 4] Filtering for winning bids only...")
    
    winners = combined[combined["bid_isWinning"] == "yes"].copy()
    print(f"  Winner rows: {len(winners):,}")
    
    # Drop rows missing tender_id or lot_lotId (cannot deduplicate)
    winners = winners.dropna(subset=["tender_id", "lot_lotId"])
    print(f"  After dropping rows with missing IDs: {len(winners):,}")
    
    # -------------------------------------------------------------------------
    # STEP 5: Global deduplication at lot level
    # -------------------------------------------------------------------------
    print("\n[STEP 5] Global deduplication (one row per lot)...")
    
    n_before = len(winners)
    winners = dedup_winners_global(winners)
    n_after = len(winners)
    
    print(f"  Before dedup: {n_before:,} rows")
    print(f"  After dedup:  {n_after:,} rows (unique lots)")
    print(f"  Duplicates removed: {n_before - n_after:,}")
    
    # -------------------------------------------------------------------------
    # STEP 6: Filter outlier prices
    # -------------------------------------------------------------------------
    print("\n[STEP 6] Filtering outlier prices...")
    
    outlier_mask = is_outlier_price(winners["bid_price_EUR"])
    n_outliers = outlier_mask.sum()
    
    # Log the outliers being removed
    if n_outliers > 0:
        outliers = winners[outlier_mask].copy()
        print(f"  Outliers found: {n_outliers}")
        print("  Sample outliers being removed:")
        for _, row in outliers.head(5).iterrows():
            print(f"    - {row['tender_country']}: {row['bid_price_EUR']:,.2f} EUR "
                  f"(tender: {row['tender_id'][:20]}...)")
    
    winners = winners[~outlier_mask].copy()
    print(f"  Rows after outlier removal: {len(winners):,}")
    
    # -------------------------------------------------------------------------
    # STEP 7: Filter rows without valid dates
    # -------------------------------------------------------------------------
    print("\n[STEP 7] Filtering rows without valid dates...")
    
    n_before = len(winners)
    winners = winners[winners["event_date"].notna()].copy()
    n_after = len(winners)
    
    print(f"  Rows with valid date: {n_after:,}")
    print(f"  Rows removed (no date): {n_before - n_after:,}")
    
    # -------------------------------------------------------------------------
    # STEP 8: Create time series aggregates
    # -------------------------------------------------------------------------
    print("\n[STEP 8] Creating time series aggregates...")
    
    # Monthly
    monthly = aggregate_to_period(winners, period="M")
    monthly = monthly.sort_values("year_month")
    monthly["year_month"] = monthly["year_month"].astype(str)
    
    # Quarterly
    quarterly = aggregate_to_period(winners, period="Q")
    quarterly = quarterly.sort_values("year_quarter")
    quarterly["year_quarter"] = quarterly["year_quarter"].astype(str)
    
    print(f"  Monthly observations: {len(monthly)}")
    print(f"  Quarterly observations: {len(quarterly)}")
    
    # -------------------------------------------------------------------------
    # STEP 9: Validation checks
    # -------------------------------------------------------------------------
    print("\n[STEP 9] Validation checks...")
    
    # Check 1: n_lots should always equal n_tenders or be close
    # (after our fix, n_lots >= n_tenders should always hold)
    invalid_lots = monthly[monthly["n_lots"] < monthly["n_tenders"]]
    if len(invalid_lots) > 0:
        print(f"  WARNING: {len(invalid_lots)} months have n_lots < n_tenders!")
    else:
        print("  ✓ n_lots >= n_tenders in all months")
    
    # Check 2: No billion-EUR months (sanity check)
    high_value_months = monthly[monthly["total_value"] > 500_000_000]  # 500M
    if len(high_value_months) > 0:
        print(f"  WARNING: {len(high_value_months)} months have total_value > 500M EUR!")
        print(high_value_months[["year_month", "total_value", "n_lots"]])
    else:
        print("  ✓ No months with total_value > 500M EUR")
    
    # Check 3: Avg lot price should be reasonable
    high_avg = monthly[monthly["avg_lot_price"] > 10_000_000]  # 10M
    if len(high_avg) > 0:
        print(f"  WARNING: {len(high_avg)} months have avg_lot_price > 10M EUR!")
    else:
        print("  ✓ No months with avg_lot_price > 10M EUR")
    
    # -------------------------------------------------------------------------
    # STEP 10: Save outputs
    # -------------------------------------------------------------------------
    print("\n[STEP 10] Saving outputs...")
    
    monthly_path = os.path.join(OUTPUT_DIR, "furniture_monthly_ts.csv")
    quarterly_path = os.path.join(OUTPUT_DIR, "furniture_quarterly_ts.csv")
    
    monthly.to_csv(monthly_path, index=False)
    quarterly.to_csv(quarterly_path, index=False)
    
    print(f"  Saved: {monthly_path}")
    print(f"  Saved: {quarterly_path}")
    
    # -------------------------------------------------------------------------
    # Summary
    # -------------------------------------------------------------------------
    print("\n" + "=" * 70)
    print("EXTRACTION COMPLETE")
    print("=" * 70)
    print(f"Date range: {monthly['year_month'].min()} to {monthly['year_month'].max()}")
    print(f"Monthly observations: {len(monthly)}")
    print(f"Quarterly observations: {len(quarterly)}")
    
    print("\nSample monthly data (first 5 rows):")
    print(monthly.head().to_string(index=False))
    
    print("\nSample monthly data (last 5 rows):")
    print(monthly.tail().to_string(index=False))
    
    print("\nVariables:")
    print("  - n_tenders: Number of unique tenders")
    print("  - n_lots: Number of lots awarded")
    print("  - total_value: Total awarded value (EUR)")
    print("  - avg_lot_price: Mean winning lot price (EUR)")
    print("  - median_lot_price: Median winning lot price (EUR)")
    print("  - avg_bids: Average bids per lot")
    print("  - avg_valid_bids: Average valid bids per lot")
    print("  - n_lots_one_bid: Count of one-bid lots")
    print("  - share_one_bid: Share of lots with exactly 1 bid")
    
    return monthly, quarterly


if __name__ == "__main__":
    monthly, quarterly = extract_time_series()
