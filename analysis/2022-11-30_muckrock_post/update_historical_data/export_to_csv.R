library(tidyverse)
library(rio)
library(janitor)
library(here)

november <- read_csv(here("update_historical_data", "november_daily.csv")) %>% 
  filter(date_time >= "2022-11-01")

may_october <- read_csv(here("update_historical_data", "may-october_daily.csv")) %>% 
  filter(date_time >= "2022-05-01", date_time < "2022-11-01")

may <- 
  may_october %>% 
  filter(date_time >= "2022-05-01", date_time < "2022-05-31") 
export(may, "05-2022.csv")

june <- 
  may_october %>% 
  filter(date_time >= "2022-06-01", date_time < "2022-06-30") 
export(june, "06-2022.csv")

july <- 
  may_october %>% 
  filter(date_time >= "2022-07-01", date_time < "2022-07-31") 
export(july, "07-2022.csv")

august <- 
  may_october %>% 
  filter(date_time >= "2022-08-01", date_time < "2022-08-31") 
export(august, "08-2022.csv")

september <- 
  may_october %>% 
  filter(date_time >= "2022-09-01", date_time < "2022-09-30") 
export(september, "09-2022.csv")

october <- 
  may_october %>% 
  filter(date_time >= "2022-10-01", date_time < "2022-10-31") 
export(october, "10-2022.csv")

export(november, "11-2022.csv")
