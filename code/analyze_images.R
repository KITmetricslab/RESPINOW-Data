install.packages(c("dplyr", "imager", "magick", "tesseract", "ISOweek"), dependencies = TRUE)

library(imager)
library(magick)
library(tesseract)
library(ISOweek)
library(dplyr)

#Set tesseract settings
numbers <- tesseract(options = list(tessedit_char_whitelist = "0123456789"))

#' Reads in image for a given path
#' @param PATH The path for the image
#' @param type Type of image (CIMG or MAGICK)
#' @return The loaded image
read_image <- function(PATH, type = "cimg"){
  if (type == "cimg"){
    #Return CIMG object
    image <- load.image(PATH)
  }else{
    #Return magick object
    image <- image_read(PATH)
  }
  return(image)
}

#' Converts image to grayscale
#' @param image The given image
#' @return The grayscale image
convert_to_grayscale <- function(image){
  image_gray <- grayscale(image)
  return(image_gray)
}

#' Get Size of the image
#' @param image The given image
#' @return List including Height and Width of the image
get_image_size <- function(image){
  size <- list("Height" = height(image), "Width" = width(image))
  return(size)
}

#'Calculates position of x-/y-axis from image
#'@param image The given image (grayscale)
#'@return List with two axis positions
get_axis_position <- function(image){
  size <- get_image_size(image)
  image_array <- as.array(image)
  x_range <- c(1: floor(size$Width/2))
  y_range <- c(floor(size$Height/2): size$Height)
  
  #x-axis
  image_subset <- image[,y_range,,]
  x_axis_pos <- y_range[1] + which.min(colSums(image_subset)) - 1
  
  #y-axis
  image_subset <- image[x_range,,,]
  y_axis_pos <- x_range[1] + which.min(rowSums(image_subset)) - 1
  
  axis_position <- list("x" = x_axis_pos, "y" = y_axis_pos)
  return(axis_position)
}

#' Calculates axis tick positions for given axis position
#' @param axis_positions List of axis positions
#' @return List of tick positions
get_tick_position <- function(axis_position){
  tick_position <- list("x" = axis_position$"x" + 1, "y" = axis_position$"y" - 2)
  return(tick_position)
}

#'Gets the tick count and tick positions for both axis
#'@param image The given image (grayscale)
#'@param axis_position List including position of both axis
#'@return List with Tick count and position for each tick
get_ticks <- function(image, axis_position){
  threshold <- 0.1
  size <- get_image_size(image)
  tick_position <- get_tick_position(axis_position)
  image_array <- as.array(image)
  
  #x-axis
  #Restrict dimension on y
  x_subset_range <- c(axis_position$y:(size$Width))
  subset <- image_array[x_subset_range,,,]
  tick_count_x <- length(subset[,tick_position$x][subset[,tick_position$x] < threshold])
  tick_positions_x <- which(subset[,tick_position$x] < threshold) + x_subset_range[1]
  
  #y-axis
  y_subset_range <- c(1:axis_position$x)
  subset <- image_array[,y_subset_range,,]
  tick_count_y <- length(subset[tick_position$y,][subset[tick_position$y,] < threshold])
  tick_positions_y <- which(subset[tick_position$y,] < threshold)
  
  result <- list("x_count" = tick_count_x, "y_count" = tick_count_y, "x_pos" = tick_positions_x,
                 "y_pos" = tick_positions_y)
  return(result)
}

#'Gets the y-axis value for a given image and x_tick
#'@param image The given image (grayscale)
#'@param axis_position The calculated axis position
#'@param x_tick The x_tick to calculate the bar height for
#'@return The value of the bar height
get_single_value <- function(image, axis_position, ticks, x_tick, scale){
  threshold <- 0.99
  size <- get_image_size(image)
  image_array <- as.array(image)
  
  #Take mean over different pixels around tick position
  x_seq <- c((x_tick-1),x_tick, (x_tick+1))
  subset <- image_array[x_seq,c(18:axis_position$x),,]
  subset <- colMeans(subset)
  height_array <- which(subset > threshold)
  bar_height <- height_array[length(height_array)] + 18

  #Deal with fractional heights in between ticks
  tick_larger <- which(ticks$y_pos >= bar_height)[1]
  tick_over <- ticks$y_pos[tick_larger] - bar_height
  if ((scale == 1) || (tick_over == 1)){
    fraction_over <- 0
  }else if ((scale >=2) && (tick_over <= 3)){
    fraction_over <- 0
  }else{
    if (tick_over == 0){
      fraction_over <- 0
    }else{
      tick_smaller <- tick_larger - 1
      tick_dist <- ticks$y_pos[tick_larger] - ticks$y_pos[tick_smaller]
      fraction_over <- (ticks$y_pos[tick_larger] - bar_height)/tick_dist
    }
  }
  value <- (ticks$y_count - tick_larger) + fraction_over
  value <- round(value * scale)
  return(value)
}


