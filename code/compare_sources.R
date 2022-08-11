library(tidyverse)
library(runner)
library(lubridate)
library(ISOweek)

Sys.setlocale("LC_ALL", "C")

# SARI

df1 <- read_csv("data/SARI/SARI-2022-24.csv") %>% 
  filter(stratum == "A00.") %>% 
  select(date, value) %>% 
  mutate(source = "SARI")

ggplot(df1, aes(x = date, y = value)) +
  geom_line()


# RespVir

df_all <- read_csv("data/RespVir/respVir_filtered.csv")

df2 <- df_all %>% 
  select(c(1:6, infasaisonpos)) %>% 
  mutate(influenza = infasaisonpos == 2)

df2 <- df2 %>% 
  mutate (year = format(date, format = "%Y"))

df2 <- df2 %>% 
  group_by(date) %>% 
  summarize(influenza = sum(influenza))

df2 <- df2 %>% 
  pivot_longer(cols = c(influenza),
               names_to = "disease",
               values_to = "value")

df2 <- df2 %>%
  group_by(disease) %>% 
  mutate(value = runner(value,
                           k = "7 days",
                           idx = date,
                           f = function(x) sum(x)),
         weekday = wday(date, label = TRUE)
  ) %>% 
  filter(weekday == "Sun")

df2 <- df2 %>% 
  ungroup() %>% 
  select(date, value) %>% 
  mutate(source = "RespVir")

ggplot(df2, aes(x = date, y = value)) +
  geom_line()


# Survstat

df3 <- read_csv("data/Survstat/latest_truth_seasonal_influenza.csv") %>% 
  filter(location == "DE",
         age_group == "00+") %>% 
  select(date, value) %>% 
  mutate(source = "Survstat")


# NRZ (Nationales Referenzzentrum)

df4 <- read_csv("data/NRZ/influenza/2022-07-03_VirusDetections.csv") %>% 
  filter(location == "DE",
         age_group == "00+") %>% 
  select(date, value) %>% 
  mutate(source = "NRZ")


# Influenza Net (Grippeweb)
library(ISOweek)
df5 <- read_csv("data/InfluenzaNet/DE_incidence.csv")

df5 <- df5 %>% 
  mutate(year = str_sub(yw, 1, 4),
         week = str_sub(yw, 5, 6),
         dt = paste0(year, "-W", week, "-7"),
         date = ISOweek2date(dt),
         value = incidence*1000
  )  %>% 
  select(date, value) %>% 
  mutate(source = "GrippeWeb")


# ECDC

df6 <- read_csv("data/ECDC/ECDC_surveillance_data_Influenza.csv")

df6 <- df6 %>% 
  mutate(dt = paste0(Time, "-7"),
         date = ISOweek2date(dt),
         value = NumValue
  )  %>% 
  select(date, value) %>% 
  mutate(source = "ECDC")

# FluNews
library(readxl)
df7 <- read_excel("data/FluNews/FluNews_SARI.xlsx")

df7 <- df7 %>% 
  filter(Country == "Germany") %>% 
  mutate(dt = paste0(Week, "-7"),
         date = ISOweek2date(dt),
         value = `Number of SARI cases`
  )  %>% 
  select(date, value) %>% 
  mutate(source = "FluNews")

# Combined

df <- bind_rows(df1, df2, df3, df4, df5, df6, df7) %>% 
  filter(date >= "2019-01-01")

ggplot(df, aes(x = date, y = value, colour = source)) +
  geom_line() 

ggplot(df, aes(x = date, y = value, colour = source)) +
  geom_line() +
  #geom_point() +
  scale_y_log10() +
  labs(title = "Influenza",
       x = NULL,
       y = "Cases",
       colour = "Data source") +
  theme_bw()

ggsave("figures/comparison_influenza.png", width = 250, height = 150, unit = "mm", device = "png")    




df0 <- df %>% 
  filter(source %in% c("Survstat", "NRZ", "RespVir", "ECDC")) %>% 
  group_by(source) %>% 
  mutate(value = scale(value))


ggplot(df0, aes(x = date, y = value, colour = source)) +
  geom_line() +
  labs(title = "Influenza",
       x = NULL,
       y = NULL,
       colour = "Data source") +
  theme_bw()

ggsave("figures/comparison_influenza_scaled.png", width = 200, height = 150, unit = "mm", device = "png")    



df0 <- df %>% 
  filter(source %in% c("NRZ", "RespVir", "ECDC"))


ggplot(df0, aes(x = date, y = value, colour = source)) +
  geom_line() +
  # scale_y_log10() +
  labs(title = "Influenza",
       x = NULL,
       y = NULL,
       colour = "Data source") +
  theme_bw()

ggsave("figures/comparison_influenza2.png", width = 200, height = 150, unit = "mm", device = "png")   






df <- bind_rows(df4, df6) %>% 
  filter(date >= "2019-01-01")


ggplot(df, aes(x = date, y = value, colour = source)) +
  geom_line() +
  labs(title = "Influenza",
       x = NULL,
       y = NULL,
       colour = "Data source") +
  theme_bw()
ggsave("figures/comparison_ecdc_nrz.png", width = 200, height = 150, unit = "mm", device = "png")    



df <- bind_rows(df2, df4, df6) %>% 
  filter(date >= "2019-01-01")

ggplot(df, aes(x = date, y = value, colour = source)) +
  geom_line(size = 1) +
  #geom_point() +
  #scale_y_log10() +
  labs(title = "Influenza",
       x = NULL,
       y = "Cases",
       colour = "Data source") +
  theme_bw()

