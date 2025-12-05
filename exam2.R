library(data.table)
library(vroom)
library(dplyr)
library(readr)
library(tictoc)

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
sample <- read_csv2(files, n_max = 20)
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
  "bid_isWinning" = col_character(),
  "cpv_code" = col_character()
)


tic("reading and filtering CSV files")

df_all <- rbindlist(lapply(files, function(f) {
  fread(f, sep = ";",colClasses = col_types, select = c( 
    "tender_id","tender_mainCpv","tender_cpvs","tender_procedureType","lot_lotId",
    "lot_selectionMethod","lot_validBidsCount","lot_estimatedPrice_EUR","bid_row_nr",
    "bid_price_EUR","bid_isWinning","cpv_code"
    ))[tender_mainCpv %in% cpv_keep | grepl(paste(cpv_keep, collapse="|"), tender_cpvs)]
}))


toc()

