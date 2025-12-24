# PROGETTO R - COMPUTING FUNDAMENTALS
# Analisi degli Appalti Pubblici Europei nel Settore Mobili

library(dplyr)
library(ggplot2)
library(readr)

# Imposto la directory di lavoro dove si trovano i dati
setwd("~/Documents/Computing fundamentals/workspace esame/data-all-csv")

# Disattivo la notazione scientifica per rendere i numeri più leggibili
# Esempio: 1000000 invece di 1e+06
options(scipen = 999)

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

# Filtro per codici CPV del settore mobili
# La funzione substr() estrae i primi 3 caratteri del codice CPV
dati_mobili <- filter(dati, substr(tender_mainCpv, 1, 3) == "391")

cat("Righe filtrate per settore mobili:", nrow(dati_mobili), "\n")

# GESTIONE DEI DUPLICATI

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

# Filtro offerte con prezzo valido (positivo e non outlier estremi)
dati_prezzi <- filter(dati_offerte, 
  !is.na(bid_price_EUR) & 
  bid_price_EUR > 0 & 
  bid_price_EUR < 5000000)

      

cat("Offerte con prezzo valido:", nrow(dati_prezzi), "\n\n")

# Distribuzione prezzi
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

#PREZZI PER DIMENSIONE DELLA GARA

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

# Analisi competizione
# Calcolo il numero di offerte per ogni lotto usando bid unici
# Evito duplicati contando bid_row_nr distinti per lot
competizione <- dati_mobili %>%
  distinct(lot_lotId, bid_row_nr, .keep_all = TRUE) %>%
  filter(!is.na(lot_lotId)) %>%
  group_by(tender_id, lot_lotId) %>%
  summarise(n_offerte = n_distinct(bid_row_nr), .groups = "drop")

summary(competizione$n_offerte)
table(competizione$n_offerte)

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

# Analisi procedura
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

# Analisi geografia
# Conteggio gare per paese
dati_mobili %>%
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

dati_mobili %>%
  distinct(lot_lotId, bid_row_nr, .keep_all = TRUE) %>%
  filter(bid_isWinning == "yes")%>%
  filter(!is.na(bid_price_EUR))%>%
  group_by(tender_country) %>%
  summarise(
            n_lots = n(),
            overall_value = sum(bid_price_EUR))%>%
  arrange(desc(n_lots)) %>%
  head(10) %>%  # Top 10 paesi
ggplot(aes(x= n_lots, y = overall_value, color = tender_country, size = overall_value))+
  scale_x_log10()+
  scale_y_log10()+
  geom_point()

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

dati_proc %>%
  distinct(lot_lotId, .keep_all = TRUE) %>%
  group_by(tender_procedureType) %>%
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

bids <- dati_mobili %>%
  distinct(lot_lotId, bid_row_nr, .keep_all = TRUE)
table(bids$bid_isWinning)