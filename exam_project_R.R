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

library(dplyr)
library(ggplot2)
library(data.table)

setwd("~/Documents/Computing fundamentals/workspace esame/data-all-csv")
options(scipen = 999)

# Define columns for analysis
selected_cols <- c(
  "tender_id",
  "tender_mainCpv",
  "tender_country",
  "tender_size",
  "tender_procedureType",
  "buyer_buyerType",
  "lot_row_nr",
  "lot_bidsCount",
  "bid_row_nr",
  "bid_price_EUR",
  "bid_isWinning"
)

# Load 2021 data
cat("Loading data...\n")
raw_data <- fread("data-all-2021.csv", sep = ";", select = selected_cols, colClasses = "character")
cat("Total rows loaded:", nrow(raw_data), "\n")

# DATA CLEANING AND FILTERING

# Filter furniture sector (CPV 391*)
furniture_data <- filter(raw_data, startsWith(tender_mainCpv, "391"))

cat("Rows after furniture filter:", nrow(furniture_data), "\n")

table(furniture_data$bid_isWinning)

# Keep only winning bids (actual contracts)
furniture_data <- filter(furniture_data, bid_isWinning == "yes")
cat("Rows after winning bid filter:", nrow(furniture_data), "\n")

# Get unique lots (one row per lot)
unique_lots <- furniture_data %>%
  distinct(tender_id, lot_row_nr, .keep_all = TRUE)
cat("Unique lots:", nrow(unique_lots), "\n")

# Convert numeric columns
unique_lots$bid_price_EUR <- as.numeric(gsub(",", ".", unique_lots$bid_price_EUR))
unique_lots$lot_bidsCount <- as.numeric(unique_lots$lot_bidsCount)

# Filter valid prices for price analysis
valid_prices <- filter(unique_lots, 
  !is.na(bid_price_EUR) & 
  bid_price_EUR > 0 & 
  bid_price_EUR < 5000000)
cat("Lots with valid price:", nrow(valid_prices), "\n")

# Filter lots with bid count info for competition analysis
lots_with_bids_info <- filter(unique_lots, !is.na(lot_bidsCount))
cat("Lots with bids count info:", nrow(lots_with_bids_info), "\n\n")

cat("Summary:\n")
cat("Unique tenders:", nrow(distinct(unique_lots, tender_id)), "\n")
cat("Unique lots:", nrow(unique_lots), "\n\n")



# PRICE DISTRIBUTION ANALYSIS

# Summary statistics
summary(valid_prices$bid_price_EUR)

# Boxplot: Overall price distribution
ggplot(valid_prices %>% filter(bid_price_EUR < 500000), aes(y = bid_price_EUR)) +
  geom_boxplot(fill = "lightblue", color = "darkblue") +
  coord_flip() +
  labs(
    title = "Bid Price Boxplot",
    subtitle = "Furniture Sector 2022",
    y = "Bid Price (EUR)"
  )

# Boxplot: Prices distribution by tender size

size_data <- filter(valid_prices, !is.na(tender_size))

ggplot(size_data, aes(x = tender_size, y = bid_price_EUR, fill = tender_size)) +
  geom_boxplot() +
  ylim(0, 100000) +
  labs(
    title = "Price Distribution by Tender Size",
    subtitle = "Furniture Sector 2022",
    x = "Tender Size",
    y = "Bid Price (EUR)") +
  theme(legend.position = "none")

# COMPETITION ANALYSIS (BIDS PER LOT)

# Use lot_bidsCount from the dataset (not counting rows)
cat("Competition statistics (lot_bidsCount):\n")
summary(lots_with_bids_info$lot_bidsCount)
table(lots_with_bids_info$lot_bidsCount)

# Bar chart: Bids per lot distribution
ggplot(lots_with_bids_info %>% filter(lot_bidsCount <= 15 & lot_bidsCount > 0), 
       aes(x = factor(lot_bidsCount))) +
  geom_bar(fill = "coral", color = "darkred") +
  labs(
    title = "Number of Bids per Lot",
    subtitle = "Competition Level in Furniture Tenders (from lot_bidsCount)",
    x = "Number of Bids",
    y = "Lot Count")

# PROCEDURE TYPE ANALYSIS

# Statistics by procedure type
proc_data <- filter(valid_prices, !is.na(tender_procedureType))%>%
  distinct(tender_id, .keep_all = TRUE)

proc_stats <- group_by(proc_data, tender_procedureType) %>%
  summarise(
    n = n(),
    mean_price = round(mean(bid_price_EUR), 0),
    median_price = round(median(bid_price_EUR), 0)
  ) %>%
  filter(n >= 50) %>%
  arrange(desc(n))

cat("\nStatistics by procedure type:\n")
print(proc_stats)

# Boxplot: Prices by procedure type
main_procedures <- proc_stats$tender_procedureType


# Bar chart: Lots by procedure type
proc_data %>%
  distinct(tender_id, lot_row_nr, .keep_all = TRUE) %>%
  group_by(tender_procedureType) %>%
  summarise(n_lots = n()) %>%
  arrange(desc(n_lots)) %>%
  head(10) %>%
  ggplot(aes(x = reorder(tender_procedureType, n_lots), y = n_lots)) +
  geom_col(fill = "steelblue") +
  coord_flip() +
  labs(
    title = "Number of Lots by Procedure Type",
    subtitle = "Top 10 Procedures - Furniture Sector",
    x = "Procedure Type",
    y = "Number of Lots"
  )

ggplot(filter(proc_data, tender_procedureType %in% main_procedures),
       aes(x = tender_procedureType, y = bid_price_EUR, fill = tender_procedureType)) +
  geom_boxplot() +
  ylim(0,100000)+
  labs(
    title = "Price Distribution by Procedure Type",
    subtitle = "Log Scale - Furniture Sector 2022",
    x = "Procedure Type",
    y = "Bid Price (EUR)"
  ) +
  theme_minimal() +
  theme(legend.position = "none")


# GEOGRAPHICAL ANALYSIS

# Bar chart: Top countries by number of tenders
unique_lots %>%
  filter(!is.na(tender_country)) %>%
  distinct(tender_id, .keep_all = TRUE) %>%
  group_by(tender_country) %>%
  summarise(n_tenders = n()) %>%
  arrange(desc(n_tenders)) %>%
  head(10) %>%
  ggplot(aes(x = reorder(tender_country, n_tenders), y = n_tenders)) +
  geom_col(fill = "steelblue") +
  coord_flip() +
  labs(
    title = "Number of Tenders by Country",
    subtitle = "Top 10 Countries - Furniture Sector",
    x = "Country",
    y = "Number of Tenders"
  )

# Boxplot: Prices by country
ggplot(valid_prices %>% filter(bid_price_EUR < 100000), 
       aes(x = tender_country, y = bid_price_EUR, fill = tender_country)) +
  geom_boxplot(alpha = 0.7) +
  labs(
    title = "Price Distribution by Country",
    subtitle = "Furniture Sector - Lots < 100,000 EUR",
    x = "Country",
    y = "Bid Price (EUR)"
  ) +
  theme(legend.position = "none")

