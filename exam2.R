setwd("~/Documents/Computing fundamentals/workspace esame/data-all-csv")
library(dplyr)
library(readr)
library(ggplot2)
library(readr)
library(vroom)
# CPV di interesse: mobili/arredo
cpv_keep <- c(
  "39000000",  # macro mobili
)
cols_keep <- ("id, country, buyer_name, buyer_id, supplier_name, supplier_id, cpv, award_value_eur, award_date, procedure_type, bids_count")

#sample_df <- read_csv2("data-all-2015.csv", n_max = 2000)
#names <- as.character(names(sample_df))

files <- list.files(pattern = "data-all-")

df <- vroom(
  files,
  delim = ";",
  col_types = scheme,
  col_select = c(
    "tender_id", "tender_country", "tender_year", "tender_title",
    "tender_mainCpv", "tender_cpvs", "tender_procedureType",
    "tender_indicator_INTEGRITY_SINGLE_BID", "tender_bidDeadline",
    "tender_awardDecisionDate", "tender_contractSignatureDate",
    "tender_estimatedPrice_EUR", "tender_finalPrice_EUR")
  ) %>% filter((tender_mainCpv %in% cpv_keep))





dfs <- lapply(
  files_list,
  function(f) read_csv2(
    file = f,
    col_select = c(
      "tender_id", "tender_country", "tender_year", "tender_title",
      "tender_mainCpv", "tender_cpvs", "tender_procedureType",
      "tender_indicator_INTEGRITY_SINGLE_BID", "tender_bidDeadline",
      "tender_awardDecisionDate", "tender_contractSignatureDate",
      "tender_estimatedPrice_EUR", "tender_finalPrice_EUR"
    ),
    show_col_types = FALSE,
    n_max = 500
  )
)


df <- bind_rows(dfs)



cpv_keep <- c("39000000")  # i CPV che vuoi tenere



scheme <- vroom::cols(
  tender_id                          = vroom::col_character(),
  tender_country                     = vroom::col_character(),
  tender_year                        = vroom::col_integer(),
  tender_title                       = vroom::col_character(),
  tender_mainCpv                     = vroom::col_character(),   # CPV: stringa
  tender_cpvs                        = vroom::col_character(),
  tender_procedureType               = vroom::col_character(),
  tender_indicator_INTEGRITY_SINGLE_BID = vroom::col_logical(),
  tender_bidDeadline                 = vroom::col_character(),   # o col_date() se formato noto
  tender_awardDecisionDate           = vroom::col_character(),   # idem
  tender_contractSignatureDate       = vroom::col_character(),
  tender_estimatedPrice_EUR          = vroom::col_double(),
  tender_finalPrice_EUR              = vroom::col_double(),
  .default                           = vroom::col_character()
)


dfs <- lapply(files, function(f) {
  read_csv2(
    f,
    col_types  = schema,
    col_select = any_of(c(
      "tender_id","tender_country","tender_year","tender_title",
      "tender_mainCpv","tender_cpvs","tender_procedureType",
      "tender_indicator_INTEGRITY_SINGLE_BID","tender_bidDeadline",
      "tender_awardDecisionDate","tender_contractSignatureDate",
      "tender_estimatedPrice_EUR","tender_finalPrice_EUR"
    )),
    show_col_types = FALSE
  ) |>
    filter(tender_mainCpv %in% cpv_keep) |>
    mutate(source = basename(f))
})

combined <- bind_rows(dfs)
