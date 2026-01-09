# ==============================================================================
# TIME SERIES DATA EXTRACTION FOR GRETL PROJECT
# ==============================================================================
# 
# Efficiently extracts time series data from EU procurement CSVs (2009-2024)
# for furniture sector (CPV 391*) to create monthly aggregates for Gretl analysis
#
# OUTPUT: Monthly time series suitable for regression/forecasting
# ==============================================================================

import pandas as pd
import os
from glob import glob

# NOTE ON DEDUPLICATION AND DATES
# The raw procurement dataset can contain multiple publications of the same tender.
# For time-series analysis we must avoid double-counting the same tender/lot across
# publications. We therefore (a) keep the latest publication per tender_id,
# and (b) aggregate at the lot-award level (one winning observation per lot).
#
# Date choice: we prefer award dates when available (awardDecisionDate, then
# contractSignatureDate, then lastContractAwardDate) to represent when outcomes
# (winning bids/prices) materialize.

# Data directory
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

    event_date = d1
    event_date = event_date.fillna(d2)
    event_date = event_date.fillna(d3)
    return event_date


def dedup_latest_publication(df: pd.DataFrame) -> pd.DataFrame:
    """Keep latest publication_row_nr per tender_id to avoid double counting."""

    if df.empty:
        return df

    out = df.copy()
    out["publication_row_nr"] = pd.to_numeric(out["publication_row_nr"], errors="coerce")
    # If publication_row_nr missing, we can't rank reliably; keep rows as-is.
    if out["publication_row_nr"].notna().any():
        out = out.sort_values(["tender_id", "publication_row_nr"])  # stable for group tail
        out = out.groupby("tender_id", as_index=False).tail(1)
    return out


def to_numeric_price(s: pd.Series) -> pd.Series:
    return pd.to_numeric(s.astype(str).str.replace(",", ".", regex=False), errors="coerce")

def process_year_file(filepath, year):
    """Process a single year file in chunks to extract furniture sector data."""
    print(f"Processing {year}...")
    
    chunks = []
    chunk_size = 500000  # Process 500k rows at a time
    
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
                print(f"  Found {len(furniture_chunk)} furniture rows in chunk")
    
    except Exception as e:
        print(f"  Error processing {year}: {e}")
        return pd.DataFrame()
    
    if chunks:
        result = pd.concat(chunks, ignore_index=True)
        print(f"  Total furniture rows for {year}: {len(result)}")
        return result
    else:
        print(f"  No furniture data found for {year}")
        return pd.DataFrame()

def aggregate_monthly(df):
    """Aggregate data to monthly time series."""

    if df.empty:
        return pd.DataFrame()

    # 1) Avoid duplicate counting from multiple publications
    df = dedup_latest_publication(df)

    # 2) Choose most suitable event date
    df = df.copy()
    df["event_date"] = choose_event_date(df)
    df = df[df["event_date"].notna()].copy()

    # 3) Create year-month
    df["year_month"] = df["event_date"].dt.to_period("M")

    # 4) Convert fields
    df["bid_price_EUR"] = to_numeric_price(df["bid_price_EUR"])
    df["lot_bidsCount"] = pd.to_numeric(df["lot_bidsCount"], errors="coerce")
    df["lot_validBidsCount"] = pd.to_numeric(df["lot_validBidsCount"], errors="coerce")

    # 5) Define the unit of analysis for value: one winning observation per lot
    #    - Using bid_isWinning avoids counting all bids.
    #    - Dropping duplicates on (tender_id, lot_lotId) prevents double-counting
    #      if the exported data still contains multiple rows per lot.
    winners = df[df["bid_isWinning"] == "yes"].copy()
    winners = winners.dropna(subset=["tender_id", "lot_lotId"])
    winners = winners.drop_duplicates(subset=["tender_id", "lot_lotId"], keep="first")

    # Filter out non-sensical prices (keep generous upper bound)
    winners = winners[(winners["bid_price_EUR"].notna()) & (winners["bid_price_EUR"] > 0) & (winners["bid_price_EUR"] < 5_000_000_000)]

    # Monthly aggregates (meaningful time-series metrics)
    monthly = winners.groupby("year_month").agg(
        n_tenders=("tender_id", "nunique"),
        n_lots=("lot_lotId", "nunique"),
        total_value=("bid_price_EUR", "sum"),
        avg_lot_price=("bid_price_EUR", "mean"),
        median_lot_price=("bid_price_EUR", "median"),
        avg_bids=("lot_bidsCount", "mean"),
        avg_valid_bids=("lot_validBidsCount", "mean"),
    ).reset_index()

    return monthly

