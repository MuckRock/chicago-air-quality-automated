library(tidyverse)
library(rio)
library(janitor)
library(plotly)
library(here)
library(lubridate)
library(htmlwidgets)

# STEP 1: Load data 
# Take 2-minute raw readings, and select the columns we need:
# Time stamp
# Channel A: PM2.5_CF1_ug/m3 (higher correction factor)
care_5_a <- read_csv(here("purple_air_correction", "data","processed", "care_5", "LUC_CARE5 (outside) (41.696642 -87.52602) Primary Real Time 05_01_2022 10_31_2022.csv")) %>% 
  mutate(device_id = "care_5_a") %>% 
  rename(date_time = created_at, pm_25 = "PM2.5_CF1_ug/m3") %>% 
  mutate(date_time = ymd_hms(date_time)) %>%
  select(device_id, date_time, pm_25)

# Time stamp
# Channel B: PM2.5_CF1_ug/m3 (higher correction factor)
care_5_b <- read_csv(here("purple_air_correction", "data", "processed", "care_5", "LUC_CARE5 B (undefined) (41.696642 -87.52602) Primary Real Time 05_01_2022 10_31_2022.csv")) %>% 
  mutate(device_id = "care_5_b") %>% 
  rename(date_time = created_at, pm_25 = "PM2.5_CF1_ug/m3") %>% 
  mutate(date_time = ymd_hms(date_time)) %>% 
  select(device_id, date_time, pm_25)
# Humidity
# Comes only in csv of Channel A as single reading for both channels 
humidity <- read_csv(here("purple_air_correction", "data","processed", "care_5", "LUC_CARE5 (outside) (41.696642 -87.52602) Primary Real Time 05_01_2022 10_31_2022.csv")) %>%
  rename(date_time = created_at, rh = "Humidity_%") %>% 
  mutate(date_time = ymd_hms(date_time)) %>% 
  mutate(date_hour = floor_date(date_time, unit = "hour")) %>%
  group_by(date_hour) %>% 
  summarize(rh = mean(rh))
# Concatenate the channels together 
care_5_both_channels <- rbind(care_5_a, care_5_b)


# STEP 2: Quality control for completeness 
# Average readings to one hour average and get rid of readings that 90% completeness criteria  (27 of 30 readings)
care_5_hourly <- 
  care_5_both_channels %>% 
  mutate(date_hour = floor_date(date_time, unit = "hour")) %>% 
  group_by(device_id, date_hour) %>% 
  summarize(pm_25 = mean(pm_25), readings = n_distinct(date_time)) %>% 
  filter(readings >= 27) %>% 
  select(-readings)


# STEP 3: Quality control for consistency 
# Average readings to daily and remove days where Channel A and Channel B are more than 68 percent, typical standard deviation 68%
care_5_daily_comp <- 
  care_5_hourly %>% 
  mutate(date = floor_date(date_hour, unit = "day")) %>% 
  group_by(device_id, date) %>% 
  summarize(pm_25 = mean(pm_25)) %>% 
  pivot_wider(names_from = device_id, values_from = "pm_25") %>% 
  mutate(diff = (care_5_a - care_5_b)*2/(care_5_a + care_5_b)) %>% 
  filter(diff <= 0.68, diff >= -0.68) %>% 
  select(date)
# removes just one day in actuality, 2022-29-05, and the following two days 30/31 for NaN


# STEP 4: Perform correction and aggregate to daily, combined channel readings
# Join hourly averages with humidity by hour and convert humidity to percent
care_5 <- 
  care_5_hourly %>% 
  left_join(humidity, by = "date_hour") %>% 
  mutate(rh = rh/100)

# Add column for corrected pm 
care_5_corrected <- 
  care_5 %>% 
  mutate(corrected_pm = 0.524*pm_25-0.0862*rh + 5.75) %>% 
  select(-rh)

# Combine channels 
care_5_agg <- 
  care_5_corrected %>% 
  group_by(date_hour) %>% 
  summarize(raw = mean(pm_25), corrected = mean(corrected_pm)) 
  
# Aggregate to daily from hourly and get rid of days that didn't meet consistency criteria 
care_5_daily_clean <- 
  care_5_agg %>% 
  mutate(date = floor_date(date_hour, unit = "day")) %>% 
  group_by(date) %>% 
  summarize(corrected = mean(corrected), raw = mean(raw)) %>% 
  inner_join(care_5_daily_comp, by = "date")
         
         

### Plotting for comparison 
plot_df <- 
  care_5_daily_clean %>% 
  pivot_longer(cols = c("raw", "corrected"))

plot <- ggplot(plot_df, aes(x=date, y=value)) +
  geom_line(aes(colour=name))

ggplotly(plot)

saveWidget(ggplotly(plot), file = "correction_h_109.html")
