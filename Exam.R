setwd("~/Documents/Computing fundamentals/workspace esame/ocds_csvs")
library(dplyr)
library(ggplot2)
library(scales)
library(lubridate)

files_list <- list.files(pattern = "\\.csv$", full.names = TRUE)
data <- lapply(files_list, read.csv, stringsAsFactors = FALSE)

# dedup per file e aggiungi source
for (i in seq_along(data)) {
  before <- nrow(data[[i]])
  data[[i]] <- data[[i]] %>%
    distinct(ocid, .keep_all = TRUE)
  data[[i]]$source <- basename(files_list[i])
  after <- nrow(data[[i]])
  cat("Processed:", basename(files_list[i]), "rows:", before, "->", after, "(removed", before - after, ")\n")
}

# rileva conflitti di tipo tra i file
all_cols <- unique(unlist(lapply(data, names)))
conflicts <- list()
for (col in all_cols) {
  classes <- unique(na.omit(unlist(lapply(data, function(df) if (col %in% names(df)) class(df[[col]]) else NA))))
  if (length(classes) > 1) conflicts[[col]] <- classes
}

# risolvi i conflitti coerciando a character e registra le conversioni
conversions <- list()
if (length(conflicts) > 0) {
  for (col in names(conflicts)) {
    old_classes <- conflicts[[col]]
    conversions[[col]] <- old_classes
    data <- lapply(data, function(df) if (col %in% names(df)) { df[[col]] <- as.character(df[[col]]); df } else df)
  }
}

# report
cat("\nConflict report:\n")
if (length(conflicts) == 0) cat("No type conflicts detected.\n") else {
  for (col in names(conflicts)) cat(sprintf("- %s: types = %s -> coerced to character\n", col, paste(conflicts[[col]], collapse = ", ")))
}

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
  mutate(date = ymd(date))

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

conversion <- function(currency, amount)
  rate <- jsonlite::fromJSON("https://api.frankfurter.app/2021-01-01?from="+(currency)+"&to=EUR")$rates$EUR
  return(amount * rate)

  
Distribution <- ggplot(df_filtered, aes(x = source)) +
  geom_bar(fill = "skyblue") +
  labs(title = "Furniture tender Distribution")
print(Distribution)


d <- ggplot(df_filtered, aes(x = tender_value_amount, y = tender_numberOfTenderers)) +
  geom_point (fill = "black") +
  labs(title = "Furniture tender Distribution")+
  scale_x_continuous(breaks = pretty_breaks(n = 7)) 
print(d)







