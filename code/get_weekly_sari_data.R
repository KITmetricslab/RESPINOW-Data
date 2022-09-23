install.packages(c("pdftools", "stringr", "ISOweek", "lubridate"), dependencies = TRUE)

library(pdftools)
library(stringr)
library(ISOweek)
library(lubridate)

#Set paths
#Path to location of this file
file_path <- "./code/"
#Path to location of folder with csv
csv_path <- "./data/SARI/"


#Path to function file
sari_functions <- paste(file_path, "sari_functions.R", sep = "")
#Source functions
source(sari_functions)

#Check for newest data
weeks_available <- gsub(".csv", "", list.files(csv_path))
latest_week <- as.integer(substr(weeks_available[length(weeks_available)], 11,12))
date_string <- date2ISOweek(Sys.Date())
current_week <- as.integer(substr(date_string,7,8))
current_year <- as.integer(substr(date_string,1,4))

#Fetch data for all missing weeks
for (week in (latest_week+1):(current_week)){
  #Define week and year as string
  week_string <- paste0(current_year,"-",week)
  #Download latest file
  if (week < 10){
    week <- paste0(0, week)
  }
  url <- paste0("https://influenza.rki.de/Wochenberichte/",(current_year-1),"_",
               current_year,"/",current_year,"-", week,".pdf")
  file_name <- substr(url, start = nchar(url)-10, stop = nchar(url)-4)
  pdf_destination <- paste(file_path, file_name, ".pdf", sep = "")
  tryCatch({
    download.file(url, pdf_destination, mode = "wb")
  },
  error = function(e) {
    print(paste("Week", week, "not available yet."))
    break
  })
    
  #Save specific page
  pdf_page_destination <- paste0(file_path,"selected_page_", file_name, ".pdf")
  data <- pdf_text(pdf_destination)
  page_list <-str_extract(data,
                          "Wöchentliche Anzahl der neu im Krankenhaus aufgenommenen SARI-Fälle")
  page <- as.character(which(is.na(page_list) == FALSE)[1])
  system2(command = "pdftk", args = c(pdf_destination,"cat", page,
                                      "output", pdf_page_destination))
  
  #Convert to svg
  svg_destination <- paste(file_path, file_name, ".svg", sep = "")
  system2("inkscape", args = c(pdf_page_destination, "--export-type=svg",
                               paste0("--export-filename=", svg_destination)))
  
  #Load data and extract csv
  tryCatch(
    {
      svg <- readLines(con = svg_destination)
      data <- get_data_from_svg(svg, week_string)
      write.csv(data, file = paste0(csv_path,"SARI-", week_string, ".csv"), row.names = FALSE)
    },
    error = function(e) {
      print("Data could not be extracted")
    },
    finally = {
      print(paste0("CSV ", week_string, " created successfully!"))
      #Delete created files
      system2("rm", args = c(paste(pdf_destination, pdf_page_destination, svg_destination)))
    }
  )
}



