library(tidyverse)
library(httr)
library(jsonlite)

# HealthTopic ID

r <- GET("http://atlas.ecdc.europa.eu/public/AtlasService/rest/GetHealthTopics") %>% 
  content(as = "text") %>% 
  fromJSON()

health_topics <- r$HealthTopics

# Influenza: 29
# RSV: 71

# DATASET ID

r <- GET("http://atlas.ecdc.europa.eu/public/AtlasService/rest/GetDatasetsForHealthTopic?healthTopicId=71") %>% 
  content(as = "text") %>% 
  fromJSON()

datasets <- r$Datasets

# CURRENT.GENERAL 27
# CURRENT.INFL.WEEKLY 289


## MEASURE ID

r <- GET("http://atlas.ecdc.europa.eu/public/AtlasService/rest/GetIndicatorMeasuresForHealthTopicAndDataset?datasetId=27&healthTopicId=29") %>% 
  content(as = "text") %>% 
  fromJSON()

m <- r$Measures %>% 
  select(Id, Code, Label, Unit)

# Influenza: 621812 SENTINEL.COUNTPOSITIVE


r <- GET("http://atlas.ecdc.europa.eu/public/AtlasService/rest/GetIndicatorMeasuresForHealthTopicAndDataset?datasetId=27&healthTopicId=71") %>% 
  content(as = "text") %>% 
  fromJSON()

m <- r$Measures %>% 
  select(Id, Code, Label, Unit, Type)

# RSV: 621832 RSV_SENTINEL.DETECTION


## POPULATION FOR MEASURE (?)
r <- GET("http://atlas.ecdc.europa.eu/public/AtlasService/rest/GetPopulationForMeasure?measureId=621812") %>% 
  content(as = "text") %>% 
  fromJSON()

# "Influenza virus detections sentinel" (?)


## Reference Region For Measure
r <- GET("http://atlas.ecdc.europa.eu/public/AtlasService/rest/GetReferenceRegionsForMeasure?measureId=621812") %>% 
  content(as = "text") %>% 
  fromJSON()

regions <- r$ReferenceRegions


### GET INFLUENZA DATA

r <- GET(paste0("http://atlas.ecdc.europa.eu/public/AtlasService/rest/GetMeasuresResults?",
                "healthTopicId=29&datasetId=27&measurePopulation=&measureIds=621812&measureTypes=I&timeCodes=&geoCodes=DE")) %>% 
  content(as = "text") %>% 
  fromJSON()

df <- r$MeasureResults


# r <- GET("http://atlas.ecdc.europa.eu/public/AtlasService/rest/GetMeasuresResults?healthTopicId=29&datasetId=289&measurePopulation=&measureIds=621812&measureTypes=I&timeCodes=&geoCodes=DE") %>% 
#   content(as = "text") %>% 
#   fromJSON()
# 
# df2 <- r$MeasureResults


### GET RSV DATA

r <- GET(paste0("http://atlas.ecdc.europa.eu/public/AtlasService/rest/GetMeasuresResults?",
                "healthTopicId=71&datasetId=27&measurePopulation=&measureIds=621832&measureTypes=I&timeCodes=&geoCodes=DE")) %>% 
  content(as = "text") %>% 
  fromJSON()

df_rsv <- r$MeasureResults

