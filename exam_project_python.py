# ==============================================================================
# EUROPEAN PUBLIC PROCUREMENT ANALYSIS - FURNITURE SECTOR (CPV 391)
# ==============================================================================
# 
# PROJECT OVERVIEW:
# Analysis of European public tenders in the furniture sector (2022 data).
# The study examines bid price distributions, market competition levels,
# procurement procedure types, and geographical patterns across EU countries.
#
# DATA SOURCE: EU Open Data Portal - Public Procurement Dataset
# SECTOR: Furniture (CPV code 391*)
# YEAR: 2022
#
# STRUCTURE:
# 1. Setup & Data Loading
# 2. Data Cleaning & Filtering
# 3. Price Distribution Analysis
# 4. Competition Analysis (Bids per Lot)
# 5. Procedure Type Analysis
# 6. Geographical Analysis
# ==============================================================================

# ==============================================================================
# 1. SETUP & DATA LOADING
# ==============================================================================

# Import required modules
# pandas: data manipulation (similar to dplyr in R)
# matplotlib.pyplot: plotting (similar to base R plots)
# numpy: numerical operations
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

# Set display options for pandas
# pd.set_option() changes global display settings
# 'display.max_columns', None: show all columns when printing DataFrames
pd.set_option('display.max_columns', None)
pd.set_option('display.float_format', '{:.2f}'.format)  # Format floats to 2 decimals

# Define columns for analysis
# List comprehension: creates a list of column names to load
selected_cols = [
    "tender_id",
    "tender_mainCpv",
    "tender_country",
    "tender_size",
    "tender_procedureType",
    "buyer_buyerType",
    "lot_lotId",
    "bid_row_nr",
    "bid_price_EUR",
    "publication_row_nr",
    "bid_isWinning"
]
dtype_dict = {
    "tender_id": str,
    "tender_mainCpv": str,
    "tender_country": str,
    "tender_size": str,
    "tender_procedureType": str,
    "buyer_buyerType": str,
    "lot_lotId": str,
    "bid_row_nr": str,
    "bid_price_EUR": str,
    "publication_row_nr": float,  
    "bid_isWinning": str
}
# Load 2022 data
# pd.read_csv(): reads CSV file into DataFrame
# sep=';': European CSV format uses semicolon as separator
# usecols: load only specified columns (saves memory)
# dtype=str: load all as strings first to avoid parsing errors
print("Loading data...")
raw_data = pd.read_csv(
    "/Users/vittoriovissani/Documents/Computing fundamentals/workspace esame/data-all-csv/data-all-2022.csv",
    sep=';',
    usecols=selected_cols,
    dtype=dtype_dict
)
print(f"Total rows loaded: {len(raw_data)}")

# ==============================================================================
# 2. DATA CLEANING & FILTERING
# ==============================================================================

# Filter furniture sector (CPV 391*)
furniture_data = raw_data[raw_data['tender_mainCpv'].str.startswith('391', na=False)]
print(f"Rows after furniture filter: {len(furniture_data)}")

# Convert publication_row_nr to numeric for comparison
# pd.to_numeric(): converts string to number
# errors='coerce': invalid values become NaN instead of raising error
furniture_data = furniture_data.copy()  # Avoid SettingWithCopyWarning
furniture_data['publication_row_nr'] = pd.to_numeric(furniture_data['publication_row_nr'], errors='coerce')

# Keep latest publication per tender
# .groupby().transform(): applies function within each group
# .idxmax(): returns index of maximum value
furniture_data = furniture_data.loc[
    furniture_data.groupby('tender_id')['publication_row_nr'].idxmax()
]
print(f"Rows after deduplication: {len(furniture_data)}")

# Create unique bids dataset
# .dropna(subset=[]): removes rows where specified columns are NaN
# .drop_duplicates(): removes duplicate rows based on specified columns
unique_bids = furniture_data.dropna(subset=['bid_row_nr'])
unique_bids = unique_bids.drop_duplicates(subset=['tender_id', 'lot_lotId', 'bid_row_nr'])
print(f"Unique bids: {len(unique_bids)}")

