setwd("~/Documents/Computing fundamentals/workspace esame/ocds_csvs")
library(dplyr)
library(ggplot2)
library(scales)
library(lubridate)

files_list <- list.files(pattern = "main\\.csv$", full.names = TRUE)
data <- lapply(files_list, read.csv, stringsAsFactors = FALSE)

#track source file
for (i in seq_along(data)) {
  data[[i]]$source <- basename(files_list[i])
}

conv_str <- function(column_name, df) {
  if (column_name %in% names(df)) {
    df[[column_name]] <- as.character(df[[column_name]])
  }
  df
}

conv_num <- function(column_name, df) {
  if (column_name %in% names(df)) {
    df[[column_name]] <- as.numeric(gsub("[^0-9eE+\\.-]", "", as.character(df[[column_name]])))
  }
  df
}

conversions <- function(df, to_strings_vec = character(), to_nums_vec = character()) {
  for (col in to_strings_vec) df <- conv_str(col, df)
  for (col in to_nums_vec)    df <- conv_num(col, df)
  df
}


all_cols <- unique(unlist(lapply(data, names)))
to_nums_vec <- c('X_link', 'tender_value_amount')
to_strings_vec <- setdiff(all_cols, to_nums_vec)


data <- lapply(data, function(df)conversions(df, to_strings_vec, to_nums_vec))



# unisci
combined <- bind_rows(data)

combined <- combined %>%
  mutate(
    date = gsub("Z$", "+0000", date),                        # Z -> +0000
    date = gsub("([+-]\\d{2}):(\\d{2})$", "\\1\\2", date),    # +03:00 -> +0300
    date = lubridate::ymd_hms(date, tz = "UTC")               # parse finale
  ) 
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
# sostituisci nella colonna 'source'
combined <- combined %>%
  mutate(source = recode(source, !!!legend))

sum(is.na(combined$tender_value_currency))

combined <- combined %>%
  mutate(tender_value_currency = coalesce(
    tender_value_currency,
    tender_minValue_currency,               # usa il nome esatto trovato sopra
    planning_budget_amount_currency
  ))
sum(is.na(combined$tender_value_currency))
cols <- c("tender_minValue_currency", "planning_budget_amount_currency", "tender_numberOfTenderers")
combined <- combined[, !(names(combined) %in% cols)]
combined <- combined %>% rename(currency = tender_value_currency)

#filter for furniture-related tender contenent
cols <- c("tender_title","tender_description","tender_additionalProcurementCategory")
keywords <- c("furniture")
# costruisci pattern (case-insensitive)
pat <- paste(keywords, collapse = "|")

df_filtered <- combined %>%
  filter(grepl(pat,
               paste0(ifelse(is.na(tender_title), "", as.character(tender_title)),
                      " ",
                      ifelse(is.na(tender_description), "", as.character(tender_description))),
               ignore.case = TRUE))

df_filtered <- df_filtered  %>%
  mutate(
    month = lubridate::floor_date(date, unit = "month")  
    # primo giorno del mese
  )

#. rates_needed <- df_filtered %>%
#  select(tender_value_currency, month)
#  rates_needed <- na.omit(rates_needed)
#  cat(nrow(rates_needed), "rows")
#  rates_needed <- unique(rates_needed)
#  cat(nrow(rates_needed), "conversions needed")
#write.csv(rates_needed, "rates_needed.csv", row.names = FALSE)

historic_rates<- read.csv("monthly_fx_long.csv")
historic_rates$date <- ymd(historic_rates$date)
df_filtered$month <- ymd(df_filtered$month)
df_filtered <- left_join(df_filtered, historic_rates, by = c("month"= "date", "currency"="currency") )
df_filtered <- df_filtered %>%
  mutate(
    value_usd = tender_value_amount/rate_units_per_usd
  )

options(scipen = 999)
hist(df_filtered$tender_value_amount)

Distribution <- ggplot(combined, aes(x = source)) +
  geom_bar(fill = "skyblue") +
  labs(title = "Furniture tender Distribution")

print(Distribution)

hist(df_filtered$value_usd, value_usd < 100000 )
Distribution <- ggplot(df_filtered, aes(x = value_usd)) +
  geom_bar(fill = "skyblue") +
  labs(title = "Furniture tender Distribution")
print(Distribution)

d <- ggplot(df_filtered, aes(x = value_usd, y = tender_numberOfTenderers)) +
  geom_point (fill = "black") +
  labs(title = "Furniture tender Distribution")+
  scale_x_continuous(breaks = pretty_breaks(n = 7)) 
print(d)