def main():
    # Quick mode: set TS_YEAR=2022 (or any year) in your environment to process just one file.
    quick_year = os.environ.get("TS_YEAR")

    print("="*60)
    print("EXTRACTING TIME SERIES DATA FOR FURNITURE SECTOR (CPV 391)")
    print("="*60)
    
    # Find all year files
    files = sorted(glob(os.path.join(DATA_DIR, "data-all-20*.csv")))
    print(f"\nFound {len(files)} data files")
    
    # Process each year
    all_data = []
    for filepath in files:
        year = os.path.basename(filepath).replace("data-all-", "").replace(".csv", "")
        if year.isdigit():  # Skip non-year files
            if quick_year and year != quick_year:
                continue
            year_data = process_year_file(filepath, year)
            if len(year_data) > 0:
                all_data.append(year_data)
    
    if not all_data:
        print("No data found!")
        return
    
    # Combine all years
    print("\nCombining all years...")
    combined = pd.concat(all_data, ignore_index=True)
    print(f"Total furniture records: {len(combined)}")

    # ----------------------------------------------------------------------
    # Sanity checks on duplicates + date availability
    # ----------------------------------------------------------------------
    print("\nSanity checks (before dedup):")
    n_rows = len(combined)
    n_tenders = combined["tender_id"].nunique(dropna=True)
    n_lots = combined["lot_lotId"].nunique(dropna=True)
    print(f"  Raw rows: {n_rows}")
    print(f"  Unique tenders: {n_tenders}")
    print(f"  Unique lots: {n_lots}")

    # How many repeated tender_ids (publication duplicates likely)
    dup_tender_rows = n_rows - combined.drop_duplicates(subset=["tender_id"]).shape[0]
    print(f"  Rows beyond first occurrence of tender_id: {dup_tender_rows}")
    
    # Date coverage
    d_award = pd.to_datetime(combined.get("tender_awardDecisionDate"), errors="coerce")
    d_sign = pd.to_datetime(combined.get("tender_contractSignatureDate"), errors="coerce")
    d_last_aw = pd.to_datetime(combined.get("tender_publications_lastContractAwardDate"), errors="coerce")
    print("  Date coverage (non-missing counts):")
    print(f"    tender_awardDecisionDate: {d_award.notna().sum()}")
    print(f"    tender_contractSignatureDate: {d_sign.notna().sum()}")
    print(f"    tender_publications_lastContractAwardDate: {d_last_aw.notna().sum()}")
    
    # Create monthly aggregates
    print("\nCreating monthly aggregates...")
    monthly_ts = aggregate_monthly(combined)
    
    # Sort by date
    monthly_ts = monthly_ts.sort_values('year_month')
    
    # Convert period to string for export
    monthly_ts['year_month'] = monthly_ts['year_month'].astype(str)
    
    print(f"\nMonthly time series created: {len(monthly_ts)} observations")
    print(monthly_ts.head(10))
    print("...")
    print(monthly_ts.tail(10))
    
    # Save to CSV for Gretl
    output_path = os.path.join(OUTPUT_DIR, "furniture_monthly_ts.csv")
    monthly_ts.to_csv(output_path, index=False)
    print(f"\nSaved to: {output_path}")
    
    # Also create quarterly aggregates (better for regression)
    print("\nCreating quarterly aggregates...")
    combined_q = combined.copy()
    combined_q = dedup_latest_publication(combined_q)
    combined_q = combined_q.copy()
    combined_q["event_date"] = choose_event_date(combined_q)
    combined_q = combined_q[combined_q["event_date"].notna()].copy()
    combined_q["year_quarter"] = combined_q["event_date"].dt.to_period("Q")
    combined_q["bid_price_EUR"] = to_numeric_price(combined_q["bid_price_EUR"])
    combined_q["lot_bidsCount"] = pd.to_numeric(combined_q["lot_bidsCount"], errors="coerce")
    combined_q["lot_validBidsCount"] = pd.to_numeric(combined_q["lot_validBidsCount"], errors="coerce")

    winners_q = combined_q[combined_q["bid_isWinning"] == "yes"].copy()
    winners_q = winners_q.dropna(subset=["tender_id", "lot_lotId"])
    winners_q = winners_q.drop_duplicates(subset=["tender_id", "lot_lotId"], keep="first")
    winners_q = winners_q[(winners_q["bid_price_EUR"].notna()) & (winners_q["bid_price_EUR"] > 0) & (winners_q["bid_price_EUR"] < 5_000_000_000)]

    quarterly = winners_q.groupby("year_quarter").agg(
        n_tenders=("tender_id", "nunique"),
        n_lots=("lot_lotId", "nunique"),
        total_value=("bid_price_EUR", "sum"),
        avg_lot_price=("bid_price_EUR", "mean"),
        median_lot_price=("bid_price_EUR", "median"),
        avg_bids=("lot_bidsCount", "mean"),
        avg_valid_bids=("lot_validBidsCount", "mean"),
    ).reset_index()
    quarterly = quarterly.sort_values("year_quarter")
    quarterly["year_quarter"] = quarterly["year_quarter"].astype(str)
    
    output_q = os.path.join(OUTPUT_DIR, "furniture_quarterly_ts.csv")
    quarterly.to_csv(output_q, index=False)
    print(f"Quarterly data saved to: {output_q}")
    print(f"Quarterly observations: {len(quarterly)}")
    
    # Summary statistics
    print("\n" + "="*60)
    print("SUMMARY STATISTICS")
    print("="*60)
    print(f"Date range: {monthly_ts['year_month'].min()} to {monthly_ts['year_month'].max()}")
    print(f"Monthly observations: {len(monthly_ts)}")
    print(f"Quarterly observations: {len(quarterly)}")
    print(f"\nVariables available for Gretl analysis:")
    print("  - n_tenders: Number of unique tenders awarded (proxy)")
    print("  - n_lots: Number of lots awarded")
    print("  - total_value: Total awarded value (sum of winning lot prices, EUR)")
    print("  - avg_lot_price: Mean winning lot price (EUR)")
    print("  - median_lot_price: Median winning lot price (EUR)")
    print("  - avg_bids: Average total bids per lot (competition)")
    print("  - avg_valid_bids: Average valid bids per lot")

if __name__ == "__main__":
    main()
