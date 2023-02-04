install.packages(c("tidyverse", "runner", "lubridate", "ISOweek"), dependencies = TRUE)

library(tidyverse)
library(runner)
library(lubridate)
library(ISOweek)

read_aggregated <- function(path = temp_path) {
  file <- grep("aggregated.csv", list.files(path), value = TRUE)
  read_csv(paste0(path, file), show_col_types = FALSE)
}

get_date <- function(path = temp_path){
  file <- grep("aggregated.csv", list.files(path), value = TRUE)
  substr(file, 1, 10)
}

#Function to transform the data
transform_data <- function(df){
  #Filter df to three diseases
  df <- df %>%
    mutate(
      influenza = infasaisonpos == 2,
      rsv = rsvpos == 2,
      pneumococcal = bakstrepos == 2,
    ) %>%
    select(c(date, influenza, rsv, pneumococcal)
    )
  
  #Aggregate
  df <- df %>%
    group_by(date) %>%
    summarize(
      influenza = sum(influenza),
      rsv = sum(rsv),
      pneumococcal = sum(pneumococcal)
    )
  
  #Pivot
  df <- df %>%
    pivot_longer(
      cols = c(influenza, rsv, pneumococcal),
      names_to = "disease",
      values_to = "value"
    )
  
  #Format
  df <- df %>%
    mutate(
      location = "DE",
      age_group = "00+"
    )
  return(df)
}



#Path to csv
temp_path <- "code/temp/"
csv_path <- "data/RespVir/"

#Print available files
print(list.files(temp_path))

#Disease vector
diseases <- c("influenza", "rsv", "pneumococcal")

#Get data and date for new file
data_aggregated <- read_aggregated()
date <- get_date()

#Transform data
data_transformed <- transform_data(data_aggregated)

#Obtain the time series
for (disease in diseases){
  df_filtered <- data_transformed %>%
    filter(disease == !!disease) %>%
    mutate(week = week(date)) %>%
    select(date, week, location, age_group, value)
  
  path_ts <- paste0(csv_path, disease, "/", date, "_respvir_", disease,  ".csv")
  write_csv(df_filtered, path_ts)
}

#Delete used files
print("Deleting raw files...")
unlink("code/temp", recursive = TRUE)

  

