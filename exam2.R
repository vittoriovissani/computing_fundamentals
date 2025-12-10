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

#df_all <- rbindlist(lapply(files, function(f) {
#  fread(f, sep = ";",colClasses = col_types, select = c( 
#    "tender_id","tender_mainCpv","tender_cpvs","tender_procedureType","lot_lotId",
#    "lot_selectionMethod","lot_validBidsCount","lot_estimatedPrice_EUR","bid_row_nr",
#    "bid_price_EUR","bid_isWinning"
#    ))[tender_mainCpv %in% cpv_keep | grepl(paste(cpv_keep, collapse="|"), tender_cpvs)]
#}))

toc()

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
buyers <- sample_recent %>%
  filter(!is.na(buyer_row_nr)) %>%
  select(starts_with("buyer"), tender_id, buyer_row_nr, publication_row_nr) %>%
  distinct(tender_id, buyer_row_nr, .keep_all = TRUE)

bidders <- sample_recent %>%
  filter(!is.na(bid_row_nr)) %>%
  select(matches("^bidder"), tender_id, lot_lotId, bid_row_nr, bidder_row_nr, publication_row_nr) %>%
  distinct(tender_id, lot_lotId, bid_row_nr, bidder_row_nr, .keep_all = TRUE)

#--------------------------------------------------------------------------------------

cat("\n--- CHECK OVERLAP ENTITÀ ---\n")
cat("Righe sample:", nrow(sample_recent), "\n")
cat("Righe tenders:", nrow(tenders), "\n")
cat("Righe lots:", nrow(lots), "\n")
cat("Righe bids:", nrow(bids), "\n")
cat("Righe buyers:", nrow(buyers), "\n")
cat("Righe bidders:", nrow(bidders), "\n")

# Quante righe hanno tutte le chiavi principali non NA
n_all_keys <- sample_recent %>%
  filter(!is.na(tender_id), !is.na(lot_lotId), !is.na(bid_row_nr), !is.na(buyer_row_nr), !is.na(bidder_row_nr)) %>%
  nrow()
cat("Righe con tutte le chiavi principali non NA:", n_all_keys, "\n")

# Quante righe hanno solo una chiave non NA (pure)
n_pure <- sample_recent %>%
  mutate(n_keys = (!is.na(tender_id)) + (!is.na(lot_lotId)) + (!is.na(bid_row_nr)) + (!is.na(buyer_row_nr)) + (!is.na(bidder_row_nr))) %>%
  filter(n_keys == 1) %>%
  nrow()
cat("Righe con una sola entità (pure):", n_pure, "\n")

# Quante righe hanno più di una chiave non NA (miste)
n_miste <- sample_recent %>%
  mutate(n_keys = (!is.na(tender_id)) + (!is.na(lot_lotId)) + (!is.na(bid_row_nr)) + (!is.na(buyer_row_nr)) + (!is.na(bidder_row_nr))) %>%
  filter(n_keys > 1) %>%
  nrow()
cat("Righe con più entità (miste):", n_miste, "\n")

#--------------------------------------------------------------------------------------

#how many bids per lot and tender
bids_lot <- bids %>%
  group_by(lot_lotId) %>%
  summarise(n_bids = n(),.groups = "drop")

bids_tender <- bids %>%
  group_by(tender_id) %>%
  summarise(n_bids = n(),.groups = "drop")

bids_stats <-bind_rows(bids_lot, bids_tender)

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

#distribution of bids price
ggplot(bids %>% filter(!is.na(bid_price_EUR) & bid_price_EUR>0), aes(x = bid_price_EUR)) +
  geom_histogram(bins=100, fill="#ef8a62", color="white") +
  xlim(0, 100000) +
  labs(x="Prezzo offerta (EUR)", y="Conteggio", title="Distribuzione prezzi offerte")



  





#bids_full <- bids %>%
#  left_join(lots %>% select(tender_id, lot_lotId, lot_estimatedPrice_EUR, lot_lotNumber, lot_title), by = c("tender_id","lot_lotId")) %>%
#  left_join(tenders %>% select(tender_id, tender_country, tender_procedureType, tender_year, tender_estimatedPrice_EUR), by = "tender_id")


#distribution of bids price
bids_full2 <- bids_full %>% mutate(is_win = ifelse(bid_isWinning == "yes", "win", ifelse(bid_isWinning == "no", "lose", NA)))
ggplot(bids_full2 %>% filter(!is.na(is_win) & !is.na(bid_price_EUR) & bid_price_EUR>0),
       aes(x = is_win, y = bid_price_EUR)) +
  geom_boxplot(outlier.size = 0.5) +
  scale_y_log10() +
  labs(x="Esito offerta", y="Prezzo (EUR, log)", title="Prezzo: vincente vs non vincente")

