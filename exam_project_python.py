# EUROPEAN PUBLIC PROCUREMENT ANALYSIS - FURNITURE SECTOR

# Analysis of European public tenders in the furniture sector (2021 data).

# DATA SOURCE: EU Open Data Portal - Public Procurement Dataset)

# STRUCTURE:
# Setup and Data Loading
# Data Cleaning and Filtering
# Price Distribution Analysis
# Competition Analysis (Bids per Lot)
# Procedure Type / Tender Size Analysis
# Geographical Analysis

#SETUP AND DATA LOADING

import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

pd.set_option('display.max_columns', None)
pd.set_option('display.max_rows', None)
pd.set_option('display.float_format', lambda x: '%.2f' % x)

# Define columns for analysis
selected_cols = [
    "tender_id",
    "tender_mainCpv",
    "tender_country",
    "tender_size",
    "tender_procedureType",
    "lot_row_nr",
    "lot_bidsCount",
    "bid_price_EUR",
    "bid_isWinning"
]

# Load 2021 data
print("Loading data...")
raw_data = pd.read_csv(
    "/Users/vittoriovissani/Documents/Computing fundamentals/workspace esame/data-all-csv/data-all-2021.csv",
    sep=';',
    usecols=selected_cols,
    dtype=str
)
print("Total rows loaded:", len(raw_data))

# DATA CLEANING AND FILTERING

# Single cleaning flow: build one dataset of awarded lots, deduplicated and cleaned

# Filter furniture sector (CPV 391*)
furniture_raw = raw_data[raw_data['tender_mainCpv'].str.startswith('391', na=False)]
print("Rows after furniture filter:", len(furniture_raw))

# Keep only winning bids (actual contracts)
furniture_awarded = furniture_raw[furniture_raw['bid_isWinning'] == 'yes']
print("Rows after winning bid filter:", len(furniture_awarded))

# One row per lot (within tender) + basic type cleaning + main filters
furniture_dedup = furniture_awarded.drop_duplicates(subset=['tender_id', 'lot_row_nr'])
print("Unique lots (dedup):", len(furniture_dedup))

furniture_clean = furniture_dedup.copy()
furniture_clean['bid_price_EUR'] = furniture_clean['bid_price_EUR'].str.replace(',', '.', regex=False)
furniture_clean['bid_price_EUR'] = pd.to_numeric(furniture_clean['bid_price_EUR'], errors='coerce')
furniture_clean['lot_bidsCount'] = pd.to_numeric(furniture_clean['lot_bidsCount'], errors='coerce')

furniture_clean = furniture_clean[
    (furniture_clean['bid_price_EUR'].notna()) &
    (furniture_clean['bid_price_EUR'] > 0) &
    (furniture_clean['bid_price_EUR'] < 5000000) &
    (furniture_clean['lot_bidsCount'].notna())
]

print("Lots after price + bidsCount filters:", len(furniture_clean))
print("Unique tenders (clean):", furniture_clean['tender_id'].nunique())
print("Duplicated rows:", furniture_clean.duplicated().sum())

# PRICE DISTRIBUTION ANALYSIS

# Summary statistics
print("\nPrice Summary Statistics:")
print(furniture_clean['bid_price_EUR'].describe())

# Boxplot: Overall price distribution
price_under_500k = furniture_clean[furniture_clean['bid_price_EUR'] < 500000]
plt.figure()
plt.boxplot(price_under_500k['bid_price_EUR'].dropna(), vert=False)
plt.title('Bid Price Boxplot\nFurniture Sector 2021')
plt.xlabel('Bid Price (EUR)')
plt.show()

# COMPETITION ANALYSIS (BIDS PER LOT)

# Use lot_bidsCount from the dataset (same df used for prices)
print("\nCompetition Summary (lot_bidsCount):")
print(furniture_clean['lot_bidsCount'].describe())

# Bar chart: Bids per lot distribution
competition_filtered = furniture_clean[
    (furniture_clean['lot_bidsCount'] <= 15) &
    (furniture_clean['lot_bidsCount'] > 0)
]
bids_counts = competition_filtered['lot_bidsCount'].value_counts().sort_index()

