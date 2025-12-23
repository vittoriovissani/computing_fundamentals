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
#sample <- read_csv2(files, n_max = 50000)
#names <- paste(as.character(names(sample)))

# Mappa dei tipi per le colonne che ti servono
col_types <- c(
    "tender_id" = col_character(),
    "tender_mainCpv" = col_character(),
    "tender_cpvs" = col_character(),
    "tender_procedureType" = col_character(),
    "tender_country" = col_character(),
    "tender_year" = col_integer(),
    "tender_estimatedPrice_EUR" = col_double(),
    "lot_lotId" = col_character(),
    "lot_selectionMethod" = col_character(),
    "lot_validBidsCount" = col_integer(),
    "lot_estimatedPrice_EUR" = col_double(),
    "lot_title" = col_character(),
    "lot_lotNumber" = col_character(),
    "bid_row_nr" = col_integer(),
    "bid_price_EUR" = col_double(),
    "bid_isWinning" = col_character(),
    "buyer_row_nr" = col_integer(),
    "buyer_country" = col_character(),
    "buyer_buyerType" = col_character(),
    "bidder_row_nr" = col_integer(),
    "bidder_country" = col_character(),
    "publication_row_nr" = col_integer()
  )



tic("reading and filtering CSV files")

df_all <- rbindlist(lapply(files, function(f) {
  fread(f, sep = ";",colClasses = col_types, select = c(
    "tender_id", "tender_mainCpv","tender_cpvs", "tender_procedureType", "tender_country",
    "tender_year", "tender_estimatedPrice_EUR", "lot_lotId", "lot_selectionMethod",
    "lot_validBidsCount", "lot_estimatedPrice_EUR", "lot_title", "lot_lotNumber",
    "bid_row_nr", "bid_price_EUR", "bid_isWinning", "buyer_row_nr", "buyer_country",
    "buyer_buyerType", "bidder_row_nr", "bidder_country", "publication_row_nr"
    ))[tender_mainCpv %in% cpv_keep | grepl(paste(cpv_keep, collapse="|"), tender_cpvs)]
}))

toc()

df_all <- df_all %>%
  group_by(tender_id) %>%
  filter(publication_row_nr == max(publication_row_nr)) %>%
  ungroup()

#Parent tables
tenders <- df_all %>%
  select(matches("^tender"), tender_id, publication_row_nr) %>%
  distinct(tender_id, .keep_all = TRUE)

lots <- df_all %>%
  filter(!is.na(lot_lotId) & lot_lotId != "") %>%
  select(matches("^lot"), tender_id, lot_lotId, publication_row_nr) %>%
  distinct(tender_id, lot_lotId, .keep_all = TRUE)

bids <- df_all %>%
  filter(!is.na(bid_row_nr) & bid_row_nr != "") %>%
  select(matches("^bid_"), tender_id, lot_lotId, bid_row_nr, publication_row_nr) %>%
  distinct(tender_id, lot_lotId, bid_row_nr, .keep_all = TRUE)

#Child tables
buyers <- df_all %>%
  filter(!is.na(buyer_row_nr)) %>%
  select(starts_with("buyer"), tender_id, buyer_row_nr, publication_row_nr) %>%
  distinct(tender_id, buyer_row_nr, .keep_all = TRUE)

bidders <- df_all %>%
  filter(!is.na(bid_row_nr)) %>%
  select(matches("^bidder"), tender_id, lot_lotId, bid_row_nr, bidder_row_nr, publication_row_nr) %>%
  distinct(tender_id, lot_lotId, bid_row_nr, bidder_row_nr, .keep_all = TRUE)

#--------------------------------------------------------------------------------------

cat("\n--- CHECK OVERLAP ENTITÀ ---\n")
cat("Righe sample:", nrow(df_all), "\n")
cat("Righe tenders:", nrow(tenders), "\n")
cat("Righe lots:", nrow(lots), "\n")
cat("Righe bids:", nrow(bids), "\n")
cat("Righe buyers:", nrow(buyers), "\n")
cat("Righe bidders:", nrow(bidders), "\n")

