# =============================================================================
#                    PROGETTO R - COMPUTING FUNDAMENTALS
#              Analisi degli Appalti Pubblici Europei nel Settore Mobili
# =============================================================================
#
# DOMANDE DI RICERCA:
# 1. Come variano i prezzi in base alla dimensione della gara?
# 2. Esistono differenze significative tra tipi di procedura?
# 3. Quali paesi dominano il mercato e con quali prezzi?
# 4. Esiste correlazione tra competizione e prezzi?
#
# DATASET: European Public Procurement Data 2022 (OpenTender/TED)
# Filtrato per settore arredamento (codici CPV 391*)
#
# =============================================================================


# -----------------------------------------------------------------------------
# SEZIONE 1: SETUP E CARICAMENTO LIBRERIE
# -----------------------------------------------------------------------------
# Carichiamo le librerie necessarie per l'analisi:
# - dplyr: manipolazione dati (filter, select, mutate, group_by, summarise)
# - ggplot2: creazione grafici
# - readr: lettura file CSV

library(dplyr)
library(ggplot2)
library(readr)

# Imposto la directory di lavoro dove si trovano i dati
setwd("~/Documents/Computing fundamentals/workspace esame/data-all-csv")

# Disattivo la notazione scientifica per rendere i numeri più leggibili
# Esempio: 1000000 invece di 1e+06
options(scipen = 999)


# -----------------------------------------------------------------------------
# SEZIONE 2: CARICAMENTO E PREPARAZIONE DEI DATI
# -----------------------------------------------------------------------------
# Il dataset contiene milioni di righe. Selezioniamo solo le colonne necessarie
# per velocizzare il caricamento e ridurre l'uso di memoria.

# Definisco le colonne che mi servono per l'analisi
colonne_utili <- c(
  "tender_id",              # Identificativo univoco della gara
  "tender_mainCpv",         # Codice CPV (classificazione merceologica)
  "tender_country",         # Paese dove si svolge la gara
  "tender_size",            # Dimensione della gara (SMALL, BELOW, ABOVE threshold)
  "tender_procedureType",   # Tipo di procedura (OPEN, OTHER, etc.)
  "buyer_buyerType",        # Tipo di acquirente pubblico
  "lot_lotId",              # Identificativo del lotto
  "bid_row_nr",             # Numero riga offerta (per identificare offerte uniche)
  "bid_price_EUR",          # Prezzo offerto in Euro
  "publication_row_nr",     # Numero pubblicazione (per gestire aggiornamenti)
  "bid_isWinning"           # Indica se l'offerta è vincente
)

# Carico i dati del 2022
# read_csv2() usa il punto e virgola come separatore (standard europeo)
cat("Caricamento dati in corso...\n")

dati <- read_csv2("data-all-2022.csv", col_select = (colonne_utili))

cat("Righe totali caricate:", nrow(dati), "\n")


# -----------------------------------------------------------------------------
# SEZIONE 3: FILTRAGGIO E PULIZIA DEI DATI
# -----------------------------------------------------------------------------
# Il file contiene gare di tutti i settori. Filtriamo solo quelle relative
# ai mobili usando il codice CPV (Common Procurement Vocabulary).
# I codici che iniziano con "391" identificano il settore arredamento.

# Filtro per codici CPV del settore mobili
# La funzione substr() estrae i primi 3 caratteri del codice CPV
dati_mobili <- filter(dati, substr(tender_mainCpv, 1, 3) == "391")

cat("Righe filtrate per settore mobili:", nrow(dati_mobili), "\n")

# GESTIONE DEI DUPLICATI
# Il dataset ha una struttura "flat": la stessa gara può apparire più volte
# perché contiene aggiornamenti (pubblicazioni successive).
# Teniamo solo l'ultima pubblicazione per ogni gara.

dati_mobili <- dati_mobili %>%
  group_by(tender_id) %>%
  filter(publication_row_nr == max(publication_row_nr)) %>%
  ungroup()

cat("Righe dopo rimozione duplicati:", nrow(dati_mobili), "\n")

# Creiamo un dataset con offerte uniche (senza duplicati da bidder multipli)
# distinct() rimuove le righe duplicate basandosi sulle colonne specificate
dati_offerte <- dati_mobili %>%
  filter(!is.na(bid_row_nr)) %>%
  distinct(tender_id, lot_lotId, bid_row_nr, .keep_all = TRUE)

