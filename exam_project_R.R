# EUROPEAN PUBLIC PROCUREMENT ANALYSIS - FURNITURE SECTOR

# Analysis of European public tenders in the furniture sector (2022 data).

# DATA SOURCE: EU Open Data Portal - Public Procurement Dataset)
# ~ 
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
  "lot_row_nr",
  "lot_bidsCount",
  "bid_price_EUR",
  "bid_isWinning")

# Load 2021 data
cat("Loading data...\n")
raw_data <- fread("data-all-2021.csv", sep = ";", select = selected_cols, colClasses = "character")
cat("Total rows loaded:", nrow(raw_data), "\n")

# DATA CLEANING AND FILTERING

# Single cleaning flow: build one dataset of awarded lots, deduplicated and cleaned

# Filter furniture sector (CPV 391*)
furniture_raw <- raw_data %>%
  filter(startsWith(tender_mainCpv, "391"))

cat("Rows after furniture filter:", nrow(furniture_raw), "\n")

# Keep only winning bids (actual contracts)
furniture_awarded <- furniture_raw %>%
  filter(bid_isWinning == "yes")

cat("Rows after winning bid filter:", nrow(furniture_awarded), "\n")

# One row per lot (within tender) + basic type cleaning + main filters
furniture_clean <- furniture_awarded %>%
  distinct(tender_id, lot_row_nr, .keep_all = TRUE) %>%
  mutate(
    bid_price_EUR = as.numeric(gsub(",", ".", bid_price_EUR)),
    lot_bidsCount = as.numeric(lot_bidsCount)) %>%
  filter(
    !is.na(bid_price_EUR) &
      bid_price_EUR > 0 &
      bid_price_EUR < 5000000 &
      !is.na(lot_bidsCount)
  )

cat("Unique lots (dedup):", nrow(distinct(furniture_awarded, tender_id, lot_row_nr)), "\n")
cat("Lots after price + bidsCount filters:", nrow(furniture_clean), "\n")
cat("Unique tenders (clean):", nrow(distinct(furniture_clean, tender_id)), "\n")
cat("Duplicated rows:", sum(duplicated(furniture_clean)), "\n")
# PRICE DISTRIBUTION ANALYSIS

# Summary statistics
summary(furniture_clean$bid_price_EUR)

# Boxplot: Overall price distribution
ggplot(furniture_clean %>% filter(bid_price_EUR < 500000), aes(y = bid_price_EUR)) +
  geom_boxplot(fill = "lightblue", color = "darkblue") +
  coord_flip() +
  labs(
    title = "Bid Price Boxplot",
    subtitle = "Furniture Sector 2022",
    y = "Bid Price (EUR)"
  )


# COMPETITION ANALYSIS (BIDS PER LOT)

# Use lot_bidsCount from the dataset (same df used for prices)
summary(furniture_clean$lot_bidsCount)

# Bar chart: Bids per lot distribution
ggplot(furniture_clean %>% filter(lot_bidsCount <= 15 & lot_bidsCount > 0),
  aes(x = factor(lot_bidsCount))) +
  geom_bar(fill = "coral", color = "darkred") +
  labs(
    title = "Number of Bids per Lot",
    subtitle = "Competition Level in Furniture Tenders (from lot_bidsCount)",
    x = "Number of Bids",
    y = "Lot Count")

# PROCEDURE TYPE / TENDER SIZE ANALYSIS

#Pie chart of tender size
furniture_clean %>%
  filter(!is.na(tender_size))%>%
  group_by(tender_size)%>%
  summarize(n_lots = n())%>%
  ungroup()%>%
    ggplot(aes(x = "", y = n_lots, fill = tender_size)) +
      geom_bar(stat = "identity") +
      coord_polar("y")+
      theme_void()


top_procedure_types <- furniture_clean %>%
  filter(!is.na(tender_procedureType)) %>%
  group_by(tender_procedureType) %>%
  summarise(n_lots = n(), .groups = "drop") %>%
  arrange(desc(n_lots)) %>%
  head(5) 

furniture_clean %>%
  filter(!is.na(tender_procedureType)) %>%
  filter(tender_procedureType %in% top_procedure_types$tender_procedureType)%>%
  mutate(competition = if_else(lot_bidsCount == 1, "one_bid", "more")) %>%
  group_by(tender_procedureType, competition)%>%
  summarise(n_lots = n(), .groups = "drop") %>%
    ggplot(aes(x = "", y = n_lots, fill = tender_procedureType)) +
      geom_col(width = 1,stat = "identity") +
      coord_polar("y")+
      facet_wrap(~ competition)+
      theme_minimal()

furniture_clean %>%
  mutate(competition = if_else(lot_bidsCount == 1, "one_bid", "more")) %>%
  ggplot(aes(x = competition, y = bid_price_EUR, fill = competition ))+
  geom_boxplot()+
  coord_cartesian(ylim = c(0,150000))+
  stat_summary(fun = mean, geom = "point", color = "red", size = 5)

l_model <- lm(bid_price_EUR ~ lot_bidsCount, data = furniture_clean)
summary(l_model)


# GEOGRAPHICAL ANALYSIS

# Bar chart: Top countries by number of tenders
furniture_clean %>%
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
ggplot(furniture_clean %>% filter(bid_price_EUR < 100000),
       aes(x = tender_country, y = bid_price_EUR, fill = tender_country)) +
  geom_boxplot() +
  labs(
    title = "Price Distribution by Country",
    subtitle = "Furniture Sector - Lots < 100,000 EUR",
    x = "Country",
    y = "Bid Price (EUR)"
  ) +
  theme(legend.position = "none")


