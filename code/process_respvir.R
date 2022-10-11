install.packages(c("tidyverse", "runner", "lubridate", "ISOweek"), dependencies = TRUE)

library(tidyverse)
library(runner)
library(lubridate)
library(ISOweek)

Sys.setlocale("LC_ALL", "C")

process_respvir <- function(df) {
  df <- df %>%
    mutate(
      influenza = infasaisonpos == 2,
      rsv = rsvpos == 2,
      pneumococcal = bakstrepos == 2
    ) %>%
    select(c(date, influenza, rsv, pneumococcal))

  df <- df %>%
    group_by(date) %>%
    summarize(
      influenza = sum(influenza),
      rsv = sum(rsv),
      pneumococcal = sum(pneumococcal)
    )

  df <- df %>%
    pivot_longer(
      cols = c(influenza, rsv, pneumococcal),
      names_to = "disease",
      values_to = "value"
    )

  df <- df %>%
    group_by(disease) %>%
    mutate(
      value = runner(value,
        k = "7 days",
        idx = date,
        f = function(x) sum(x)
      ),
      weekday = wday(date, label = TRUE)
    ) %>%
    filter(weekday == "Sun")

  df <- df %>%
    ungroup() %>%
    select(date, disease, value)

  df <- df %>%
    mutate(
      location = "DE",
      age_group = "00+"
    )
}

read_latest <- function(disease = "influenza") {
  files <- list.files(paste0("data/RespVir/", disease), full.names = TRUE)
  latest_file <- max(files)
  read_csv(latest_file, show_col_types = FALSE)
}

update_timeseries <- function(df_old, df_new, disease = "influenza") {
  df_new %>%
    filter(disease == !!disease) %>%
    select(-disease) %>%
    bind_rows(df_old) %>%
    group_by(date, location, age_group) %>%
    summarize(value = sum(value)) %>%
    ungroup()
}


df_influenza <- read_latest("influenza")
df_rsv <- read_latest("rsv")
df_pneumococcal <- read_latest("pneumococcal")

files_new <- sort(list.files("code/temp/", pattern = "*respAll_filtered_\\d{4}-\\d{2}-\\d{2}.csv", full.names = TRUE))

for (f in files_new) {
  print(paste0("Processing: ", basename(f)))
  df_new <- read_csv(max(files_new)) %>%
    process_respvir()

  df_influenza <- update_timeseries(df_influenza, df_new, "influenza")
  df_rsv <- update_timeseries(df_rsv, df_new, "rsv")
  df_pneumococcal <- update_timeseries(df_pneumococcal, df_new, "pneumococcal")

  write_csv(df_influenza, paste0("data/RespVir/influenza/", max(df_influenza$date), "_respvir_influenza.csv"))
  write_csv(df_rsv, paste0("data/RespVir/rsv/", max(df_rsv$date), "_respvir_rsv.csv"))
  write_csv(df_pneumococcal, paste0("data/RespVir/pneumococcal/", max(df_pneumococcal$date), "_respvir_pneumococcal.csv"))
}

print("Deleting raw files...")
unlink("code/temp", recursive = TRUE)