cat("Offerte uniche:", nrow(dati_offerte), "\n")

# Converto il prezzo in formato numerico
# gsub() sostituisce la virgola con il punto per il formato decimale
dati_offerte$bid_price_EUR <- as.numeric(gsub(",", ".", dati_offerte$bid_price_EUR))


# -----------------------------------------------------------------------------
# SEZIONE 4: STATISTICHE DESCRITTIVE
# -----------------------------------------------------------------------------
# Calcoliamo le principali misure di centralità e dispersione per i prezzi.


# Filtro offerte con prezzo valido (positivo e non outlier estremi)
dati_prezzi <- filter(dati_offerte, 
                      !is.na(bid_price_EUR) & 
                      bid_price_EUR > 0 & 
                      bid_price_EUR < 5000000)

cat("Offerte con prezzo valido:", nrow(dati_prezzi), "\n\n")

# MISURE DI CENTRALITÀ
# mean() calcola la media aritmetica
# median() calcola la mediana (valore centrale)

# MISURE DI DISPERSIONE
# sd() calcola la deviazione standard ma qui non ha senso
# IQR() calcola il range interquartile (Q3 - Q1)
# range() restituisce minimo e massimo

summary(dati_prezzi$bid_price_EUR)


ggplot(dati_prezzi %>% filter(bid_price_EUR < 100000), 
       aes(x = bid_price_EUR)) +
  geom_histogram(fill = "steelblue", color = "white", bins = 30) +
  labs(
    title = "Distribuzione dei Prezzi delle Offerte",
    subtitle = "Settore Arredamento - Gare < 100.000 EUR",
    x = "Prezzo Offerta (EUR)",
    y = "Frequenza"
  ) 

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

# -----------------------------------------------------------------------------
# SEZIONE 5: ANALISI 1 - PREZZI PER DIMENSIONE DELLA GARA
# -----------------------------------------------------------------------------
# La variabile tender_size classifica le gare in base al valore:
# - SMALL_SCALE: gare di piccolo importo
# - BELOW_THE_THRESHOLD: sotto soglia comunitaria
# - ABOVE_THE_THRESHOLD: sopra soglia comunitaria

cat("\n========== ANALISI 1: PREZZI PER DIMENSIONE GARA ==========\n")

# Filtro solo le gare con dimensione specificata
dati_size <- filter(dati_prezzi, !is.na(tender_size))


# GRAFICO 1: Boxplot prezzi per dimensione gara
# Il boxplot mostra: mediana (linea centrale), IQR (box), e outliers (punti)

ggplot(dati_size, aes(x = tender_size, y = bid_price_EUR, fill = tender_size)) +
  geom_boxplot() +
  ylim(0,100000)+
  labs(title = "Distribuzione Prezzi per Dimensione Gara",
       subtitle = "Scala logaritmica - Settore Arredamento 2022",
       x = "Dimensione Gara",
       y = "Prezzo Offerta (EUR)") +

  theme(legend.position = "none")

ggsave("grafico1_prezzi_per_size.png", width = 10, height = 6)



# -----------------------------------------------------------------------------
# SEZIONE 6: ANALISI 2 - PREZZI PER TIPO DI PROCEDURA
# -----------------------------------------------------------------------------
# La variabile tender_procedureType indica come viene gestita la gara:
# - OPEN: procedura aperta (tutti possono partecipare)
# - OTHER: altre procedure semplificate
# - APPROACHING_BIDDERS: invito diretto a fornitori

table(dati_prezzi$tender_procedureType)
# Filtro procedure più comuni (almeno 50 osservazioni)
dati_proc <- filter(dati_prezzi, !is.na(tender_procedureType))

stats_proc <- dati_proc %>%
  group_by(tender_procedureType) %>%
  summarise(
    n = n(),
    media = round(mean(bid_price_EUR), 0),
    mediana = round(median(bid_price_EUR), 0)
  ) %>%
  filter(n >= 50) %>%
  arrange(desc(n))

cat("\nStatistiche per tipo procedura:\n")
print(stats_proc)

