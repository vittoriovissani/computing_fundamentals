# ============================================================================
#                    PROGETTO R - COMPUTING FUNDAMENTALS
#                 Analisi del Mercato degli Appalti di Mobili
#                        (European Public Procurement)
# ============================================================================
# 
# OBIETTIVO DEL PROGETTO:
# Analizzare le gare d'appalto pubbliche europee nel settore dell'arredamento
# per rispondere alle seguenti domande:
# 1. Come si distribuiscono i prezzi delle offerte nel settore arredamento?
# 2. Qual è il livello di competizione nelle gare? (numero di offerte per gara)
# 3. Quali fattori distinguono le offerte vincenti da quelle non vincenti?
#
# DATASET:
# Dati provenienti da TED (Tenders Electronic Daily) - database europeo 
# degli appalti pubblici. Filtrati per codici CPV relativi a mobili.
# Fonte: https://opentender.eu/
#
# ============================================================================

# ----------------------------------------------------------------------------
# 0. SETUP - Caricamento librerie
# ----------------------------------------------------------------------------

library(dplyr)    # Per manipolazione dati (filter, select, mutate, etc.)
library(ggplot2)  # Per visualizzazioni grafiche
library(readr)    # Per leggere file CSV

# Imposta la working directory dove si trovano i dati
setwd("~/Documents/Computing fundamentals/workspace esame/data-all-csv")

# Disattiva notazione scientifica per numeri più leggibili
options(scipen = 999)

# ----------------------------------------------------------------------------
# 1. CARICAMENTO E PULIZIA DEI DATI
# ----------------------------------------------------------------------------

# Definizione dei codici CPV (Common Procurement Vocabulary) per il settore mobili
# CPV è un sistema di classificazione europeo per gli appalti pubblici
cpv_mobili <- c(
  "39100000",  # Mobili in generale
  "39110000",  # Sedute e sedie
  "39130000",  # Mobili per ufficio
  "39140000",  # Mobili domestici
  "39150000"   # Mobili vari (scuole, ospedali, etc.)
)

# Leggo i dati del 2022 (anno con buon volume di dati)
cat("Caricamento dati in corso...\n")

# Colonne che ci interessano per l'analisi
# NOTA: il file è in formato FLAT - ogni riga può contenere info su
# tender, lot, bid, buyer e bidder annidati insieme
colonne_utili <- c(
  "tender_id",              # ID della gara
  "tender_mainCpv",         # Codice CPV principale
  "tender_country",         # Paese della gara
  "tender_year",            # Anno della gara
  "lot_lotId",              # ID del lotto
  "lot_validBidsCount",     # Numero offerte valide ricevute
  "bid_row_nr",             # Numero riga bid (per identificare bid unici)
  "bid_price_EUR",          # Prezzo dell'offerta in EUR
  "bid_isWinning",          # L'offerta ha vinto? (TRUE/FALSE)
  "buyer_country",          # Paese dell'acquirente
  "bidder_country",         # Paese dell'offerente
  "publication_row_nr"      # Numero pubblicazione (per filtrare duplicati)
)

# Carico il dataset 2022 
# Nota: read_csv2 usa il punto e virgola (;) come separatore - standard europeo
dati <- read_csv2("data-all-2022.csv", 
                  col_select = all_of(colonne_utili),
                  show_col_types = FALSE)

cat("Righe totali caricate:", nrow(dati), "\n")

# Converto bid_price_EUR in numerico (potrebbe essere letto come carattere)
# Il formato europeo usa la virgola come separatore decimale
dati$bid_price_EUR <- as.numeric(gsub(",", ".", dati$bid_price_EUR))

# Filtro solo le gare relative ai mobili (CPV che iniziano con 391)
dati_mobili <- dati %>%
  filter(substr(tender_mainCpv, 1, 3) == "391")

cat("Righe filtrate per settore mobili:", nrow(dati_mobili), "\n")

# ----------------------------------------------------------------------------
# 1b. PULIZIA DUPLICATI - Gestione struttura FLAT del file
# ----------------------------------------------------------------------------
# Il file contiene righe duplicate per:
# 1. Pubblicazioni multiple dello stesso tender (aggiornamenti)
# 2. Bidder multipli per lo stesso bid (consorzi)
# Filtriamo per ottenere dati puliti

