# EUROPEAN PUBLIC PROCUREMENT ANALYSIS - FURNITURE SECTOR

# Analysis of European public tenders in the furniture sector (2022 data).

# DATA SOURCE: EU Open Data Portal - Public Procurement Dataset)

# STRUCTURE:
# Setup and Data Loading
# Data Cleaning and Filtering
# Price Distribution Analysis
# Competition Analysis (Bids per Lot)
# Procedure Type Analysis
# Geographical Analysis

#SETUP AND DATA LOADING

import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

pd.set_option('display.max_columns', None)
pd.set_option('display.max_rows', None)

# Define columns for analysis
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

# Load 2022 data
print("Loading data...")
raw_data = pd.read_csv(
    "/Users/vittoriovissani/Documents/Computing fundamentals/workspace esame/data-all-csv/data-all-2022.csv",
    sep=';',
    usecols=selected_cols,
    dtype=str
)
print("Total rows loaded:", len(raw_data))

# DATA CLEANING & FILTERING

# Filter furniture sector (CPV 391*)
furniture_data = raw_data[raw_data['tender_mainCpv'].str.startswith('391', na=False)]
print("Rows after furniture filter:", len(furniture_data))

# Convert publication_row_nr to numeric
furniture_data = furniture_data.copy()
furniture_data['publication_row_nr'] = pd.to_numeric(furniture_data['publication_row_nr'], errors='coerce')

# Keep latest publication per tender
furniture_data = furniture_data.sort_values('publication_row_nr').drop_duplicates(
    subset=['tender_id'], keep='last')
print("Rows after deduplication:", len(furniture_data))

# Create unique bids dataset
unique_bids = furniture_data[furniture_data['bid_row_nr'].notna()]
unique_bids = unique_bids.drop_duplicates(subset=['tender_id', 'lot_lotId', 'bid_row_nr'])
print("Unique bids:", len(unique_bids))

# Convert price to numeric
unique_bids = unique_bids.copy()
unique_bids['bid_price_EUR'] = unique_bids['bid_price_EUR'].str.replace(',', '.', regex=False)
unique_bids['bid_price_EUR'] = pd.to_numeric(unique_bids['bid_price_EUR'], errors='coerce')

# Filter valid prices
valid_prices = unique_bids[
    (unique_bids['bid_price_EUR'].notna()) &
    (unique_bids['bid_price_EUR'] > 0) &
    (unique_bids['bid_price_EUR'] < 5000000)]
print("Valid price records:", len(valid_prices))
print()
print("Unique tenders:", valid_prices['tender_id'].nunique())
print("Unique lots:", valid_prices['lot_lotId'].nunique())
print("Unique bids:", len(valid_prices.drop_duplicates(subset=['tender_id', 'lot_lotId', 'bid_row_nr'])))
print()

# PRICE DISTRIBUTION ANALYSIS

# Summary statistics
print("Price Summary Statistics:")
print(valid_prices['bid_price_EUR'].describe())
print()

# Histogram: Bid price distribution
price_under_100k = valid_prices[valid_prices['bid_price_EUR'] < 100000]
plt.hist(price_under_100k['bid_price_EUR'], bins=30, color='steelblue', edgecolor='white')
plt.title('Bid Price Distribution\nFurniture Sector - Bids < 100,000 EUR')
plt.xlabel('Bid Price (EUR)')
plt.ylabel('Frequency')
plt.show()

# Boxplot: Overall price distribution
price_under_500k = valid_prices[valid_prices['bid_price_EUR'] < 500000]
plt.boxplot(price_under_500k['bid_price_EUR'].dropna(), vert=False)
plt.title('Bid Price Boxplot\nFurniture Sector 2022')
plt.xlabel('Bid Price (EUR)')
plt.show()

# Boxplot: Prices distribution by tender size
size_data = valid_prices[valid_prices['tender_size'].notna()]
size_data[['bid_price_EUR', 'tender_size']].boxplot(by='tender_size')
plt.ylim(0, 100000)
plt.suptitle('Price Distribution by Tender Size\nFurniture Sector 2022')
plt.xlabel('Tender Size')
plt.ylabel('Bid Price (EUR)')
plt.show()

# COMPETITION ANALYSIS (BIDS PER LOT)

