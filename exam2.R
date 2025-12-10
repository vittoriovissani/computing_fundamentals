setwd("~/Documents/Computing fundamentals/workspace esame/data-all-csv")
library(data.table)
library(vroom)
library(dplyr)
library(readr)
library(tictoc)
library(ggplot2)


# CPV di interesse (singolo valore: usa filtro '=='; se multipli: usa '%in%')
cpv_keep <- c(
  "39100000",  # Furniture
  "39110000",  # Seats, chairs
  "39111000",  # Seats
  "39112000",  # Chairs
  "39113000",  # Sofas
  "39120000",  # Tables, cupboards, desks
  "39121000",  # Tables
  "39122000",  # Cupboards
  "39123000",  # Desks
  "39130000",  # Office furniture
  "39131000",  # Office desks
  "39132000",  # Office chairs
  "39133000",  # Filing cabinets
  "39134000",  # Conference-room furniture
  "39135000",  # Shelving
  "39140000",  # Domestic furniture
  "39141000",  # Bedroom furniture
  "39142000",  # Dining-room furniture
  "39143000",  # Living-room furniture
  "39151000",  # School furniture
  "39154000",  # Hospital furniture
  "39156000"   # Hotel and restaurant furniture
)

# Lista dei file (stesso pattern che usi già)
files <- list.files(pattern = "data-all-")



#sample to read column content
sample <- read_csv2(files, n_max = 50000)
names <- paste(as.character(names(sample)))

# Mappa dei tipi per le colonne che ti servono
col_types <- c(
  "tender_id" = col_character(),
  "tender_mainCpv" = col_character(),
  "tender_cpvs" = col_character(),
  "tender_procedureType" = col_character(),
  "lot_lotId" = col_character(),
  "lot_selectionMethod" = col_character(),
  "lot_validBidsCount" = col_integer(),
  "lot_estimatedPrice_EUR" = col_double(),
  "bid_row_nr" = col_integer(),
  "bid_price_EUR" = col_double(),
  "bid_isWinning" = col_character()
)


tic("reading and filtering CSV files")

df_all <- rbindlist(lapply(files, function(f) {
  fread(f, sep = ";",colClasses = col_types, select = c( 
    "tender_id","tender_mainCpv","tender_cpvs","tender_procedureType","lot_lotId",
    "lot_selectionMethod","lot_validBidsCount","lot_estimatedPrice_EUR","bid_row_nr",
    "bid_price_EUR","bid_isWinning"
    ))[tender_mainCpv %in% cpv_keep | grepl(paste(cpv_keep, collapse="|"), tender_cpvs)]
}))

toc()




## Use the sample (not the full dataset) to discover column names and build
## the per-entity tables (tenders, lots, bids, buyers, bidders).
## This keeps work light: we filter the sample to the most recent publication per tender.
colnames_sample <- names(sample)
message("Sample columns: ", paste(colnames_sample, collapse = ", "))

sample_recent <- sample %>%
  group_by(tender_id) %>%
  filter(publication_row_nr == max(publication_row_nr)) %>%
  ungroup()

#Parent tables
tenders <- sample_recent %>%
  select(matches("^tender"), tender_id, publication_row_nr) %>%
  distinct(tender_id, .keep_all = TRUE)

lots <- sample_recent %>%
  filter(!is.na(lot_lotId) & lot_lotId != "") %>%
  select(matches("^lot"), tender_id, lot_lotId, publication_row_nr) %>%
  distinct(tender_id, lot_lotId, .keep_all = TRUE)

bids <- sample_recent %>%
  filter(!is.na(bid_row_nr) & bid_row_nr != "") %>%
  select(matches("^bid"), tender_id, lot_lotId, bid_row_nr, publication_row_nr) %>%
  distinct(tender_id, lot_lotId, bid_row_nr, .keep_all = TRUE)

#Child tables
buyers_rows <- sample_recent %>%
  filter(!is.na(buyer_row_nr)) %>%
  select(starts_with("buyer"), tender_id, buyer_row_nr, publication_row_nr) %>%
  distinct(tender_id, buyer_row_nr, .keep_all = TRUE)

bidders_rows <- sample_recent %>%
  filter(!is.na(bid_row_nr)) %>%
  select(matches("^bidder"), tender_id, lot_lotId, bid_row_nr, bidder_row_nr, publication_row_nr) %>%
  distinct(tender_id, lot_lotId, bid_row_nr, bidder_row_nr, .keep_all = TRUE)

#sanity check prints
cat("sample_recent rows:", nrow(sample_recent), "\n")
cat("tenders:", nrow(tenders), "lots:", nrow(lots), "bids:", nrow(bids),
    "buyers:", nrow(buyers), "bidders:", nrow(bidders), "\n","total:", sum(nrow(tenders), nrow(lots), nrow(bids)))

library(dplyr)
library(ggplot2)
library(tidyr)