# Step 1: Teniamo solo l'ultima pubblicazione per ogni tender
dati_mobili <- dati_mobili %>%
  group_by(tender_id) %>%
  filter(publication_row_nr == max(publication_row_nr)) %>%
  ungroup()

cat("Righe dopo filtro ultima pubblicazione:", nrow(dati_mobili), "\n")

# Step 2: Per l'analisi prezzi, prendiamo un record per ogni bid unico
# (evita duplicati da bidder multipli)
dati_bid_unici <- dati_mobili %>%
  filter(!is.na(bid_row_nr)) %>%
  distinct(tender_id, lot_lotId, bid_row_nr, .keep_all = TRUE)

cat("Bid unici:", nrow(dati_bid_unici), "\n")

# Verifica conteggi entità
cat("\n--- VERIFICA ENTITÀ UNICHE ---\n")
cat("Tender unici:", n_distinct(dati_mobili$tender_id), "\n")
cat("Lot unici:", n_distinct(dati_mobili$lot_lotId, na.rm = TRUE), "\n")
cat("Bid unici:", nrow(dati_bid_unici), "\n")

# ----------------------------------------------------------------------------
# 2. ESPLORAZIONE INIZIALE DEI DATI
# ----------------------------------------------------------------------------

# Vediamo la struttura del dataset (bid unici)
cat("\n--- STRUTTURA DEL DATASET BID UNICI ---\n")
str(dati_bid_unici)

# Statistiche descrittive delle variabili numeriche
cat("\n--- STATISTICHE DESCRITTIVE ---\n")

# Statistiche sul prezzo delle offerte (usando bid unici)
cat("\nPrezzo offerte (EUR):\n")
summary(dati_bid_unici$bid_price_EUR)

# Quanti valori mancanti abbiamo?
cat("\n--- VALORI MANCANTI ---\n")
cat("Bid senza prezzo:", sum(is.na(dati_bid_unici$bid_price_EUR)), "\n")
cat("Bid con prezzo:", sum(!is.na(dati_bid_unici$bid_price_EUR)), "\n")

# ----------------------------------------------------------------------------
# 3. PULIZIA DEI DATI PER ANALISI PREZZI
# ----------------------------------------------------------------------------

# Uso dati_bid_unici per evitare duplicati nell'analisi prezzi
# Rimuovo righe con prezzo mancante o nullo
dati_prezzi <- dati_bid_unici %>%
  filter(!is.na(bid_price_EUR) & bid_price_EUR > 0) %>%
  filter(bid_price_EUR < 10000000)  # Rimuovo outlier estremi (>10M EUR)

cat("\nBid con prezzo valido per analisi:", nrow(dati_prezzi), "\n")

# ----------------------------------------------------------------------------
# 4. ANALISI 1: DISTRIBUZIONE DEI PREZZI DELLE OFFERTE
# ----------------------------------------------------------------------------

cat("\n=== ANALISI 1: DISTRIBUZIONE PREZZI ===\n")

# Misure di centralità
media_prezzo <- mean(dati_prezzi$bid_price_EUR)
mediana_prezzo <- median(dati_prezzi$bid_price_EUR)

cat("Media prezzo offerte:", round(media_prezzo, 2), "EUR\n")
cat("Mediana prezzo offerte:", round(mediana_prezzo, 2), "EUR\n")

# Misure di dispersione
sd_prezzo <- sd(dati_prezzi$bid_price_EUR)
iqr_prezzo <- IQR(dati_prezzi$bid_price_EUR)

cat("Deviazione standard:", round(sd_prezzo, 2), "EUR\n")
cat("Range interquartile (IQR):", round(iqr_prezzo, 2), "EUR\n")

# GRAFICO 1: Istogramma della distribuzione prezzi (fino a 100k EUR)
ggplot(dati_prezzi %>% filter(bid_price_EUR < 100000), 
       aes(x = bid_price_EUR)) +
  geom_histogram(fill = "steelblue", color = "white", bins = 30) +
  geom_vline(aes(xintercept = mediana_prezzo), 
             color = "red", linetype = "dashed", linewidth = 1) +
  labs(
    title = "Distribuzione dei Prezzi delle Offerte",
    subtitle = "Settore Arredamento - Gare < 100.000 EUR",
    x = "Prezzo Offerta (EUR)",
    y = "Frequenza"
  ) +
  annotate("text", x = mediana_prezzo + 5000, y = Inf, 
           label = paste("Mediana:", round(mediana_prezzo, 0), "EUR"),
           vjust = 2, color = "red")