#' Obtains the y-axis scale from a given image
#' @param image Image in magicker format
#' @param axis_pos The calculated axis position
#' @param ticks The calculated ticks
#' @return The scale of the axis
get_scale <- function(image_m, axis_pos, ticks){
  #Get axis position and ticks
  length <- axis_pos$y - 27
  geometry <- paste(length, "x120+22", sep = "")
  #Extract numbers from image
  text <- image_m %>% image_crop(geometry) %>% ocr(engine = numbers)
  numbers <- as.numeric(unlist(regmatches(text, gregexpr("[[:digit:]]+", text))))
  #Extract scale
  scale <- numbers[1] / (ticks$y_count - 1)
  
  #Remove errors from ocr image processing
  if (ticks$y_count < 15){
    scale <- 1
  }
  #Remove values smaller 1
  if (scale < 1){
    scale <- 1
  }
  #Remove fractions between 1 and 2
  if ((scale > 1) && (scale < 2)){
    scale <- 2
  }
  #Solve problem with large graphs, 350 is not recognized
  if ((scale > 8) && (scale < 10)){
    scale <- 10
  }
  return(scale)
}

#' Calculates the bar position for the whole image
#' @param image_m Image in magicker format
#' @param image_c Image in cimg format (grayscale)
#' @param axis_position The calculated axis_position
#' @return Array including all bar heights of the graphic
get_whole_image_data <- function(image_m, image_c, axis_position){
  ticks <- get_ticks(image_c, axis_position)
  result_arr <- array(dim = 52)
  scale <- get_scale(image_m, axis_position, ticks)
  
  i <- 1
  for (tick in ticks$x_pos[-1]){
    value <- get_single_value(image_c, axis_position, ticks, tick, scale)
    result_arr[i] <- value
    i <- i+1
  }
  return(result_arr)
}

#' Calculates the bar position for a whole image given its file path
#'@param PATH The file path
#'@return Array including all bar heights of the graphic
get_data_from_path <- function(PATH){
  img_m <- read_image(PATH, type = "magick")
  img_c <- magick2cimg(img_m)
  img_gray <- convert_to_grayscale(img_c)
  axis_pos <- get_axis_position(img_gray)
  data <- get_whole_image_data(img_m, img_gray, axis_pos)
  return(data)
}

#' Converts integer week into the specified string format
#' @param num Week as integer
#' @return Week in needed string format
convert_to_string <- function(num){
  if (num<10){
    return(paste("0",num, sep = ""))
  }else{
    return(as.character(num))
  }
}

#' Gets the Date of the Sunday of the ISOweek
#'  @param year The given year as integer
#'  @param week The given week as string
#'  @return The Date of the Sunday
date_in_week <- function(year, week, weekday = 7){
  w <- paste0(year, "-W", week, "-", weekday)
  return(as.character(ISOweek2date(w)))
}

#' Analyzes images and creates csv for a specified dataset
#' @param year The given year
#' @param week The given week
#' @param file_path The path to the data folder
#' @param n_weeks The number of IsoWeeks the current year has
create_csv <- function(year, week, url, file_path, n_weeks = 52){
  #Pre work
  week_int <- as.integer(week)
  week_list <- sapply(c(40:n_weeks,1:39), FUN = convert_to_string)
  split_length <- n_weeks - 39
  file_name <- paste(date_in_week(year,week,7), "_", output_names[url], sep = "")
  
  # Check disease, RSV does not have data for county DE
  if (substr(url,1,3) == "RSV"){
    counties <- german_counties[-1]
    disease <- "rsv"
  }else{
    counties <- german_counties
    disease <- "influenza"
  }
  
  #Calculate results
  results <- matrix(ncol = 5)
  for (county in names(counties)){
    county_number <- german_counties[county]
    image_url <- paste(url_start, (year-1), "_",(year), "/", week, "/",
                       county_number, "_", url, "_", week, "_", (year-1), year,
                       ".gif", sep = "")
    data <- get_data_from_path(image_url)
    
    #Use for cutting of future values
    if (week_int <= 39){
      week_cutoff <- split_length + week_int
      year_list <- c(rep((year-1),split_length),rep(year,(n_weeks-split_length)))
    }else{
      week_cutoff <- week_int - (40-1)
      year_list <- c(rep((year - 1),split_length),rep(year,(n_weeks-split_length)))
    }
    
    new_data <- cbind(year_list[1:week_cutoff],week_list[1:week_cutoff],
                      rep(county, week_cutoff), rep("00+", week_cutoff), data[1:week_cutoff])
    results <- rbind(results, new_data)
  }
  
  results_df <- data.frame(results[-1,])
  colnames(results_df) <- c("year", "week", "location", "age_group", "value")
  #Calculate date
  results_df$year <- as.integer(results_df$year)
  results_df$value <- as.integer(results_df$value)
  results_df$date <- mapply(FUN = date_in_week, results_df$year, results_df$week)
  
  #Add aggregation from countries for RSV
  if (disease == "rsv"){
    agg_value <- aggregate(value~date, data = results_df, FUN = sum)
    agg_data <- cbind(year_list[1:week_cutoff],week_list[1:week_cutoff],
                      rep("DE", week_cutoff), rep("00+", week_cutoff),
                      agg_value$value, agg_value$date)
    colnames(agg_data) <- c("year", "week", "location", "age_group", "value","date")
    
    results_df <- rbind(results_df, agg_data)
  }
  
  results_df <- results_df[order(results_df$location),]
  results_df <- select(results_df,"date", c("date", "week", "location", "age_group", "value"))
  output_path <- paste(file_path, disease, "/", file_name, ".csv", sep = "")
  write.csv(results_df, output_path, row.names = FALSE)
}
