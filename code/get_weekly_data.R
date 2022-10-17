
# Source functions
source("analyze_images.R")

#Get current week
date_string <- date2ISOweek(Sys.Date())
current_week <- substr(date_string,7,8)
current_year <- as.integer(substr(date_string,1,4))
if (current_week >= 40){
  current_year <- current_year+1
}

#List of urls
urls <- list("Influenza-NRZ-Nachweise" = "VirusDetections",
             "Influenza-NRZ-PosRate" = "PosRate",
             "RSV-NRZ-Nachweise" = "RSV",
             "RSV-NRZ-PosRate" = "RSVPosRate"
)
#List of output names
output_names <- list("VirusDetections" = "VirusDetections",
                     "PosRate" = "AmountTested",
                     "RSV" = "VirusDetections",
                     "RSVPosRate" =  "AmountTested"
)
#Start of url
url_start <- "https://influenza.rki.de/Graphs/"
#List of county identifiers
german_counties <- list("DE" = "00",
                        "DE-BW" = "01",
                        "DE-BY" = "02",
                        "DE-BB-BE" = "03",
                        "DE-HE" = "04",
                        "DE-MV" = "05",
                        "DE-NI-HB" = "06",
                        "DE-NW" = "07",
                        "DE-RP-SL" = "08",
                        "DE-SN" = "09",
                        "DE-ST" = "10",
                        "DE-SH-HH" = "11",
                        "DE-TH" = "12")

#File path for data folder
file_path <- "../data/NRZ/"

#Create CSVs for the different images
for (url in urls){
  create_csv(current_year, current_week, url, file_path)
}