# normalizza stringhe vuote -> NA e lowercase per isWinning
sample_recent <- sample_recent %>%
  mutate(across(where(is.character), ~ ifelse(trimws(.x) == "", NA_character_, trimws(.x)))) %>%
  mutate(bid_isWinning = tolower(as.character(bid_isWinning)),
         bid_isWinning = ifelse(bid_isWinning %in% c("yes","true","y","1"), "yes",
                                ifelse(bid_isWinning %in% c("no","false","n","0"), "no", NA)))

# entità già costruite (tenders, lots, bids, buyers_rows, bidders_rows)
# build join (bids_full) with selected columns
bids_full <- bids %>%
  left_join(lots %>% select(tender_id, lot_lotId, lot_estimatedPrice_EUR, lot_lotNumber, lot_title), by = c("tender_id","lot_lotId")) %>%
  left_join(tenders %>% select(tender_id, tender_country, tender_procedureType, tender_year, tender_estimatedPrice_EUR), by = "tender_id")

bids_per_lot <- bids %>%
  group_by(tender_id, lot_lotId) %>%
  summarise(n_bids = n(), .groups = "drop")

ggplot(bids_per_lot, aes(x = n_bids)) +
  geom_histogram(binwidth = 1, fill = "#2c7fb8", color = "white") +
  scale_y_log10() +
  labs(x = "Numero offerte per lotto (log scale)", y = "Conteggio lotti", title = "Distribuzione: offerte per lotto")

bidders_per_bid <- bidders_rows %>%
  group_by(tender_id, lot_lotId, bid_row_nr) %>%
  summarise(n_bidders = n(), .groups = "drop")

ggplot(aes(y= bidders_per_bid, x = n_bidders)) +
  geom_histogram(binwidth = 1, fill = "#91cf60", color = "white") +
  scale_y_log10() +
  labs(x = "Numero di bidder per offerta", y = "Conteggio offerte", title = "Distribuzione: bidder per offerta")

ggplot(bids_full %>% filter(!is.na(bid_price_EUR) & bid_price_EUR>0), aes(x = bid_price_EUR)) +
  geom_histogram(bins=100, fill="#ef8a62", color="white") +
  scale_x_log10() +
  labs(x="Prezzo offerta (EUR, log scale)", y="Conteggio", title="Distribuzione prezzi offerte")


ggplot(bids, aes(x = bid_price_eur, y = )

bids_full2 <- bids_full %>% mutate(is_win = ifelse(bid_isWinning == "yes", "win", ifelse(bid_isWinning == "no", "lose", NA)))
ggplot(bids_full2 %>% filter(!is.na(is_win) & !is.na(bid_price_EUR) & bid_price_EUR>0),
       aes(x = is_win, y = bid_price_EUR)) +
  geom_boxplot(outlier.size = 0.5) +
  scale_y_log10() +
  labs(x="Esito offerta", y="Prezzo (EUR, log)", title="Prezzo: vincente vs non vincente")
ggsave("plot_price_win_vs_lose.png", width=6, height=5)

winners <- bids_full2 %>%
  filter(is_win == "win", !is.na(bid_price_EUR), !is.na(lot_estimatedPrice_EUR), bid_price_EUR>0, lot_estimatedPrice_EUR>0) %>%
  group_by(tender_id, lot_lotId) %>%
  summarise(win_price = min(bid_price_EUR, na.rm=TRUE), est = first(lot_estimatedPrice_EUR), .groups="drop")

ggplot(winners, aes(x = est, y = win_price)) +
  geom_point(alpha=0.3) +
  geom_smooth(method = "lm", formula = y ~ x, se = TRUE, color="blue") +
  scale_x_log10() + scale_y_log10() +
  labs(x = "Estimated lot price (EUR)", y = "Winning bid price (EUR)", title = "Winning price vs Estimated lot price (log-log)")
ggsave("plot_win_vs_estimated.png", width=7, height=6)

bids_per_lot2 <- bids_per_lot %>%
  left_join(lots %>% select(tender_id, lot_lotId, lot_estimatedPrice_EUR), by = c("tender_id","lot_lotId")) %>%
  filter(!is.na(lot_estimatedPrice_EUR) & lot_estimatedPrice_EUR>0)

ggplot(bids_per_lot2, aes(x = lot_estimatedPrice_EUR, y = n_bids)) +
  geom_point(alpha=0.3) +
  scale_x_log10() +
  labs(x = "Estimated price (EUR, log)", y = "n bids per lot", title = "Numero offerte vs prezzo stimato")
ggsave("plot_nBids_vs_estimated.png", width=7, height=5)

proc_stats <- bids_full %>%
  group_by(tender_procedureType) %>%
  summarise(
    n_bids = n(),
    mean_price = mean(bid_price_EUR, na.rm=TRUE),
    median_price = median(bid_price_EUR, na.rm=TRUE),
    .groups="drop"
  ) %>%
  arrange(-n_bids)

# bar chart top 15 procedure by n_bids
proc_stats %>% slice_head(n=15) %>%
  ggplot(aes(x = reorder(tender_procedureType, n_bids), y = n_bids)) +
  geom_col(fill="#4575b4") + coord_flip() +
  labs(x="", y="n bids", title="Top 15 tender_procedureType by number of bids")
ggsave("plot_proc_type_top15.png", width=8, height=6)