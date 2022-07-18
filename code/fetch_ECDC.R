library(tidyverse)
library(httr)
library(jsonlite)
library(ISOweek)

r <- GET(paste0("http://atlas.ecdc.europa.eu/public/AtlasService/rest/GetMeasuresResults?",
                "healthTopicId=29&",
                "datasetId=27&",
                "measurePopulation=&",
                "measureIds=621812&",
                "measureTypes=I&",
                "timeCodes=&",
                "geoCodes=DE")) %>% 
  content(as = "text") %>% 
  fromJSON()

df1 <- r$MeasureResults


df1 <- df1 %>% 
  mutate(dt = paste0(TimeCode, "-7"),
         date = ISOweek2date(dt),
         value = N
  )  %>% 
  select(date, value) %>% 
  mutate(source = "ECDC")

ggplot(df1, aes(x = date, y = value)) +
  geom_line()



df2 <- read_csv("data/truth/NRZ/influenza/2022-07-03_VirusDetections.csv") %>% 
  filter(location == "DE",
         age_group == "00+") %>% 
  select(date, value) %>% 
  mutate(source = "NRZ")

df <- bind_rows(df1, df2)

ggplot(df, aes(x = date, y = value, color = source)) +
  geom_line()


df <- df1 %>% 
  filter(date < min(df2$date)) %>% 
  bind_rows(df2)

ggplot(df, aes(x = date, y = value, color = source)) +
  geom_line()
