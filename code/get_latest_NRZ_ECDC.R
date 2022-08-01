library(tidyverse)
library(httr)
library(jsonlite)
library(ISOweek)


### RSV

# Load ECDC data

r <- GET(paste0("http://atlas.ecdc.europa.eu/public/AtlasService/rest/GetMeasuresResults?",
                "healthTopicId=71&",
                "datasetId=27&",
                "measurePopulation=&",
                "measureIds=621832&",
                "measureTypes=I&",
                "timeCodes=&",
                "geoCodes=DE")) %>% 
  content(as = "text") %>% 
  fromJSON()

df1 <- r$MeasureResults

df1 <- df1 %>% 
  filter(str_detect(TimeCode, "W")) %>% 
  mutate(dt = paste0(TimeCode, "-7"),
         date = ISOweek2date(dt),
         value = N
  )  %>% 
  mutate(location = "DE",
         age_group = "00+",
         source = "ECDC") %>% 
  select(location, age_group, date, value, source)


# Load NRZ data

latest_file <- sort(list.files("data/NRZ/rsv/", pattern = "*VirusDetections.csv"), decreasing= TRUE)[1]

df2 <- read_csv(paste0("data/NRZ/rsv/", latest_file)) %>% 
  filter(location == "DE",
         age_group == "00+") %>% 
  mutate(source = "NRZ")


df <- df1 %>% 
  filter(date < min(df2$date)) %>% 
  bind_rows(df2)

# ggplot(df, aes(x = date, y = value, color = source)) +
#   geom_line() +
#   labs(title = "RSV",
#        x = NULL,
#        y = "Cases",
#        color = "Source")

write_csv(df, "data/NRZ/rsv_latest_truth.csv")