# GRAFICO 2: Boxplot prezzi per tipo procedura
# Filtro solo le procedure principali per leggibilità
procedure_principali <- c("OPEN", "OTHER", "APPROACHING_BIDDERS", "MINITENDER")

ggplot(filter(dati_proc, tender_procedureType %in% procedure_principali),
       aes(x = tender_procedureType, y = bid_price_EUR, fill = tender_procedureType)) +
  geom_boxplot() +
  ylim(5000,NA) +
  scale_y_log10(labels = scales::comma) +
  labs(title = "Distribuzione Prezzi per Tipo di Procedura",
       subtitle = "Scala logaritmica - Settore Arredamento 2022",
       x = "Tipo Procedura",
       y = "Prezzo Offerta (EUR)") +
  theme_minimal() +
  theme(legend.position = "none")

ggsave("grafico2_prezzi_per_procedura.png", width = 10, height = 6)
cat("\nGrafico salvato: grafico2_prezzi_per_procedura.png\n")


# -----------------------------------------------------------------------------
# SEZIONE 7: ANALISI 3 - DISTRIBUZIONE GEOGRAFICA
# -----------------------------------------------------------------------------
# Analizziamo quali paesi hanno più gare e come variano i prezzi.

cat("\n========== ANALISI 3: DISTRIBUZIONE GEOGRAFICA ==========\n")

# Conteggio gare per paese
gare_per_paese <- dati_mobili %>%
  filter(!is.na(tender_country)) %>%
  distinct(tender_id, .keep_all = TRUE) %>%
  group_by(tender_country) %>%
  summarise(n_gare = n()) %>%
  arrange(desc(n_gare)) %>%
  head(10) %>%  # Top 10 paesi
  
ggplot(aes(x = reorder(tender_country, n_gare), y = n_gare)) +
  geom_col(fill = "steelblue") +
  coord_flip() +
  labs(
    title = "Numero di Gare per Paese",
    subtitle = "Top 10 paesi - Settore Arredamento",
    x = "Paese",
    y = "Numero di Gare"
  )

# GRAFICO 4: Boxplot confronto prezzi per paese
ggplot(dati_mobili %>% filter(bid_price_EUR < 100000), 
       aes(x = tender_country, y = bid_price_EUR, fill = tender_country)) +
  geom_boxplot(alpha = 0.7) +
  labs(
    title = "Distribuzione Prezzi per Paese",
    subtitle = "Settore Arredamento - Gare < 100.000 EUR",
    x = "Paese",
    y = "Prezzo Offerta (EUR)"
  ) +
  theme(legend.position = "none")



# -----------------------------------------------------------------------------
# SEZIONE 8: ANALISI 4 - CORRELAZIONE PREZZO E COMPETIZIONE
# -----------------------------------------------------------------------------
# Calcoliamo il numero di offerte per ogni lotto e verifichiamo se esiste
# una correlazione con il prezzo delle offerte.

cat("\n========== ANALISI 4: CORRELAZIONE PREZZO-COMPETIZIONE ==========\n")

cat("\n=== ANALISI 2: COMPETIZIONE NELLE GARE ===\n")

# Calcolo il numero di offerte per ogni lotto usando bid unici
# Evito duplicati contando bid_row_nr distinti per lot
competizione <- dati_mobili %>%
  distinct(lot_lotId, bid_row_nr, .keep_all = TRUE) %>%
  filter(!is.na(lot_lotId)) %>%
  group_by(tender_id, lot_lotId) %>%
  summarise(n_offerte = n_distinct(bid_row_nr), .groups = "drop")

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

# GRAFICO 4: Scatterplot con linea di regressione
# geom_point() crea lo scatterplot
# geom_smooth(method = "lm") aggiunge la retta di regressione lineare

ggplot(filter(analisi_corr, n_offerte <= 10 & bid_price_EUR < 200000),
       aes(x = n_offerte, y = bid_price_EUR)) +
  geom_point(alpha = 0.3, color = "darkblue") +
  geom_smooth(method = "lm", color = "red", se = TRUE) +
  labs(title = "Relazione tra Competizione e Prezzo",
       subtitle = paste("Correlazione:", round(correlazione, 3)),
       x = "Numero di Offerte nel Lotto",
       y = "Prezzo Offerta (EUR)") +
  theme_minimal()

