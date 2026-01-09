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

# Data directory
DATA_DIR = "/Users/vittoriovissani/Documents/Computing fundamentals/workspace esame/data-all-csv"
OUTPUT_DIR = "/Users/vittoriovissani/Documents/Computing fundamentals/workspace esame/repository"

# Columns needed for time series analysis
COLS_TO_LOAD = [
    "tender_id",
    "tender_mainCpv",
    "tender_country",
    "tender_awardDecisionDate",
    "tender_procedureType",
    "tender_size",
    "lot_lotId",
    "lot_bidsCount",
    "lot_validBidsCount",
    "bid_row_nr",
    "bid_price_EUR",
    "bid_isWinning",
    "publication_row_nr"
]

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
    
    # Convert date column
    df['tender_awardDecisionDate'] = pd.to_datetime(
        df['tender_awardDecisionDate'], 
        errors='coerce'
    )
    
    # Filter rows with valid dates
    df_dated = df[df['tender_awardDecisionDate'].notna()].copy()
    
    # Create year-month column
    df_dated['year_month'] = df_dated['tender_awardDecisionDate'].dt.to_period('M')
    
    # Convert price to numeric
    df_dated['bid_price_EUR'] = df_dated['bid_price_EUR'].astype(str).str.replace(',', '.', regex=False)
    df_dated['bid_price_EUR'] = pd.to_numeric(df_dated['bid_price_EUR'], errors='coerce')
    
    # Convert bids count to numeric
    df_dated['lot_bidsCount'] = pd.to_numeric(df_dated['lot_bidsCount'], errors='coerce')
    df_dated['lot_validBidsCount'] = pd.to_numeric(df_dated['lot_validBidsCount'], errors='coerce')
    
    # Get unique winning bids per lot for aggregation
    winning_bids = df_dated[df_dated['bid_isWinning'] == 'yes'].drop_duplicates(
        subset=['tender_id', 'lot_lotId', 'bid_row_nr']
    )
    
    # Monthly aggregates
    monthly = winning_bids.groupby('year_month').agg(
        n_contracts=('tender_id', 'nunique'),       # Number of contracts awarded
        n_lots=('lot_lotId', 'nunique'),            # Number of lots
        total_value=('bid_price_EUR', 'sum'),       # Total contract value
        avg_price=('bid_price_EUR', 'mean'),        # Average contract price
        median_price=('bid_price_EUR', 'median'),   # Median contract price
        avg_bids=('lot_bidsCount', 'mean'),         # Average bids per lot
        max_price=('bid_price_EUR', 'max'),         # Maximum price
        min_price=('bid_price_EUR', 'min')          # Minimum price
    ).reset_index()
    
    return monthly

def main():
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
    combined_dated = combined.copy()
    combined_dated['tender_awardDecisionDate'] = pd.to_datetime(
        combined_dated['tender_awardDecisionDate'], errors='coerce'
    )
    combined_dated = combined_dated[combined_dated['tender_awardDecisionDate'].notna()]
    combined_dated['year_quarter'] = combined_dated['tender_awardDecisionDate'].dt.to_period('Q')
    combined_dated['bid_price_EUR'] = combined_dated['bid_price_EUR'].astype(str).str.replace(',', '.', regex=False)
    combined_dated['bid_price_EUR'] = pd.to_numeric(combined_dated['bid_price_EUR'], errors='coerce')
    combined_dated['lot_bidsCount'] = pd.to_numeric(combined_dated['lot_bidsCount'], errors='coerce')
    
    winning_q = combined_dated[combined_dated['bid_isWinning'] == 'yes'].drop_duplicates(
        subset=['tender_id', 'lot_lotId', 'bid_row_nr']
    )
    
    quarterly = winning_q.groupby('year_quarter').agg(
        n_contracts=('tender_id', 'nunique'),
        n_lots=('lot_lotId', 'nunique'),
        total_value=('bid_price_EUR', 'sum'),
        avg_price=('bid_price_EUR', 'mean'),
        median_price=('bid_price_EUR', 'median'),
        avg_bids=('lot_bidsCount', 'mean')
    ).reset_index()
    quarterly = quarterly.sort_values('year_quarter')
    quarterly['year_quarter'] = quarterly['year_quarter'].astype(str)
    
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
    print("  - n_contracts: Number of unique contracts awarded")
    print("  - n_lots: Number of lots awarded")
    print("  - total_value: Total value of contracts (EUR)")
    print("  - avg_price: Average contract price (EUR)")
    print("  - median_price: Median contract price (EUR)")
    print("  - avg_bids: Average number of bids per lot (competition)")

if __name__ == "__main__":
    main()