plt.figure()
plt.bar(bids_counts.index.astype(int).astype(str), bids_counts.values, color='coral', edgecolor='darkred')
plt.title('Number of Bids per Lot\nCompetition Level in Furniture Tenders (from lot_bidsCount)')
plt.xlabel('Number of Bids')
plt.ylabel('Lot Count')
plt.show()

# PROCEDURE TYPE / TENDER SIZE ANALYSIS

# Pie chart of tender size
size_counts = furniture_clean[furniture_clean['tender_size'].notna()].groupby('tender_size').size()

plt.figure()
plt.pie(size_counts.values, labels=size_counts.index, autopct='%1.1f%%')
plt.title('Tender Size Distribution')
plt.show()

# Top procedure types
top_procedures = (furniture_clean[furniture_clean['tender_procedureType'].notna()]
    .groupby('tender_procedureType')
    .size()
    .sort_values(ascending=False)
    .head(5)
    .index.tolist())

# Competition by procedure type (pie charts)
furniture_top_proc = furniture_clean[
    (furniture_clean['tender_procedureType'].notna()) &
    (furniture_clean['tender_procedureType'].isin(top_procedures))
].copy()
furniture_top_proc['competition'] = furniture_top_proc['lot_bidsCount'].apply(
    lambda x: 'one_bid' if x == 1 else 'more'
)

fig, axes = plt.subplots(1, 2, figsize=(12, 5))
for i, comp in enumerate(['one_bid', 'more']):
    subset = furniture_top_proc[furniture_top_proc['competition'] == comp]
    proc_counts = subset.groupby('tender_procedureType').size()
    axes[i].pie(proc_counts.values, labels=proc_counts.index, autopct='%1.1f%%')
    axes[i].set_title(comp)
plt.suptitle('Procedure Type by Competition Level')
plt.show()

# Boxplot: price by competition level
furniture_comp = furniture_clean.copy()
furniture_comp['competition'] = furniture_comp['lot_bidsCount'].apply(
    lambda x: 'one_bid' if x == 1 else 'more'
)

fig, ax = plt.subplots()
groups = [furniture_comp[furniture_comp['competition'] == c]['bid_price_EUR'].dropna() for c in ['one_bid', 'more']]
bp = ax.boxplot(groups, labels=['one_bid', 'more'], patch_artist=True)
colors = ['lightcoral', 'lightgreen']
for patch, color in zip(bp['boxes'], colors):
    patch.set_facecolor(color)
# add mean points
means = [g.mean() for g in groups]
ax.scatter([1, 2], means, color='red', s=50, zorder=3)
ax.set_ylim(0, 150000)
ax.set_title('Price Distribution by Competition Level')
ax.set_xlabel('Competition')
ax.set_ylabel('Bid Price (EUR)')
plt.show()

# GEOGRAPHICAL ANALYSIS

# Bar chart: Top countries by number of tenders
country_tenders = (furniture_clean[furniture_clean['tender_country'].notna()]
    .drop_duplicates(subset=['tender_id'])
    .groupby('tender_country')
    .size()
    .sort_values(ascending=False)
    .head(10))

plt.figure()
plt.barh(country_tenders.index[::-1], country_tenders.values[::-1], color='steelblue')
plt.title('Number of Tenders by Country\nTop 10 Countries - Furniture Sector')
plt.xlabel('Number of Tenders')
plt.ylabel('Country')
plt.show()

# Boxplot: Prices by country
country_prices = furniture_clean[furniture_clean['bid_price_EUR'] < 100000]
countries = country_prices['tender_country'].dropna().unique()

fig, ax = plt.subplots(figsize=(12, 6))
data_by_country = [country_prices[country_prices['tender_country'] == c]['bid_price_EUR'].dropna() 
                   for c in sorted(countries)]
ax.boxplot(data_by_country, labels=sorted(countries))
ax.set_title('Price Distribution by Country\nFurniture Sector - Lots < 100,000 EUR')
ax.set_xlabel('Country')
ax.set_ylabel('Bid Price (EUR)')
plt.xticks(rotation=45)
plt.tight_layout()
plt.show()
