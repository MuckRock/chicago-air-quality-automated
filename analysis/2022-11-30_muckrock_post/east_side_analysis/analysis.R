library(tidyverse)
library(rio)
library(janitor)
library(here)
library(ggplot2)
library(plotly)
library(lubridate)
library(htmlwidgets)

purple_air_main <- read_csv(here("east_chicago_analysis", "purple_air_data", "purple_air_all.csv")) %>% 
  filter(device_id %in% c("h_109_primary_a", "luc_care_2_primary_a")) %>% 
  mutate(date_time = as.Date(date_time)) %>% 
  group_by(device_id, date_time) %>% 
  summarize(pm_25 = mean(pm_25))

purple_air_all <- read_csv(here("east_chicago_analysis", "purple_air_data", "purple_air_all.csv")) %>% 
  filter(!device_id == "luc_care_5_primary_a") %>% 
  mutate(date_time = as.Date(date_time)) %>% 
  group_by(device_id, date_time) %>% 
  summarize(pm_25 = mean(pm_25))

msft <- read_csv(here("east_chicago_analysis", "msft_data", "daily_clean.csv")) %>% 
  filter(msr_device_nbr == "2135") %>% 
  select(-number_of_readings) %>% 
  rename(device_id = msr_device_nbr, date_time = date) %>% 
  mutate(device_id = as.character(device_id))


epa_days <- read_csv(here("east_chicago_analysis", "epa_data", "washington_pm_25.csv")) %>% 
  select(date_local, arithmetic_mean) %>% 
  rename(date_time = date_local, pm_25 = arithmetic_mean) %>% 
  group_by(date_time) %>% 
  summarize(pm_25 = mean(pm_25))


df_all <- rbind(purple_air_main, msft) %>% 
  mutate(pm_25 = round(pm_25, 2))
  
main <- ggplot(df_all, aes(x=date_time, y=pm_25)) +
  geom_line(aes(colour=device_id)) +
  geom_point(data = epa_days, aes(x=date_time, y=pm_25))


main <- ggplot(df, aes(x=date_time, y=pm_25)) +
  geom_line(aes(colour=device_id))

ggsave("example.png", main)

ggplotly(main)

saveWidget(ggplotly(all), file = "east_chicago_eda_main.html")