# Convert price to numeric
# .astype(str).str.replace(): converts to string first, then replaces comma with dot
unique_bids = unique_bids.copy()
unique_bids['bid_price_EUR'] = unique_bids['bid_price_EUR'].astype(str).str.replace(',', '.', regex=False)
unique_bids['bid_price_EUR'] = pd.to_numeric(unique_bids['bid_price_EUR'], errors='coerce')

# Filter valid prices
# Boolean indexing with multiple conditions using & (and)
# Each condition must be in parentheses
valid_prices = unique_bids[
    (unique_bids['bid_price_EUR'].notna()) &
    (unique_bids['bid_price_EUR'] > 0) &
    (unique_bids['bid_price_EUR'] < 5000000)
]
print(f"Valid price records: {len(valid_prices)}\n")

# ==============================================================================
# 3. PRICE DISTRIBUTION ANALYSIS
# ==============================================================================

# Summary statistics
# .describe(): generates descriptive statistics (count, mean, std, min, quartiles, max)
# Similar to summary() in R
print("Price Summary Statistics:")
print(valid_prices['bid_price_EUR'].describe())
print()

# Histogram: Bid price distribution
# plt.figure(): creates new figure with specified size
# plt.hist(): creates histogram
# bins: number of bars
# edgecolor: border color of bars
plt.figure(figsize=(10, 6))
price_under_100k = valid_prices[valid_prices['bid_price_EUR'] < 100000]['bid_price_EUR']
plt.hist(price_under_100k, bins=30, color='steelblue', edgecolor='white')
plt.title('Bid Price Distribution\nFurniture Sector - Bids < 100,000 EUR')
plt.xlabel('Bid Price (EUR)')
plt.ylabel('Frequency')
plt.tight_layout()

# Boxplot: Overall price distribution
# plt.boxplot(): creates boxplot
# vert=False: horizontal boxplot (similar to coord_flip() in ggplot2)
plt.figure(figsize=(10, 4))
price_under_500k = valid_prices[valid_prices['bid_price_EUR'] < 500000]['bid_price_EUR']
plt.boxplot(price_under_500k.dropna(), vert=False, patch_artist=True,
            boxprops=dict(facecolor='lightblue', color='darkblue'))
plt.title('Bid Price Boxplot\nFurniture Sector 2022')
plt.xlabel('Bid Price (EUR)')
plt.tight_layout()

# Boxplot: Prices by tender size
# .groupby(): groups data by category
# Similar to group_by() in dplyr
size_data = valid_prices[valid_prices['tender_size'].notna()]
size_data_filtered = size_data[size_data['bid_price_EUR'] < 100000]

# Prepare data for grouped boxplot
# Create list of arrays, one for each category
size_groups = size_data_filtered.groupby('tender_size')['bid_price_EUR']
size_labels = list(size_groups.groups.keys())
size_values = [group.dropna().values for name, group in size_groups]

plt.figure(figsize=(10, 6))
bp = plt.boxplot(size_values, patch_artist=True)
plt.xticks(range(1, len(size_labels) + 1), size_labels)
# Assign different colors to each box
colors = ['lightblue', 'lightgreen', 'lightyellow']
for patch, color in zip(bp['boxes'], colors[:len(bp['boxes'])]):
    patch.set_facecolor(color)
plt.title('Price Distribution by Tender Size\nFurniture Sector 2022')
plt.xlabel('Tender Size')
plt.ylabel('Bid Price (EUR)')
plt.tight_layout()
plt.savefig('price_by_size.png', dpi=150)

# ==============================================================================
# 4. COMPETITION ANALYSIS (BIDS PER LOT)
# ==============================================================================

# Calculate bids per lot
# .nunique(): counts unique values (similar to n_distinct() in dplyr)
furniture_data_clean = furniture_data.copy()
furniture_data_clean['bid_row_nr'] = pd.to_numeric(furniture_data_clean['bid_row_nr'], errors='coerce')

