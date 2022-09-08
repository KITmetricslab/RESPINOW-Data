library(pdftools)
library(stringr)
library(ISOweek)
library(lubridate)

#Set paths
#Path to location of this file
file_path <- ""
#Path to location of folder with csv
csv_path <- ""
#Path to function file
sari_functions <- paste(file_path, "sari_functions.R", sep = "")

#Source functions
source(sari_functions)


#Check for newest data
weeks_available <- gsub(".csv", "", list.files("csv"))
latest_week <- as.integer(substr(weeks_available[length(weeks_available)], 11,12))
date_string <- date2ISOweek(Sys.Date())
current_week <- as.integer(substr(date_string,7,8))

for (week in latest_week:current_week){
  #Download latest file
  if (week < 10){
    week <- paste(0, week, sep = "")
  }
  url <- paste("https://influenza.rki.de/Wochenberichte/2021_2022/2022-",
  week,".pdf",sep = "")
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
  pdf_page_destination <- paste(file_path, file_name, ".pdf", sep = "")
  data <- pdf_text(url)
  page_list <-str_extract(data,
                          "Wöchentliche Anzahl der neu im Krankenhaus aufgenommenen SARI-Fälle")
  page <- as.character(which(is.na(page_list) == FALSE)[1])
  system2(command = "pdftk", args = c(pdf_destination,"cat", page,
                                      "output", pdf_page_destination))
  
  #Convert to svg
  svg_destination <- paste(file_path, file_name, ".svg", sep = "")
  system2("inkscape", args = c("--without-gui", paste("--file=", pdf_page_destination, sep = ""), 
                               paste("--export-plain-svg=", svg_destination, sep = "")))
  
  
  
  #Extract information from svg
  cat("Starting", week, "\n")
  # read in svg:
  svg <- readLines(con = svg_destination)
  
  # get ruler coordinates:
  rulers <- get_rulers(tag = "style=\"fill:#e0e0e0;fill-opacity:1;fill-rule:nonzero;stroke:none\"", 
                       svg = svg)
  
  # read data from coloured lines:
  data_list <- list()
  
  # red = 0-4
  red_line <- get_line(tag = "fill:none;stroke:#ff0000", svg = svg)
  data_list[["00-04"]] <- transform_line(line = red_line, rulers = rulers)
  
  # orange = 5-14
  orange_line <- get_line(tag = "fill:none;stroke:#ff7f00", svg = svg)
  data_list[["05-14"]] <- transform_line(line = orange_line, rulers = rulers)
  
  # yellow = 15-34
  yellow_line <- get_line(tag = "fill:none;stroke:#ffd200", svg = svg)
  data_list[["15-34"]] <- transform_line(line = yellow_line, rulers = rulers)
  
  # green = 35-59
  green_line <- get_line(tag = "fill:none;stroke:#00b000", svg = svg)
  data_list[["35-59"]] <- transform_line(line = green_line, rulers = rulers)
  
  # blue = 60-79
  blue_line <- get_line(tag = "fill:none;stroke:#008bbc", svg = svg)
  data_list[["60-79"]] <- transform_line(line = blue_line, rulers = rulers)
  
  # grey = 80 plus
  grey_line <- get_line(tag = "fill:none;stroke:#808080", svg = svg)
  data_list[["80+"]] <- transform_line(line = grey_line, rulers = rulers)
  
  # get date, week and year:
  week_formatted <- paste("2022-",week, sep = "")
  dates <- get_dates(tag_week = week_formatted, n_weeks = nrow(red_line))
  
  # assemble everything in one data.frame formatted the same way as the existing data in the repo:
  data_frame <- NULL
  
  for(ag in names(data_list)){
    dat_temp <- data.frame(date = dates$date,
                           week = dates$week,
                           location = "DE",
                           age_group = rep(ag, nrow(dates)),
                           value = data_list[[ag]][, "value"])
    if(is.null(data_frame)){
      data_frame <- dat_temp
    }else{
      data_frame <- rbind(data_frame, dat_temp)
    }
  }
  
  # add part with sum over all age groups:
  to_add <- aggregate(value ~ week + location + date, data_frame, FUN = sum)
  to_add$age_group <- "00+"
  to_add <- to_add[ , colnames(data_frame)]
  data_frame <- rbind(data_frame, to_add)
  data_frame$value <- as.integer(round(data_frame$value))
  
  # write out:
  write.csv(data_frame, file = paste0(csv_path,"SARI-", week_formatted, ".csv"), row.names = FALSE)
  
  #Delete created files
  system2("rm", args = c(paste(pdf_destination, pdf_page_destination, svg_destination)))
}



