# EUROPEAN PUBLIC PROCUREMENT ANALYSIS - FURNITURE SECTOR
# Data: 2021, Source: EU Open Data Portal

import pandas as pd
import matplotlib.pyplot as plt


pd.set_option('display.float_format', '{:.2f}'.format)

# LOAD DATA

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

print("Loading data...")
raw_data = pd.read_csv(
    "/Users/vittoriovissani/Documents/Computing fundamentals/workspace esame/data-all-csv/data-all-2021.csv",
    sep=';',
    usecols=selected_cols,
    dtype=str
)
print("Total rows loaded:", len(raw_data))

# CLEANING

# Filter furniture sector 
furniture_raw = raw_data[raw_data['tender_mainCpv'].str.startswith('391', na=False)]
print("Rows after furniture filter:", len(furniture_raw))

# Keep only winning bids
furniture_awarded = furniture_raw[furniture_raw['bid_isWinning'] == 'yes']
print("Rows after winning bid filter:", len(furniture_awarded))

# One row per lot (deduplicate)
furniture_clean = furniture_awarded.drop_duplicates(subset=['tender_id', 'lot_row_nr'])
print("Unique lots (dedup):", len(furniture_clean))

# Convert types
furniture_clean.loc[:,'bid_price_EUR'] = furniture_clean['bid_price_EUR'].str.replace(',', '.', regex=False)
furniture_clean.loc[:,'bid_price_EUR'] = pd.to_numeric(furniture_clean['bid_price_EUR'], errors='coerce')
furniture_clean.loc[:,'lot_bidsCount'] = pd.to_numeric(furniture_clean['lot_bidsCount'], errors='coerce')

# Filter valid prices
furniture_clean = furniture_clean[
    (furniture_clean['bid_price_EUR'].notna()) &
    (furniture_clean['bid_price_EUR'] > 0) &
    (furniture_clean['bid_price_EUR'] < 5000000) &
    (furniture_clean['lot_bidsCount'].notna())
]
furniture_clean['bid_price_EUR'] = pd.to_numeric(furniture_clean['bid_price_EUR'], errors='coerce')

print("Lots after price + bidsCount filters:", len(furniture_clean))
print("Unique tenders (clean):", len(furniture_clean['tender_id'].unique()))

# PRICE DISTRIBUTION

print("\nPrice summary:")
print(furniture_clean['bid_price_EUR'].describe())

plt.boxplot(furniture_clean['bid_price_EUR'])
plt.title('Bid Price Boxplot - Furniture 2021')
plt.ylabel('EUR')
plt.ylim(0,150000)
plt.show()

# COMPETITION ANALYSIS

print("\nBids per lot summary:")
print(furniture_clean['lot_bidsCount'].describe())


# COMPETITION vs PRICE
one_bid = furniture_clean[furniture_clean['lot_bidsCount'] == 1]['bid_price_EUR']
more_bids = furniture_clean[furniture_clean['lot_bidsCount'] > 1]['bid_price_EUR']

plt.boxplot([one_bid, more_bids])
plt.title('Price by Competition Level')
plt.xticks([1, 2], ['one_bid', 'more'])
plt.ylabel('EUR')
plt.ylim(0,150000)
plt.show()

# GEOGRAPHICAL ANALYSIS

country_tenders = furniture_clean.drop_duplicates(subset=['tender_id'])
country_counts = country_tenders['tender_country'].value_counts().head(10)
print("\nTop 10 countries by tenders:")
print(country_counts)

plt.barh(country_counts.index, country_counts.values)
plt.title('Number of Tenders by Country - Top 10')
plt.xlabel('Number of Tenders')
plt.show()