# Calculate bids per lot
competition = furniture_data.drop_duplicates(subset=['tender_id', 'lot_lotId', 'bid_row_nr'])
competition = competition[competition['lot_lotId'].notna()]
competition = competition.groupby(['tender_id', 'lot_lotId']).agg(
    n_bids=('bid_row_nr', 'nunique')).reset_index()

print("Competition Statistics (Bids per Lot):")
print(competition['n_bids'].describe())
print()
print("Bids per lot distribution:")
print(competition['n_bids'].value_counts().sort_index())

# Bar chart: Bids per lot distribution
competition_filtered = competition[competition['n_bids'] <= 15]
bids_counts = competition_filtered['n_bids'].value_counts().sort_index()
plt.bar(bids_counts.index.astype(str), bids_counts.values, color='coral', edgecolor='darkred')
plt.yscale('log')
plt.title('Number of Bids per Lot\nCompetition Level in Furniture Tenders')
plt.xlabel('Number of Bids')
plt.ylabel('Lot Count')
plt.show()

# Winning bids summary
bids_summary = furniture_data.drop_duplicates(subset=['tender_id', 'lot_lotId', 'bid_row_nr'])
print("\nWinning bids distribution:")
print(bids_summary['bid_isWinning'].value_counts())

# PROCEDURE TYPE ANALYSIS

# Statistics by procedure type
proc_data = valid_prices[valid_prices['tender_procedureType'].notna()]
proc_data = proc_data.drop_duplicates(subset=['tender_id'])

proc_stats = proc_data.groupby('tender_procedureType').agg(
    n=('bid_price_EUR', 'count'),
    mean_price=('bid_price_EUR', 'mean'),
    median_price=('bid_price_EUR', 'median')).round(0)
proc_stats = proc_stats[proc_stats['n'] >= 50].sort_values('n', ascending=False)
print("\nStatistics by procedure type:")
print(proc_stats)

# Boxplot: Prices by procedure type
main_procedures = proc_stats.index.tolist()

# Bar chart: Lots by procedure type
proc_lots = proc_data.drop_duplicates(subset=['lot_lotId'])
proc_lot_counts = proc_lots.groupby('tender_procedureType').size().sort_values(ascending=False).head(10)
plt.barh(proc_lot_counts.index[::-1], proc_lot_counts.values[::-1], color='steelblue')
plt.title('Number of Lots by Procedure Type\nTop 10 Procedures - Furniture Sector')
plt.xlabel('Number of Lots')
plt.ylabel('Procedure Type')
plt.show()

proc_filtered = proc_data[proc_data['tender_procedureType'].isin(main_procedures)]
proc_filtered[['bid_price_EUR', 'tender_procedureType']].boxplot(by='tender_procedureType')
plt.ylim(0, 100000)
plt.suptitle('Price Distribution by Procedure Type\nFurniture Sector 2022')
plt.xlabel('Procedure Type')
plt.ylabel('Bid Price (EUR)')
plt.xticks(rotation=45)
plt.show()

# GEOGRAPHICAL ANALYSIS

# Bar chart: Top countries by number of tenders
country_data = furniture_data[furniture_data['tender_country'].notna()]
country_tenders = country_data.drop_duplicates(subset=['tender_id'])
country_counts = country_tenders.groupby('tender_country').size().sort_values(ascending=False).head(10)
plt.barh(country_counts.index[::-1], country_counts.values[::-1], color='steelblue')
plt.title('Number of Tenders by Country\nTop 10 Countries - Furniture Sector')
plt.xlabel('Number of Tenders')
plt.ylabel('Country')
plt.show()

# Boxplot: Prices by country
furniture_data_price = furniture_data.copy()
furniture_data_price['bid_price_EUR'] = furniture_data_price['bid_price_EUR'].str.replace(',', '.', regex=False)
furniture_data_price['bid_price_EUR'] = pd.to_numeric(furniture_data_price['bid_price_EUR'], errors='coerce')
country_prices = furniture_data_price[furniture_data_price['bid_price_EUR'] < 100000]
country_prices[['bid_price_EUR', 'tender_country']].boxplot(by='tender_country')
plt.suptitle('Price Distribution by Country\nFurniture Sector - Bids < 100,000 EUR')
plt.xlabel('Country')
plt.ylabel('Bid Price (EUR)')
plt.xticks(rotation=45)
plt.show()
