setwd("/home/johannes/Documents/Projects/hospitalization-nowcast-hub_fork/nowcast_viz_de/")
source("functions.R")
dat <- read.csv("plot_data/2021-11-16_forecast_data.csv", 
                colClasses = c("target_end_date" = "Date",
                               "forecast_date" = "Date"))

path_truth <-   "../data-truth/COVID-19/COVID-19_hospitalizations.csv"
dat_truth <- read.csv(path_truth,
                      colClasses = c(date = "Date"))
dat_truth <- dat_truth[order(dat_truth$date), ]

# get population sizes:
pop <- read.csv("plot_data/population_sizes.csv")

create_table <- function(forecasts, dat_truth, population, model,
                         forecast_date, target_end_date, by = "state",
                         median_or_mean = "median", interval_level = "95%",
                         scale = "absolute", pathogen = "COVID-19", target_type = "hosp"){
  
  bundeslaender <- c("DE" = "Alle (Deutschland)",
                     "DE-BW" = "Baden-Württemberg", 	
                     "DE-BY" = "Bayern", 	
                     "DE-BE" = "Berlin", 	
                     "DE-BB" = "Brandenburg", 	
                     "DE-HB" = "Bremen", 	
                     "DE-HH" = "Hamburg", 	
                     "DE-HE" = "Hessen", 	
                     "DE-MV" = "Mecklenburg-Vorpommern", 	
                     "DE-NI" = "Niedersachsen", 	
                     "DE-NW" = "Nordrhein-Westfalen", 	
                     "DE-RP" = "Rheinland-Pfalz", 	
                     "DE-SL" = "Saarland", 	
                     "DE-SN" = "Sachsen",
                     "DE-ST" = "Sachsen-Anhalt",
                     "DE-SH" = "Schleswig-Holstein", 	
                     "DE-TH" = "Thüringen")
  
  sub <- forecasts[forecasts$target_end_date == target_end_date &
                     forecasts$model == model &
                     forecasts$pathogen == "COVID-19" &
                     forecasts$target_type == target_type, ]
  
  if(by == "state"){
    sub <- subset(sub, age_group == "00+")
  }
  if(by == "age_group"){
    sub <- subset(sub, location == "DE")
  }
  
  # remove columns not needed:
  sub$target_type <- sub$pathogen <- sub$model <- NULL
  
  # choose point nowcast:
  sub$point <- if(median_or_mean == "median"){
    sub$q0.5
  }else{
    sub$mean
  }
  
  # choose lower and upper bound:
  sub$lower <- NA
  if(interval_level == "50%"){
    sub$lower <- sub$q0.25
  }
  if(interval_level == "95%"){
    sub$lower <- sub$q0.025
  }
  
  sub$upper <- NA
  if(interval_level == "50%"){
    sub$upper <- sub$q0.75
  }
  if(interval_level == "95%"){
    sub$upper <- sub$q0.975
  }
  
  # add scaling factor for population:
  sub <- merge(sub, pop, by = c("location", "age_group"))
  
  # apply:
  if(scale == "per 100.000"){
    sub$pop_factor <- 100000/sub$population
  }else{
    sub$pop_factor <- 1
  }
  sub$point <- round(sub$pop_factor*sub$point, 2)
  sub$lower <- round(sub$pop_factor*sub$lower, 2)
  sub$upper <- round(sub$pop_factor*sub$upper, 2)
  
  # create column with point nowcast and interval:
  sub$nowcast <- paste0(sub$point, " (", sub$lower, " - ", sub$upper, ")")
  
  # get truth as of when the nowcast was made:
  truths_forecast_date <- truth_as_of_by_strat(dat_truth, by = by,
                                               forecast_date = forecast_date,
                                               target_end_date = target_end_date)
  colnames(truths_forecast_date)[1:2] <- c("target_end_date", "value_forecast_date")
  # add:
  sub <- merge(sub, truths_forecast_date, by = c("target_end_date", "location", "age_group"))
  # apply population factor
  sub$value_forecast_date <- sub$pop_factor*sub$value_forecast_date
  
  # get truth as of target date (i.e. frozen value):
  truths_target_end_date <- truth_as_of_by_strat(dat_truth, by = by,
                                                 forecast_date = target_end_date,
                                                 target_end_date = target_end_date)
  colnames(truths_target_end_date)[1:2] <- c("target_end_date", "value_target_end_date")
  # apply population factor
  truths_target_end_date$value_target_end_date <- sub$pop_factor*truths_target_end_date$value_target_end_date
  # add:
  sub <- merge(sub, truths_target_end_date, by = c("target_end_date", "location", "age_group"))
  
  # get current truth:
  truths_current <- truth_as_of_by_strat(dat_truth, by = by,
                                         forecast_date = Sys.Date(),
                                         target_end_date = target_end_date)
  colnames(truths_current)[1:2] <- c("target_end_date", "value_current_date")
  # add:
  sub <- merge(sub, truths_current, by = c("target_end_date", "location", "age_group"))
  # apply population factor
  sub$value_current_date <- sub$pop_factor*sub$value_current_date
  
  # nowcasts from seven days ago:
  sub_7days_ago <- forecasts[forecasts$target_end_date == target_end_date - 7 &
                               forecasts$model == model &
                               forecasts$pathogen == "COVID-19" &
                               forecasts$target_type == target_type, ]
  
  if(by == "state"){
    sub_7days_ago <- subset(sub_7days_ago, age_group == "00+")
  }
  if(by == "age_group"){
    sub_7days_ago <- subset(sub_7days_ago, location == "DE")
  }
  # take only point:
  # choose point nowcast:
  sub_7days_ago$nowcast_7days_ago <- if(median_or_mean == "median"){
    sub_7days_ago$q0.5
  }else{
    sub_7days_ago$mean
  }
  sub_7days_ago <- sub_7days_ago[, c("location", "age_group", "nowcast_7days_ago")]
  
  # add:
  sub <- merge(sub, sub_7days_ago, by = c("location", "age_group"))
  # apply population factor:
  sub$nowcast_7days_ago <- sub$pop_factor*sub$nowcast_7days_ago
  
  # compute correction factors:
  sub$correction_factor_forecast_date <- sub$point / sub$value_forecast_date
  sub$correction_factor_target_end_date <- sub$point / sub$value_target_end_date
  
  # compute nowcasted increase over last seven days
  sub$perc_increase_7d <- 100*(sub$point/sub$nowcast_7days_ago - 1)
  
  sub <- sub[, c("location", "age_group", "target_end_date", "nowcast", "perc_increase_7d",
                 "value_forecast_date", "correction_factor_forecast_date",
                 # "value_target_end_date", "correction_factor_target_end_date",
                 "value_current_date")]
  
  sub$perc_increase_7d <- paste0(round(sub$perc_increase_7d, 2), "%")
  sub$correction_factor_forecast_date <- round(sub$correction_factor_forecast_date, 2)
  sub$value_forecast_date <- round(sub$value_forecast_date, 2)
  sub$value_current_date <- round(sub$value_current_date, 2)
  # sub$value_target_end_date <- round(sub$value_target_end_date, 2)
  # sub$correction_factor_target_end_date <- round(sub$correction_factor_target_end_date, 2)
  
  if(by == "state"){
    sub$age_group <- NULL
    sub$location <- bundeslaender[sub$location]
    sub <- sub[order(sub$location), ]
  }
  if(by == "age_group"){
    sub$location <- NULL
  }
  
  return(sub)
}

debug(create_table)
a <- create_table(forecasts = dat, dat_truth = dat_truth, population = pop,
                  by = "age_group",scale = "per 100.000",
                  model = "NowcastHub-MeanEnsemble",forecast_date = as.Date("2021-11-16"),
                  target_end_date = as.Date("2021-11-13"))
data.table(a)


library(shiny)
library(DT)



shinyApp(
  ui = fluidPage(
    DTOutput("table")
  ),
  server = function(input, output, session) {
    coln <- c("Bundesland", "Meldedatum", "Nowcast Stand 2021-11-16 (95%-Intervall)",
              "Veränderung zur Vorwoche (Nowcast)",
              "Datenstand 2021-11-16", "Korrekturfaktor",
              # "Datenstand 2021-11-13", "Korrekturfaktor",
              "Neuester Datenstand (2021-12-07)")
    output$table <- renderDT({
      a %>%
        datatable(colnames = coln, options = list(pageLength = 17))
    })
  }
)