competition = furniture_data_clean.dropna(subset=['lot_lotId', 'bid_row_nr'])
competition = competition.drop_duplicates(subset=['lot_lotId', 'bid_row_nr'])
competition = competition.groupby(['tender_id', 'lot_lotId']).agg(
    n_bids=('bid_row_nr', 'nunique')
).reset_index()

print("Competition Statistics (Bids per Lot):")
print(competition['n_bids'].describe())
print("\nBids per lot distribution:")
print(competition['n_bids'].value_counts().sort_index())

# Bar chart: Bids per lot distribution
# .value_counts(): counts occurrences of each value
# Similar to table() in R
competition_filtered = competition[competition['n_bids'] <= 15]
bids_counts = competition_filtered['n_bids'].value_counts().sort_index()

plt.figure(figsize=(10, 6))
plt.bar(bids_counts.index.astype(str), bids_counts.values, color='coral', edgecolor='darkred')
plt.title('Number of Bids per Lot\nCompetition Level in Furniture Tenders')
plt.xlabel('Number of Bids')
plt.ylabel('Lot Count')
plt.tight_layout()

# Winning bids summary
bids_summary = furniture_data.drop_duplicates(subset=['lot_lotId', 'bid_row_nr'])
print("\nWinning bids distribution:")
print(bids_summary['bid_isWinning'].value_counts())

# ==============================================================================
# 5. PROCEDURE TYPE ANALYSIS
# ==============================================================================

print("\nProcedure type distribution:")
print(valid_prices['tender_procedureType'].value_counts())

# Statistics by procedure type
# .agg(): applies multiple aggregation functions
# Similar to summarise() in dplyr
proc_data = valid_prices[valid_prices['tender_procedureType'].notna()]

proc_stats = proc_data.groupby('tender_procedureType').agg(
    n=('bid_price_EUR', 'count'),
    mean_price=('bid_price_EUR', 'mean'),
    median_price=('bid_price_EUR', 'median')
).round(0)

# Filter procedures with at least 50 observations
proc_stats = proc_stats[proc_stats['n'] >= 50].sort_values('n', ascending=False)
print("\nStatistics by procedure type:")
print(proc_stats)

# Boxplot: Prices by procedure type
main_procedures = ['OPEN', 'OTHER', 'APPROACHING_BIDDERS', 'MINITENDER']
proc_filtered = proc_data[proc_data['tender_procedureType'].isin(main_procedures)]
proc_filtered = proc_filtered[proc_filtered['bid_price_EUR'] > 5000]

# Grouped boxplot for procedures
proc_groups = proc_filtered.groupby('tender_procedureType')['bid_price_EUR']
proc_labels = [p for p in main_procedures if p in proc_groups.groups]
proc_values = [proc_groups.get_group(p).dropna().values for p in proc_labels]

plt.figure(figsize=(10, 6))
bp = plt.boxplot(proc_values, patch_artist=True)
plt.xticks(range(1, len(proc_labels) + 1), proc_labels)
colors = ['#66c2a5', '#fc8d62', '#8da0cb', '#e78ac3']
for patch, color in zip(bp['boxes'], colors[:len(bp['boxes'])]):
    patch.set_facecolor(color)
plt.yscale('log')  # Log scale similar to scale_y_log10() in ggplot2
plt.title('Price Distribution by Procedure Type\nLog Scale - Furniture Sector 2022')
plt.xlabel('Procedure Type')
plt.ylabel('Bid Price (EUR)')
plt.tight_layout()

# Bar chart: Lots by procedure type
proc_lots = proc_data.drop_duplicates(subset=['lot_lotId'])
proc_lot_counts = proc_lots['tender_procedureType'].value_counts().head(10)

plt.figure(figsize=(10, 6))
# .barh(): horizontal bar chart
plt.barh(proc_lot_counts.index[::-1], proc_lot_counts.values[::-1], color='steelblue')
plt.title('Number of Lots by Procedure Type\nTop 10 Procedures - Furniture Sector')
plt.xlabel('Number of Lots')
plt.ylabel('Procedure Type')
plt.tight_layout()

