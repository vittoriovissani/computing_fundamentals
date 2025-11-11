setwd("~/Documents/Computing fundamentals/workspace esame/ocds_csvs")
library(dplyr)
library(ggplot2)
library(scales)
library(lubridate)

files_list <- list.files(pattern = "\\.csv$", full.names = TRUE)
data <- lapply(files_list, read.csv, stringsAsFactors = FALSE)

conv_str <- function(column_name, df) {
  if (column_name %in% names(df)) {
    df[[column_name]] <- as.character(df[[column_name]])
  }
  df
}

conv_num <- function(column_name, df) {
  if (column_name %in% names(df)) {
    df[[column_name]] <- as.numeric(df[[column_name]])
  }
  df
}

conversions <- function(df, to_strings_vec, to_nums_vec) {
   df <- lapply(df, conv_num, to_strings_vec)
   df <- lapply(df, conv_str, to_nums_vec)
   df
}

to_strings_vec <- c('buyer_id')
to_nums_vec <- c('X_link', 'tender_value_amount')


data <- lapply(data, conversions, to_nums_vec, to_strings_vec)



# unisci
combined <- bind_rows(data)

# riepilogo finale
cat("\nFinal summary:\n")
cat("Files:", length(files_list), "\n")
cat("Rows (merged):", nrow(combined), "\n")
if (length(conversions) > 0) cat("Columns coerced:", paste(names(conversions), collapse = ", "), "\n")

combined <- combined %>%
  mutate(
    # rimuove ogni carattere non numerico eccetto 0-9, ., -, e la notazione scientifica e/E e + (es. 9e+07)
    tender_value_amount = as.numeric(gsub("[^0-9eE+\\.-]", "", as.character(tender_value_amount))),
  ) %>%
  filter(!is.na(tender_value_amount) & !is.na(tender_numberOfTenderers))
combined <- combined %>%
  mutate(
    date = as.character(date),
    date = gsub("Z$", "+0000", date),                        # Z -> +0000
    date = gsub("([+-]\\d{2}):(\\d{2})$", "\\1\\2", date),    # +03:00 -> +0300
    date = lubridate::ymd_hms(date, tz = "UTC")               # parse finale
  ) %>%
  mutate()

  combined <- bind_rows(data)
# df: il tuo data.frame
# cols: vettore di nomi colonna da cercare, es. c("description","title")
# keywords: vettore di parole chiave, es. c("furniture","arred")

cols <- c("tender_title","tender_description","tender_additionalProcurementCategory")
keywords <- c("furniture","meuble")

# costruisci pattern (case-insensitive)
pat <- paste(keywords, collapse = "|")

df_filtered <- combined %>%
  filter(grepl(pat,
               paste0(ifelse(is.na(tender_title), "", as.character(tender_title)),
                      " ",
                      ifelse(is.na(tender_description), "", as.character(tender_description))),
               ignore.case = TRUE))



# legenda
legend <- c(
  "85_main.csv"  = "Ghana",
  "13_main.csv"  = "Kenya",
  "147_main.csv" = "Kenya",
  "156_main.csv" = "Liberia",
  "107_main.csv" = "Nigeria",
  "127_main.csv" = "Nigeria",
  "64_main.csv"  = "Nigeria",
  "3_main.csv"   = "Zambia",
  "130_main.csv" = "Uganda",
  "143_main.csv" = "South Africa",
  "145_main.csv" = "Rwanda",
  "152_main.csv" = "Tanzania",
  "118_main.csv" = "Nigeria",
  "106_main.csv" = "Nigeria",
  "103_main.csv" = "Nigeria",
  "104_main.csv" = "Nigeria",
  "125_main.csv" = "Nigeria",
  "116_main.csv" = "Nigeria",
  "86_main.csv"  = "Nigeria"
)

options(scipen = 999)

# sostituisci nella colonna 'country'
df_filtered <- df_filtered %>%
  mutate(source = recode(source, !!!legend))

rate_needed <- df_filtered %>%
  select(tender_value_currency, date) %>%
  mutate(
    date = lubridate::ymd_hms(as.character(date), tz = "UTC"),  # ensure POSIXct
    date = lubridate::floor_date(date, unit = "month")          # primo giorno del mese
  )

# produce la lista minima di month per currency e salva come csv (YYYY-MM-01)
needed_rates <- rate_needed %>%
  distinct(tender_value_currency, date) %>%
  mutate(month = as.Date(format(date, "%Y-%m-01"))) %>%
  arrange(tender_value_currency, month) %>%
  select(currency = tender_value_currency, month)

write.csv(needed_rates, "needed_rates.csv", row.names = FALSE)

# leggi i rate forniti (month in formato YYYY-MM-01)
rates <- read.csv("provided_rates.csv", stringsAsFactors = FALSE) %>%
  mutate(month = as.Date(month))

# aggancia ai dati originali usando month = primo del mese
df_with_rates <- df_filtered %>%
  mutate(month = as.Date(format(date, "%Y-%m-01"))) %>%
  left_join(rates, by = c("tender_value_currency" = "currency", "month" = "month"))


hist(df_filtered$tender_value_amount)

Distribution <- ggplot(df_filtered, aes(x = source)) +
  geom_bar(fill = "skyblue") +
  labs(title = "Furniture tender Distribution")
print(Distribution)


d <- ggplot(df_filtered, aes(x = tender_value_amount, y = tender_numberOfTenderers)) +
  geom_point (fill = "black") +
  labs(title = "Furniture tender Distribution")+
  scale_x_continuous(breaks = pretty_breaks(n = 7)) 
print(d)







