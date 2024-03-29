#
#Extract data in the specified format from the svg file
#Week string determines the name of the file and the week/year
get_data_from_svg <- function(svg, week_string){
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
  dates <- get_dates(tag_week = week_string, n_weeks = nrow(red_line))
  
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
  return(data_frame)
}


# extract coordinates of a line from the document
# tag: a code snippet to identify the line *before* the numbers to be extracted (done via colour)
# svg: the svg object
get_line <- function(tag, svg){
  # identify line:
  ind_line <- which(grepl(tag, svg))
  line <- svg[ind_line - 1]
  
  # remove everything which is not a number:
  line <- gsub("                 d=\"m ", "", x = line)
  line <- gsub("\" /><path", "", x = line)
  line <- gsub("m ", "", x = line)
  line <- gsub("h ", "", x = line)
  line <- gsub("l ", "", x = line)
  line <- gsub("\"", "", line)
  
  
  # need to split at tags "H" and "L" and handle the segments separately
  # (H re-sets the horizontal coordinate to an absolute value;
  # L re-sets both coordinates)
  line_segments <- strsplit(line, "H ", fixed = TRUE)[[1]]
  line_segments <- unlist(strsplit(line_segments, "L ", fixed = TRUE))
  
  data_line <- NULL
  end_previous_segment <- NULL
  
  for(i in seq_along(line_segments)){
    dat_temp <- process_line_segment(line_segments[i], end_previous_segment = end_previous_segment)
    end_previous_segment <- dat_temp[nrow(dat_temp), ]
    if(is.null(data_line)){
      data_line <- dat_temp
    }else{
      data_line <- rbind(data_line, dat_temp)
    }
  }
  
  # line <- strsplit(line, split = c(" "), fixed = TRUE)[[1]]
  # # following "h" (=horizontal) there is just one rather than 2 numbers; add 0 for vertical move
  # line[!grepl(",", line)] <- paste0(line[!grepl(",", line)], ",0")
  # 
  # # create return object
  # data_line <- matrix(as.numeric(unlist(strsplit(line, ","))), ncol = 2, byrow = TRUE)
  # # the numbers are actually increments / instructions to move, so need cumsum
  # data_line[, 1] <- cumsum(data_line[, 1])
  # data_line[, 2] <- cumsum(data_line[, 2])
  # colnames(data_line) <- c("x", "y")
  
  return(data_line)
}


process_line_segment <- function(segment, end_previous_segment = NULL){
  # split up:
  segment <- strsplit(segment, split = c(" "), fixed = TRUE)[[1]]
  # need to re-use y coordinate from previous segment if only one starting coordinate.
  # This happens if tag H was used.
  if(!grepl(",", segment[1])){
    if(is.null(end_previous_segment)){
      stop("Only one initial coordinate provided, but end_previous_segment is NULL. Need one of these.")
    } 
    segment[1] <- paste0(segment[1], ",", end_previous_segment[2])
  }
  
  # following "h" (=horizontal) there is just one rather than 2 numbers; add 0 for vertical move
  segment[!grepl(",", segment)] <- paste0(segment[!grepl(",", segment)], ",0")
  
  # create return object
  data_segment <- matrix(as.numeric(unlist(strsplit(segment, ","))), ncol = 2, byrow = TRUE)
  # the numbers are actually increments / instructions to move, so need cumsum
  data_segment[, 1] <- cumsum(data_segment[, 1])
  data_segment[, 2] <- cumsum(data_segment[, 2])
  colnames(data_segment) <- c("x", "y")
  
  return(data_segment)
}

# identify the svg and plot coordinates of grey horizontal rulers
get_rulers <- function(tag, svg, step = 100){
  # identify lines corresponding to rulers:
  inds_rulers <- which(grepl(tag, svg))
  rulers <- svg[inds_rulers - 1]
  
  # function to extract the coordinates fron these lines (x and y values of starting point):
  extract_coord_ruler <- function(txt){
    # occasionally coded with capital letters, no idea why
    txt <- gsub("d=\"M", "d=\"m", txt)
    txt <- gsub(" H ", " h ", txt)
    txt <- strsplit(txt, "d=\"m ", fixed = TRUE)[[1]][2]
    txt <- strsplit(txt, " h ", fixed = TRUE)[[1]][1]
    txt <- strsplit(txt, ",", fixed = TRUE)[[1]]
    Y <- as.numeric(txt)
    return(Y)
  }
  
  # get coordinates
  coords_svg_rulers <- matrix(nrow = length(rulers), ncol = 2)
  for(i in 1:nrow(coords_svg_rulers)){
    coords_svg_rulers[i, ] <- extract_coord_ruler(rulers[i])
  }
  # remove additional lines which may have snuck in by keeping only thise with
  # most common x coordinate:
  tab <- table(coords_svg_rulers[, 1])
  most_common_x <- as.numeric(names(tab)[which.max(tab)])
  coords_svg_rulers <- coords_svg_rulers[coords_svg_rulers[, 1] == most_common_x, ]
  
  # sort and check plausibility:
  coords_svg_rulers <- sort(unique(coords_svg_rulers[, 2]))
  diffs <- diff(coords_svg_rulers)
  if(max(diffs) - min(diffs) > 0.2) warning("Implausible coordinates for horizontal rulers")
  coords_plot_rulers <- seq(from = step, by = step, length.out = length(coords_svg_rulers))
  
  # createreturn object:
  result <- cbind("svg_coordinate" = coords_svg_rulers,
                  "plot_coordinate" = coords_plot_rulers)
  return(result)
}


# transform from svg to plot coordinates using ruler coordinates:
transform_line <- function(line, rulers){
  svg_coordinate <- rulers[, "svg_coordinate"]
  plot_coordinate <- rulers[, "plot_coordinate"]
  
  # figure out linear transformation
  scale <- (max(plot_coordinate) - min(plot_coordinate)) /
    (max(svg_coordinate) - min(svg_coordinate))
  shift <- plot_coordinate[1] - svg_coordinate[1]*scale
  
  # and apply it
  transformed_line <- line*NA
  transformed_line[, 1] <- 1:nrow(line)
  transformed_line[, 2] <- shift + scale*line[, 2]
  colnames(transformed_line) <- c("time", "value")
  
  return(transformed_line)
}

get_dates <- function(tag_week, n_weeks){
  year <- as.numeric(strsplit(tag_week, "-", fixed = TRUE)[[1]][1])
  week <- as.numeric(strsplit(tag_week, "-", fixed = TRUE)[[1]][2])
  
  # determine Sunday of the week in the tag:
  sundays0 <- seq(from = as.Date("2017-01-01"), by = 7, 
                  length.out = 52*(year - 2017 + 3))
  weeks0 <- lubridate::isoweek(sundays0)
  years0 <- lubridate::isoyear(sundays0)
  this_sunday <- sundays0[paste(years0, weeks0, sep = "-") == gsub("-0", "-", tag_week)]
  
  # generate sequence of desired length leading up to that date:
  sundays <- seq(from = this_sunday - 7*(n_weeks - 1), by = 7, length.out = n_weeks)
  weeks <- lubridate::isoweek(sundays)
  years <- lubridate::isoyear(sundays)
  
  if(weeks[1] != 40) warning("Unexpected result: Weeks do not start with 40.")
  
  return(data.frame(date = sundays,
                    week = weeks,
                    year = years))
}