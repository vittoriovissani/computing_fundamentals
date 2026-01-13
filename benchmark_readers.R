# Benchmark rapido: readr::read_csv2 vs readr (col_types) vs data.table::fread

suppressPackageStartupMessages({
  library(readr)
  library(data.table)
})

file_path <- "~/Documents/Computing fundamentals/workspace esame/data-all-csv/data-all-2022.csv"

selected_cols <- c(
  "tender_id",
  "tender_mainCpv",
  "tender_country",
  "tender_size",
  "tender_procedureType",
  "buyer_buyerType",
  "lot_lotId",
  "bid_row_nr",
  "bid_price_EUR",
  "publication_row_nr",
  "bid_isWinning"
)

cat("File:", file_path, "\n")

bench_once <- function(label, expr) {
  gc()
  t <- system.time({
    x <- eval(expr)
  })
  cat(sprintf("%-30s  elapsed: %.3fs\n", label, t[["elapsed"]]))
  invisible(t[["elapsed"]])
}

cat("\n--- warmup (per evitare costi one-off) ---\n")
try(invisible(readLines(file_path, n = 1)), silent = TRUE)

cat("\n--- benchmark (1 run per metodo) ---\n")

# 1) readr default (con col_select)
bench_once("readr::read_csv2 default", quote({
  read_csv2(file_path, col_select = all_of(selected_cols), show_col_types = FALSE)
}))

# 2) readr con tipi espliciti
# Nota: imposto quasi tutto come col_character; parse numerici solo dove serve.
# Nel tuo script poi converti bid_price_EUR, quindi qui restare character e' ok.
col_types_fixed <- cols(
  tender_id = col_character(),
  tender_mainCpv = col_character(),
  tender_country = col_character(),
  tender_size = col_character(),
  tender_procedureType = col_character(),
  buyer_buyerType = col_character(),
  lot_lotId = col_character(),
  bid_row_nr = col_character(),
  bid_price_EUR = col_character(),
  publication_row_nr = col_double(),
  bid_isWinning = col_character()
)

bench_once("readr::read_csv2 col_types", quote({
  read_csv2(file_path,
            col_select = all_of(selected_cols),
            col_types = col_types_fixed)
}))

# 3) data.table fread con select
bench_once("data.table::fread select", quote({
  fread(file_path, sep = ";", select = selected_cols, showProgress = FALSE)
}))

# 4) data.table fread con select + classes
# NB: classes in fread non gestisce formati decimali con virgola automaticamente;
#     per questo lascio bid_price_EUR come character.
classes_fixed <- c(
  tender_id = "character",
  tender_mainCpv = "character",
  tender_country = "character",
  tender_size = "character",
  tender_procedureType = "character",
  buyer_buyerType = "character",
  lot_lotId = "character",
  bid_row_nr = "character",
  bid_price_EUR = "character",
  publication_row_nr = "numeric",
  bid_isWinning = "character"
)

bench_once("data.table::fread classes", quote({
  fread(file_path,
        sep = ";",
        select = selected_cols,
        colClasses = classes_fixed,
        showProgress = FALSE)
}))