ggsave("grafico4_correlazione.png", width = 10, height = 6)
cat("\nGrafico salvato: grafico4_correlazione.png\n")


# -----------------------------------------------------------------------------
# SEZIONE 9: ANALISI 5 - TIPO DI ACQUIRENTE
# -----------------------------------------------------------------------------
# Analizziamo come variano i prezzi in base al tipo di ente pubblico.

cat("\n========== ANALISI 5: PREZZI PER TIPO ACQUIRENTE ==========\n")

dati_buyer <- filter(dati_prezzi, !is.na(buyer_buyerType))

stats_buyer <- dati_buyer %>%
  group_by(buyer_buyerType) %>%
  summarise(
    n = n(),
    mediana = round(median(bid_price_EUR), 0)
  ) %>%
  filter(n >= 30) %>%
  arrange(desc(n))

cat("\nStatistiche per tipo acquirente:\n")
print(stats_buyer)

# GRAFICO 5: Boxplot per tipo acquirente
buyer_principali <- c("REGIONAL_AUTHORITY", "PUBLIC_BODY", 
                      "NATIONAL_AUTHORITY", "NATIONAL_AGENCY")

ggplot(filter(dati_buyer, buyer_buyerType %in% buyer_principali),
       aes(x = buyer_buyerType, y = bid_price_EUR, fill = buyer_buyerType)) +
  geom_boxplot() +
  scale_y_log10(labels = scales::comma) +
  labs(title = "Distribuzione Prezzi per Tipo di Acquirente",
       subtitle = "Scala logaritmica - Settore Arredamento 2022",
       x = "Tipo Acquirente",
       y = "Prezzo Offerta (EUR)") +
  theme_minimal() +
  theme(legend.position = "none",
        axis.text.x = element_text(angle = 20, hjust = 1))

ggsave("grafico5_prezzi_per_buyer.png", width = 10, height = 6)
cat("\nGrafico salvato: grafico5_prezzi_per_buyer.png\n")


# -----------------------------------------------------------------------------
# SEZIONE 10: CONCLUSIONI
# -----------------------------------------------------------------------------

cat("\n")
cat("===========================================================================\n")
cat("                              CONCLUSIONI                                  \n")
cat("===========================================================================\n")
cat("\n")

cat("1. DIMENSIONE GARA (tender_size):\n")
cat("   Le gare sopra soglia (ABOVE_THRESHOLD) hanno prezzi mediani ~14 volte\n")
cat("   superiori rispetto alle gare piccole (SMALL_SCALE).\n")
cat("   SMALL: ~17.000 EUR | BELOW: ~24.000 EUR | ABOVE: ~243.000 EUR\n")
cat("\n")

cat("2. TIPO PROCEDURA (tender_procedureType):\n")
cat("   Le procedure MINITENDER hanno i prezzi piu alti (~248.000 EUR mediana)\n")
cat("   mentre OTHER ha prezzi piu bassi (~17.000 EUR).\n")
cat("   Le procedure OPEN mostrano prezzi intermedi (~38.000 EUR).\n")
cat("\n")

cat("3. DISTRIBUZIONE GEOGRAFICA:\n")
cat("   La Spagna domina il mercato con ~50% delle gare (2023 su 4106).\n")
cat("   Francia e Croazia hanno i prezzi piu alti (mediana 67-176k EUR).\n")
cat("   Georgia e Romania hanno prezzi intermedi (9-14k EUR).\n")
cat("\n")

cat("4. CORRELAZIONE PREZZO-COMPETIZIONE:\n")
cat("   Correlazione:", round(correlazione, 3), "\n")
if (correlazione < 0) {
  cat("   Correlazione negativa debole: lotti con piu offerte tendono ad avere\n")
  cat("   prezzi leggermente piu bassi, coerente con la teoria economica\n")
  cat("   (maggiore concorrenza -> prezzi piu competitivi).\n")
}
cat("\n")

cat("5. TIPO ACQUIRENTE:\n")
cat("   Le autorita regionali (REGIONAL_AUTHORITY) fanno piu acquisti (1690)\n")
cat("   con prezzi mediani di ~32.000 EUR.\n")
cat("   Le autorita nazionali (NATIONAL_AUTHORITY) hanno prezzi piu alti (~49.000 EUR).\n")
cat("\n")
cat("===========================================================================\n")
