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

library(dplyr)
library(ggplot2)
library(readr)

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
  "lot_lotId",
  "bid_row_nr",
  "bid_price_EUR",
  "publication_row_nr",
  "bid_isWinning"
)

# Load 2022 data
cat("Loading data...\n")
raw_data <- read_csv2("data-all-2022.csv", col_select = selected_cols)
cat("Total rows loaded:", nrow(raw_data), "\n")

# ==============================================================================
# 2. DATA CLEANING & FILTERING
# ==============================================================================

# Filter furniture sector (CPV 391*)
furniture_data <- filter(raw_data, startsWith(tender_mainCpv, "391"))

cat("Rows after furniture filter:", nrow(furniture_data), "\n")

# Keep latest publication per tender
furniture_data <- furniture_data %>%
  group_by(tender_id) %>%
  filter(publication_row_nr == max(publication_row_nr)) %>%
  ungroup()
  
cat("Rows after deduplication:", nrow(furniture_data), "\n")

# Create unique bids dataset
unique_bids <- furniture_data %>%
  filter(!is.na(bid_row_nr)) %>%
  distinct(tender_id, lot_lotId, bid_row_nr, .keep_all = TRUE)
cat("Unique bids:", nrow(unique_bids), "\n")

# Convert price to numeric
unique_bids$bid_price_EUR <- as.numeric(gsub(",", ".", unique_bids$bid_price_EUR))

# Filter valid prices
valid_prices <- filter(unique_bids, 
  !is.na(bid_price_EUR) & 
  bid_price_EUR > 0 & 
  bid_price_EUR < 5000000)
cat("Valid price records:", nrow(valid_prices), "\n\n")

cat("Unique tenders:", nrow(distinct(valid_prices, tender_id)), "\n")
cat("Unique lots:", nrow(distinct(valid_prices, lot_lotId)), "\n")
cat("Unique bids:", nrow(distinct(valid_prices, tender_id, lot_lotId, bid_row_nr)), "\n\n")



# ==============================================================================
# 3. PRICE DISTRIBUTION ANALYSIS
# ==============================================================================

# Summary statistics
summary(valid_prices$bid_price_EUR)

# Histogram: Bid price distribution
ggplot(valid_prices %>% filter(bid_price_EUR < 100000), 
       aes(x = bid_price_EUR)) +
  geom_histogram(fill = "steelblue", color = "white", bins = 30) +
  labs(
    title = "Bid Price Distribution",
    subtitle = "Furniture Sector - Bids < 100,000 EUR",
    x = "Bid Price (EUR)",
    y = "Frequency"
  )

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

# ==============================================================================
# 4. COMPETITION ANALYSIS (BIDS PER LOT)
# ==============================================================================

# Calculate bids per lot
competition <- furniture_data %>%
  distinct(tender_id, lot_lotId, bid_row_nr, .keep_all = TRUE) %>%
  filter(!is.na(lot_lotId)) %>%
  group_by(tender_id, lot_lotId) %>%
  summarise(n_bids = n_distinct(bid_row_nr), .groups = "drop")

summary(competition$n_bids)
table(competition$n_bids)

# Bar chart: Bids per lot distribution
ggplot(competition %>% filter(n_bids <= 15), aes(x = factor(n_bids))) +
  geom_bar(fill = "coral", color = "darkred") +
  scale_y_log10()+
  labs(
    title = "Number of Bids per Lot",
    subtitle = "Competition Level in Furniture Tenders",
    x = "Number of Bids",
    y = "Lot Count")

# Winning bids summary
bids_summary <- furniture_data %>%
  distinct(tender_id, lot_lotId, bid_row_nr, .keep_all = TRUE)

table(bids_summary$bid_isWinning)

# ==============================================================================
# 5. PROCEDURE TYPE ANALYSIS
# ==============================================================================

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
  distinct(lot_lotId, .keep_all = TRUE) %>%
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


# ==============================================================================
# 6. GEOGRAPHICAL ANALYSIS
# ==============================================================================

# Bar chart: Tenders by country (Top 10)
furniture_data %>%
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
ggplot(furniture_data %>% filter(bid_price_EUR < 100000), 
       aes(x = tender_country, y = bid_price_EUR, fill = tender_country)) +
  geom_boxplot(alpha = 0.7) +
  labs(
    title = "Price Distribution by Country",
    subtitle = "Furniture Sector - Bids < 100,000 EUR",
    x = "Country",
    y = "Bid Price (EUR)"
  ) +
  theme(legend.position = "none")