# Quante righe hanno tutte le chiavi principali non NA
n_all_keys <- df_all %>%
  filter(!is.na(tender_id), !is.na(lot_lotId), !is.na(bid_row_nr), !is.na(buyer_row_nr), !is.na(bidder_row_nr)) %>%
  nrow()
cat("Righe con tutte le chiavi principali non NA:", n_all_keys, "\n")

# Quante righe hanno solo una chiave non NA (pure)
n_pure <- df_all %>%
  mutate(n_keys = (!is.na(tender_id)) + (!is.na(lot_lotId)) + (!is.na(bid_row_nr)) + (!is.na(buyer_row_nr)) + (!is.na(bidder_row_nr))) %>%
  filter(n_keys == 1) %>%
  nrow()
cat("Righe con una sola entità (pure):", n_pure, "\n")

# Quante righe hanno più di una chiave non NA (miste)
n_miste <- df_all %>%
  mutate(n_keys = (!is.na(tender_id)) + (!is.na(lot_lotId)) + (!is.na(bid_row_nr)) + (!is.na(buyer_row_nr)) + (!is.na(bidder_row_nr))) %>%
  filter(n_keys > 1) %>%
  nrow()
cat("Righe con più entità (miste):", n_miste, "\n")

#--------------------------------------------------------------------------------------
options(scipen=999)

#how many bids per lot and tender
bids_lot <- bids %>%
  group_by(lot_lotId) %>%
  summarise(n_bids = n(),.groups = "drop")

bids_tender <- bids %>%
  group_by(tender_id) %>%
  summarise(n_bids = n(),.groups = "drop")

summary(bids_tender$n_bids)
summary(bids_lot$n_bids)

#how many bidders for bid
bidders_per_bid <- bidders %>%
  group_by(tender_id, lot_lotId, bid_row_nr) %>%
  summarise(n_bidders = n(), .groups = "drop")

ggplot(bidders_per_bid, aes(x = n_bidders)) +
  geom_bar(fill = "lightblue", color = "blue") +
  scale_y_log10() +
  labs(x = "Numero di bidder per offerta", y = "Conteggio offerte", title = "Distribuzione: bidder per offerta")
ggsave("plot_bidders_per_bid.png")

#distribution of bids price
ggplot(bids %>% filter(!is.na(bid_price_EUR) & bid_price_EUR>0), aes(x = bid_price_EUR)) +
  geom_histogram( fill="#ef8a62", color="white") +
  xlim(0, 100000) +
  labs(x="Prezzo offerta (EUR)", y="Conteggio", title="Distribuzione prezzi offerte")
ggsave("plot_bids_price_distribution.png")

pie(table(bids$bid_isWinning))
ggsave("plot_pie_bid_isWinning.png")
  

#add average price by lot_Id, like group_by+summarize+join 
bids <- bids %>%
  mutate(bid_competition_average = mean(bid_price_EUR), .by = lot_lotId)%>%
  left_join(bids_lot, join_by(lot_lotId))%>%
  left_join(tenders, join_by(tender_id))


ggplot(bids %>% filter(n_bids > 1), aes(x = bid_competition_average, y = bid_price_EUR,color = bid_isWinning, shape = bid_isWinning))+
  geom_point()+
  xlim(0,50000)+
  ylim(0,50000)+  
  scale_colour_brewer()
ggsave("plot_bids_vs_average_competition.png")

ggplot(bids, aes(x = bid_price_EUR))+
  geom_histogram(binwidth = 10000)+
  xlim(NA,1000000)
ggsave("plot_bids_histogram_1M.png")

ggplot(bids %>% filter(n_bids == 1), aes(x = bid_isWinning, y = bid_price_EUR, color = bid_isWinning, shape = bid_isWinning))+
  geom_violin()+
  ylim(0,50000)+
  scale_colour_brewer()
ggsave("plot_violin_single_bid.png")

ggplot(bids, aes(x = bid_isWinning, y = bid_price_EUR, color = bid_isWinning, shape = bid_isWinning))+
  geom_violin()+
  ylim(25000,500000)
ggsave("plot_violin_all_bids.png")
 