# ==============================================================================
# 6. GEOGRAPHICAL ANALYSIS
# ==============================================================================

# Bar chart: Tenders by country (Top 10)
country_data = furniture_data[furniture_data['tender_country'].notna()]
country_tenders = country_data.drop_duplicates(subset=['tender_id'])
country_counts = country_tenders['tender_country'].value_counts().head(10)

plt.figure(figsize=(10, 6))
plt.barh(country_counts.index[::-1], country_counts.values[::-1], color='steelblue')
plt.title('Number of Tenders by Country\nTop 10 Countries - Furniture Sector')
plt.xlabel('Number of Tenders')
plt.ylabel('Country')
plt.tight_layout()

# Scatter plot: Lots vs Total Value by country
furniture_data_price = furniture_data.copy()
furniture_data_price['bid_price_EUR'] = furniture_data_price['bid_price_EUR'].astype(str).str.replace(',', '.', regex=False)
furniture_data_price['bid_price_EUR'] = pd.to_numeric(furniture_data_price['bid_price_EUR'], errors='coerce')

winning_bids = furniture_data_price[
    (furniture_data_price['bid_isWinning'] == 'yes') &
    (furniture_data_price['bid_price_EUR'].notna())
]
winning_bids = winning_bids.drop_duplicates(subset=['lot_lotId', 'bid_row_nr'])

country_market = winning_bids.groupby('tender_country').agg(
    n_lots=('lot_lotId', 'count'),
    total_value=('bid_price_EUR', 'sum')
).reset_index()

country_market_top = country_market.nlargest(10, 'n_lots')

plt.figure(figsize=(10, 8))
# plt.scatter(): creates scatter plot
# s: size of points, c: colors
scatter = plt.scatter(
    country_market_top['n_lots'],
    country_market_top['total_value'],
    s=country_market_top['total_value'] / 1e6,  # Scale size
    c=range(len(country_market_top)),
    cmap='tab10',
    alpha=0.7
)
plt.xscale('log')
plt.yscale('log')

# Add country labels to points
for idx, row in country_market_top.iterrows():
    plt.annotate(row['tender_country'], (row['n_lots'], row['total_value']),
                 xytext=(5, 5), textcoords='offset points', fontsize=9)

plt.title('Market Size by Country\nWinning Bids - Lots vs Total Value')
plt.xlabel('Number of Lots')
plt.ylabel('Total Value (EUR)')
plt.tight_layout()

# Boxplot: Prices by country
country_prices = furniture_data_price[
    (furniture_data_price['bid_price_EUR'].notna()) &
    (furniture_data_price['bid_price_EUR'] < 100000) &
    (furniture_data_price['bid_price_EUR'] > 0)
]

# Get top 10 countries by number of bids for boxplot
top_countries = country_prices['tender_country'].value_counts().head(10).index.tolist()
country_prices_top = country_prices[country_prices['tender_country'].isin(top_countries)]

country_groups = country_prices_top.groupby('tender_country')['bid_price_EUR']
country_labels = top_countries
country_values = [country_groups.get_group(c).dropna().values for c in country_labels if c in country_groups.groups]
country_labels = [c for c in country_labels if c in country_groups.groups]

plt.figure(figsize=(12, 6))
bp = plt.boxplot(country_values, patch_artist=True)
plt.xticks(range(1, len(country_labels) + 1), country_labels, rotation=45)
plt.title('Price Distribution by Country\nFurniture Sector - Bids < 100,000 EUR (Top 10 Countries)')
plt.xlabel('Country')
plt.ylabel('Bid Price (EUR)')
plt.tight_layout()

print("\n" + "="*60)
print("ANALYSIS COMPLETE")
print("="*60)

# Keep all plot windows open at the end
# plt.ioff(): turn off interactive mode
# plt.show(): display all figures and wait (blocking call at the end only)
plt.ioff()
plt.show()