ggsave("grafico1_distribuzione_prezzi.png", width = 8, height = 6)

# GRAFICO 2: Boxplot dei prezzi
ggplot(dati_prezzi %>% filter(bid_price_EUR < 500000), 
       aes(y = bid_price_EUR)) +
  geom_boxplot(fill = "lightblue", color = "darkblue") +
  coord_flip()+
  labs(
    title = "Boxplot dei Prezzi delle Offerte",
    subtitle = "Settore Arredamento",
    y = "Prezzo Offerta (EUR)"
  )

ggsave("grafico2_boxplot_prezzi.png", width = 6, height = 8)

# ----------------------------------------------------------------------------
# 5. ANALISI 2: LIVELLO DI COMPETIZIONE
# ----------------------------------------------------------------------------

cat("\n=== ANALISI 2: COMPETIZIONE NELLE GARE ===\n")

# Calcolo il numero di offerte per ogni lotto usando bid unici
# Evito duplicati contando bid_row_nr distinti per lot
competizione <- dati_bid_unici %>%
  filter(!is.na(lot_lotId)) %>%
  group_by(tender_id, lot_lotId) %>%
  summarise(n_offerte = n_distinct(bid_row_nr), .groups = "drop")

# Statistiche sulla competizione
cat("Numero medio offerte per lotto:", 
    round(mean(competizione$n_offerte), 2), "\n")
cat("Mediana offerte per lotto:", 
    median(competizione$n_offerte), "\n")
summary(competizione$n_offerte)

# Tabella di frequenza
tabella_competizione <- table(competizione$n_offerte)
cat("\nDistribuzione numero offerte:\n")
print(head(tabella_competizione, 10))

# GRAFICO 3: Distribuzione del numero di offerte per lotto
ggplot(competizione %>% filter(n_offerte <= 15), 
       aes(x = factor(n_offerte))) +
  geom_bar(fill = "coral", color = "darkred") +
  labs(
    title = "Numero di Offerte per Lotto",
    subtitle = "Livello di competizione nelle gare di arredamento",
    x = "Numero di Offerte",
    y = "Conteggio Lotti"
  )

ggsave("grafico3_competizione.png", width = 8, height = 6)

# ----------------------------------------------------------------------------
# 6. ANALISI 3: DISTRIBUZIONE PREZZI PER PAESE
# ----------------------------------------------------------------------------

cat("\n=== ANALISI 3: PREZZI PER PAESE ===\n")

# Preparo i dati per il confronto tra paesi
dati_per_paese <- dati_prezzi %>%
  filter(!is.na(tender_country))

# Calcolo statistiche per paese
statistiche_paese <- dati_per_paese %>%
  group_by(tender_country) %>%
  summarise(
    n = n(),
    media = mean(bid_price_EUR),
    mediana = median(bid_price_EUR),
    deviazione_std = sd(bid_price_EUR)
  ) %>%
  arrange(desc(n))

cat("\nStatistiche per paese:\n")
print(statistiche_paese)

# GRAFICO 4: Boxplot confronto prezzi per paese
ggplot(dati_per_paese %>% filter(bid_price_EUR < 100000), 
       aes(x = tender_country, y = bid_price_EUR, fill = tender_country)) +
  geom_boxplot(alpha = 0.7) +
  labs(
    title = "Distribuzione Prezzi per Paese",
    subtitle = "Settore Arredamento - Gare < 100.000 EUR",
    x = "Paese",
    y = "Prezzo Offerta (EUR)"
  ) +
  theme(legend.position = "none")

ggsave("grafico4_vincenti_vs_non_vincenti.png", width = 8, height = 6)

# ----------------------------------------------------------------------------
# 7. ANALISI 4: DISTRIBUZIONE GEOGRAFICA
# ----------------------------------------------------------------------------

cat("\n=== ANALISI 4: ANALISI PER PAESE ===\n")

# Conteggio gare per paese
gare_per_paese <- dati_mobili %>%
  filter(!is.na(tender_country)) %>%
  group_by(tender_country) %>%
  summarise(n_gare = n_distinct(tender_id)) %>%
  arrange(desc(n_gare)) %>%
  head(10)  # Top 10 paesi