winners <- bids_full2 %>%
  filter(is_win == "win", !is.na(bid_price_EUR), !is.na(lot_estimatedPrice_EUR), bid_price_EUR>0, lot_estimatedPrice_EUR>0) %>%
  group_by(tender_id, lot_lotId) %>%
  summarise(win_price = min(bid_price_EUR, na.rm=TRUE), est = first(lot_estimatedPrice_EUR), .groups="drop")

ggplot(winners, aes(x = est, y = win_price)) +
  geom_point(alpha=0.3) +
  geom_smooth(method = "lm", formula = y ~ x, se = TRUE, color="blue") +
  scale_x_log10() + scale_y_log10() +
  labs(x = "Estimated lot price (EUR)", y = "Winning bid price (EUR)", title = "Winning price vs Estimated lot price (log-log)")


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



# Statistiche e check semplici sulle entità
cat("\n--- STATISTICHE E CHECK SEMPLICI ---\n")
cat(sprintf("Tenders: %d (unici: %d)\n", nrow(tenders), length(unique(tenders$tender_id))))
cat(sprintf("Lots: %d (unici: %d)\n", nrow(lots), length(unique(paste(lots$tender_id, lots$lot_lotId)))))
cat(sprintf("Bids: %d (unici: %d)\n", nrow(bids), length(unique(paste(bids$tender_id, bids$lot_lotId, bids$bid_row_nr)))))
cat(sprintf("Buyers: %d (unici: %d)\n", nrow(buyers), length(unique(paste(buyers$tender_id, buyers$buyer_row_nr)))))
cat(sprintf("Bidders: %d (unici: %d)\n", nrow(bidders), length(unique(paste(bidders$tender_id, bidders$lot_lotId, bidders$bid_row_nr, bidders$bidder_row_nr)))))

cat("\nEsempio tenders:\n"); print(head(tenders, 2))
cat("\nEsempio lots:\n"); print(head(lots, 2))
cat("\nEsempio bids:\n"); print(head(bids, 2))
cat("\nEsempio buyers:\n"); print(head(buyers, 2))
cat("\nEsempio bidders:\n"); print(head(bidders, 2))

# entità già costruite (tenders, lots, bids, buyers_rows, bidders_rows)
# build join (bids_full) with selected columns

# Statistiche sintetiche per ciascuna entità
cat("\n--- STATISTICHE SINTETICHE ---\n")
cat("Tenders: paesi principali\n"); print(head(sort(table(tenders$tender_country), decreasing=TRUE),5))
cat("Tenders: procedure principali\n"); print(head(sort(table(tenders$tender_procedureType), decreasing=TRUE),5))
cat("Tenders: CPV principali\n"); print(head(sort(table(tenders$tender_mainCpv), decreasing=TRUE),5))

cat("\nLots: prezzo stimato (EUR)\n"); print(summary(lots$lot_estimatedPrice_EUR))
cat("Lots: titoli principali\n"); print(head(sort(table(lots$lot_title), decreasing=TRUE),3))

cat("\nBids: prezzo offerta (EUR)\n"); print(summary(bids$bid_price_EUR))
cat("Bids: esito vincente\n"); print(table(bids$bid_isWinning))

cat("\nBuyers: paesi principali\n"); print(head(sort(table(buyers$buyer_country), decreasing=TRUE),5))
cat("Buyers: tipi principali\n"); print(head(sort(table(buyers$buyer_buyerType), decreasing=TRUE),5))

cat("\nBidders: paesi principali\n"); print(head(sort(table(bidders$bidder_country), decreasing=TRUE),5))

# Analisi concorrenza: scatterplot prezzo offerta vs stimato, colore CPV, forma per metodo selezione
bids_full <- bids %>%
  left_join(lots %>% select(tender_id, lot_lotId, lot_estimatedPrice_EUR, lot_selectionMethod, lot_title, lot_lotNumber), by = c("tender_id","lot_lotId")) %>%
  left_join(tenders %>% select(tender_id, tender_country, tender_mainCpv, tender_procedureType), by = "tender_id")

# Filtra solo dati con prezzi validi
bids_plot <- bids_full %>% filter(!is.na(bid_price_EUR) & bid_price_EUR>0 & !is.na(lot_estimatedPrice_EUR) & lot_estimatedPrice_EUR>0)
ggplot(bids_plot, aes(x = lot_estimatedPrice_EUR, y = bid_price_EUR,
                      color = tender_mainCpv, shape = lot_selectionMethod)) +
  scale_x_log10() +
  scale_y_log10() +
  labs(x = "Prezzo stimato lotto (EUR, log)", y = "Prezzo offerta (EUR, log)",
       color = "CPV", shape = "Metodo selezione",
       title = "Concorrenza: Prezzo offerta vs stimato")