ggsave("figures/comparison_influenza_ECDC_NRZ_RespVir.png", width = 200, height = 150, unit = "mm", device = "png") 




# SARI + ZI
# Influenza Net (Grippeweb)
df5 <- read_csv("data/InfluenzaNet/DE_incidence.csv")

df5 <- df5 %>% 
  mutate(year = str_sub(yw, 1, 4),
         week = str_sub(yw, 5, 6),
         dt = paste0(year, "-W", week, "-7"),
         date = ISOweek2date(dt),
         value = incidence*1000
  )  %>% 
  select(date, value) %>% 
  mutate(source = "GrippeWeb")

df7 <- read_csv("data/ZI/data-VNscS.csv") %>% 
  rename(date = Datum, value = ARE) %>% 
  mutate(source = "ZI")


df <- bind_rows(df1, df5, df7) %>% 
  filter(date >= "2019-01-01")

df <- df %>% 
  group_by(source) %>% 
  mutate(value = scale(value))

ggplot(df, aes(x = date, y = value, colour = source)) +
  geom_line() +
  # geom_point() +
  labs(x = NULL,
       y = "Value",
       colour = "Data source") +
  theme_bw()

ggsave("figures/comparison_sari_zi_grippeweb_scaled.png", width = 250, height = 150, unit = "mm", device = "png")    



### RSV

# RespVir

df_all <- read_csv("data/RespVir/respVir_filtered.csv")

df2 <- df_all %>% 
  select(c(1:6, rsvpos)) %>% 
  mutate(rsv = rsvpos == 2)

df2 <- df2 %>% 
  mutate (year = format(date, format = "%Y"))

df2 <- df2 %>% 
  group_by(date) %>% 
  summarize(rsv = sum(rsv))

df2 <- df2 %>% 
  pivot_longer(cols = c(rsv),
               names_to = "disease",
               values_to = "value")

df2 <- df2 %>%
  group_by(disease) %>% 
  mutate(value = runner(value,
                        k = "7 days",
                        idx = date,
                        f = function(x) sum(x)),
         weekday = wday(date, label = TRUE)
  ) %>% 
  filter(weekday == "Sun")

df2 <- df2 %>% 
  ungroup() %>% 
  select(date, value) %>% 
  mutate(source = "RespVir")

ggplot(df2, aes(x = date, y = value)) +
  geom_line()


# Survstat

df3 <- read_csv("data/Survstat/latest_truth_rsv_infection.csv") %>% 
  filter(location == "DE",
         age_group == "00+") %>% 
  select(date, value) %>% 
  mutate(source = "Survstat")


# NRZ (Nationales Referenzzentrum)

df4 <- read_csv("data/NRZ/rsv/2022-07-03_VirusDetections.csv") %>% 
  group_by(date) %>% 
  summarize(value = sum(value)) %>% 
  mutate(source = "NRZ")

# ECDC

df6 <- read_csv("data/ECDC/ECDC_surveillance_data_Respiratory_Syncytial_Virus.csv")

df6 <- df6 %>% 
  mutate(dt = paste0(Time, "-7"),
         date = ISOweek2date(dt),
         value = NumValue
  )  %>% 
  select(date, value) %>% 
  mutate(source = "ECDC")


df <- bind_rows(df2, df3, df4, df6) %>% 
  filter(date >= "2019-01-01")

ggplot(df, aes(x = date, y = value, colour = source)) +
  geom_line() +
  #geom_point() +
  #scale_y_log10() +
  labs(title = "RSV",
       x = NULL,
       y = "Cases",
       colour = "Data source") +
  theme_bw()

ggsave("figures/comparison_rsv.png", width = 200, height = 150, unit = "mm", device = "png") 


### PNEUMOCOCCAL DISEASE

# RespVir

df_all <- read_csv("data/RespVir/respAll_filtered.csv")

df2 <- df_all %>% 
  select(c(1:7, bakstrepos))%>% 
  mutate(bakstrepos = bakstrepos == 2)


df2 <- df2 %>% 
  group_by(date) %>% 
  summarize(bakstrepos = sum(bakstrepos))

df2 <- df2 %>% 
  pivot_longer(cols = c(bakstrepos),
               names_to = "disease",
               values_to = "value")

df2 <- df2 %>%
  group_by(disease) %>% 
  mutate(value = runner(value,
                        k = "7 days",
                        idx = date,
                        f = function(x) sum(x)),
         weekday = wday(date, label = TRUE)
  ) %>% 
  filter(weekday == "Sun")

df2 <- df2 %>% 
  ungroup() %>% 
  select(date, value) %>% 
  mutate(source = "RespVir")

ggplot(df2, aes(x = date, y = value)) +
  geom_line()


# Survstat

df3 <- read_csv("data/Survstat/latest_truth_pneumococcal_disease.csv") %>% 
  filter(location == "DE",
         age_group == "00+") %>% 
  select(date, value) %>% 
  mutate(source = "Survstat")


df <- bind_rows(df2, df3) %>% 
  filter(date >= "2018-01-01")

ggplot(df, aes(x = date, y = value, colour = source)) +
  geom_line() +
  #geom_point() +
  #scale_y_log10() +
  labs(title = "Pneumococcal Disease",
       x = NULL,
       y = "Cases",
       colour = "Data source") +
  theme_bw()

ggsave("figures/comparison_pneumococcal_disease.png", width = 200, height = 150, unit = "mm", device = "png") 