cat("\nTop 10 paesi per numero di gare:\n")
print(gare_per_paese)

# GRAFICO 5: Barplot paesi
ggplot(gare_per_paese, 
       aes(x = reorder(tender_country, n_gare), y = n_gare)) +
  geom_col(fill = "steelblue") +
  coord_flip() +
  labs(
    title = "Numero di Gare per Paese",
    subtitle = "Top 10 paesi - Settore Arredamento",
    x = "Paese",
    y = "Numero di Gare"
  )

ggsave("grafico5_gare_per_paese.png", width = 8, height = 6)

# ----------------------------------------------------------------------------
# 8. ANALISI 5: RELAZIONE PREZZO - COMPETIZIONE
# ----------------------------------------------------------------------------

cat("\n=== ANALISI 5: PREZZO vs COMPETIZIONE ===\n")

# Aggiungo il numero di offerte ai dati prezzi usando il calcolo fatto prima
# Preparo i dati filtrati
dati_per_join <- dati_prezzi %>% filter(!is.na(lot_lotId))

# Uso left_join con join_by() - sintassi corretta per dplyr recente
analisi_relazione <- left_join(dati_per_join, competizione, 
                                join_by(tender_id, lot_lotId))

# Filtro per l'analisi
analisi_relazione <- analisi_relazione %>%
  filter(!is.na(n_offerte) & n_offerte > 0) %>%
  filter(bid_price_EUR < 500000)  # Limito per visualizzazione

# Correlazione
correlazione <- cor(analisi_relazione$n_offerte, 
                    analisi_relazione$bid_price_EUR, 
                    use = "complete.obs")
cat("Correlazione tra n. offerte e prezzo:", round(correlazione, 3), "\n")

# GRAFICO 6: Scatterplot prezzo vs numero offerte
ggplot(analisi_relazione %>% filter(n_offerte <= 10), 
       aes(x = n_offerte, y = bid_price_EUR)) +
  geom_point(alpha = 0.3, color = "darkblue") +
  geom_smooth(method = "lm", color = "red", se = TRUE) +
  labs(
    title = "Relazione tra Prezzo e Numero di Offerte",
    subtitle = paste("Correlazione:", round(correlazione, 3)),
    x = "Numero di Offerte nel Lotto",
    y = "Prezzo Offerta (EUR)"
  )

ggsave("grafico6_prezzo_vs_competizione.png", width = 8, height = 6)

# ----------------------------------------------------------------------------
# 9. CONCLUSIONI
# ----------------------------------------------------------------------------

cat("\n")
cat("============================================================================\n")
cat("                           CONCLUSIONI\n")
cat("============================================================================\n")
cat("\n")
cat("1. DISTRIBUZIONE PREZZI:\n")
cat("   - La distribuzione è fortemente asimmetrica a destra (positiva skewness)\n")
cat("   - La maggior parte delle offerte è sotto i 50.000 EUR\n")
cat("   - Mediana:", round(mediana_prezzo, 0), "EUR\n")
cat("\n")
cat("2. COMPETIZIONE:\n")
cat("   - La maggior parte dei lotti riceve una sola offerta\n")
cat("   - Media offerte per lotto:", round(mean(competizione$n_offerte), 1), "\n")
cat("\n")
cat("3. PREZZI PER PAESE:\n")
cat("   - I prezzi variano significativamente tra i paesi\n")
cat("   - La Spagna domina il mercato ma ha prezzi medi alti\n")
cat("\n")
cat("4. GEOGRAFIA:\n")
cat("   - I paesi con più gare sono:", 
    paste(head(gare_per_paese$tender_country, 3), collapse = ", "), "\n")
cat("\n")
cat("5. CORRELAZIONE PREZZO-COMPETIZIONE:\n")
cat("   - Correlazione:", round(correlazione, 2), "\n")
if(correlazione < 0) {
  cat("   - Correlazione debole negativa: lotti con più competizione tendono\n")
  cat("     ad avere prezzi leggermente più bassi (maggiore concorrenza)\n")
} else {
  cat("   - Correlazione positiva: gare con più competizione tendono ad avere\n")
  cat("     prezzi più alti (probabilmente gare più grandi attirano più offerte)\n")
}
cat("\n")
cat("============================================================================\n")
