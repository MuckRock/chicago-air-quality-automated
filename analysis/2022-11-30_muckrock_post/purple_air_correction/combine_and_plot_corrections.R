library(tidyverse)
library(rio)
library(janitor)
library(here)
library(ggplot2)
library(lubridate)

library(plotly)
library(htmlwidgets)

h_109_corrected <- read_csv(here("purple_air_correction", "data", "clean", "h_109_corrected.csv")) %>% 
  mutate(device_id = "h_109") %>% 
  filter(name == "corrected") %>% 
  select(device_id, date, value) %>% 
  rename(pm_25 = value)

care_2_corrected <- read_csv(here("purple_air_correction", "data", "clean", "care_2_corrected.csv")) %>% 
  mutate(device_id = "care_2") %>% 
  filter(name == "corrected") %>% 
  select(device_id, date, value) %>% 
  rename(pm_25 = value)

purple_air <- 
  rbind(h_109_corrected, care_2_corrected)

export(purple_air, "purple_air_sensors_corrected.csv")

msft <- read_csv(here("east_chicago_analysis", "msft_data", "daily_clean.csv")) %>% 
  filter(msr_device_nbr == "2135") %>% 
  select(-number_of_readings) %>% 
  rename(device_id = msr_device_nbr) %>% 
  mutate(device_id = as.character(device_id))

epa_days <- read_csv(here("east_chicago_analysis", "epa_data", "washington_pm_25.csv")) %>% 
  select(date_local, arithmetic_mean) %>% 
  rename(date_time = date_local, pm_25 = arithmetic_mean) %>% 
  group_by(date_time) %>% 
  summarize(pm_25 = mean(pm_25)) %>% 
  rename(date = date_time)

pa_and_msft <- rbind(purple_air, msft)


plot <- ggplot(pa_and_msft, aes(x=date, y=pm_25)) +
  geom_line(aes(colour=device_id)) 


ggplotly(plot)

saveWidget(ggplotly(plot), file = "corrected_comparison.html")
