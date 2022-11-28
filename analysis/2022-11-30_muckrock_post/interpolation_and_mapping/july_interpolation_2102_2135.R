library(gstat)
library(sf)
library(dplyr) 
library(readr)
library(ggplot2)
library(here)
library(janitor)
library(stars)
library(tmap)
library(magick)
library(purrr)
library(lubridate)
library(RColorBrewer)
library(rio)



### LOAD AND CLEAN OUR EAST CHICAGO SENSOR TO APPEND TO OTHER DATA
removed_devices_hourly <- read_csv(here("data", "old_historical_data", "old_hourly_query.csv")) %>% 
  clean_names() %>% 
  filter(msr_device_nbr == c("2102", "2135")) %>% 
  filter(reading_date_time_local >= "2022-07-01", reading_date_time_local < "2022-08-01") %>% 
  rename(date_time = reading_date_time_local, number_of_readings = reading_date_time_utc, pm_25 = calibrated_pm25) %>% 
  select(msr_device_nbr, date_time, number_of_readings, pm_25) %>% 
  filter(number_of_readings >= 9)

# extract stable lat / longs from hourly readings 
# make a mode function because R doesn't have one
find_mode <- function(x) {
  ux <- unique(x)
  ux[which.max(tabulate(match(x, ux)))]
}

removed_device_lat_longs <- read_csv(here("data", "old_historical_data", "old_hourly_query.csv")) %>% 
  clean_names() %>% 
  filter(msr_device_nbr == c("2102", "2135")) %>% 
  group_by(msr_device_nbr) %>% 
  summarize(latitude = find_mode(latitude), longitude = find_mode(longitude)) 

removed_devices_daily <-  
  removed_devices_hourly %>%
  group_by(msr_device_nbr, date_time) %>% 
  summarize(number_of_readings = sum(number_of_readings), pm_25 = mean(pm_25))

removed_devices_july <- 
  removed_devices_daily %>% 
  group_by(msr_device_nbr) %>% 
  summarize(pm_25 = mean(pm_25)) %>% 
  inner_join(removed_device_lat_longs, by = "msr_device_nbr") %>% 
  mutate(device_friendly_name = as.character(msr_device_nbr)) %>% 
  select(-msr_device_nbr)

# mutate(device_friendly_name = "106th & Ave D (WB)", month = 7) %>% 
  
### LOAD ALL DATA WE NEED ###
daily <- read_csv(here("data", "new_index", "may-october_daily.csv")) %>% 
  filter(date_time >= "2022-05-01", date_time < "2022-09-01") %>% 
  filter(!device_friendly_name %in% c("Madeleines House (outside)", "Madeleines House (inside)", "EnclTest 2019"))

city_boundaries <- st_read(here("data", "chicago_boundaries", "chicago_boundaries.shp"))

# apply 75% completion criteria to daily readings and aggregate to monthly
monthly <- daily %>% 
  mutate(month = month(date_time)) %>% 
  group_by(device_friendly_name, month) %>% 
  summarize(pm_25 = mean(pm_25), nbr_of_readings = sum(nbr_of_readings)) %>%
  filter(nbr_of_readings >= 6696) %>% 
  select(-nbr_of_readings) 
  # used 31 days as conservative measurement 

# get device ids that met criteria for all months we want to map 
all_summer_devices <- 
  monthly %>% 
  count(device_friendly_name) %>% 
  filter(n == 4)

# get monthly data for only the devices that meet criteria for all months we want to map
monthly_map <- 
  all_summer_devices %>% 
  inner_join(monthly, by = "device_friendly_name") %>% 
  select(-n) 


# use mode function to get mode lat/long from all hourly readings 
coords <- daily %>% 
  group_by(device_friendly_name) %>% 
  summarize(latitude = find_mode(latitude), longitude = find_mode(longitude))

#join monthly_map data with lat longs 
df <- 
  monthly_map %>% 
  left_join(coords, by = "device_friendly_name") %>% 
  filter(month == 7) %>% 
  rbind(removed_devices_july)



### PREPARE THE DATA FOR GEOSPATIAL ANALYSIS ###
crs = st_crs("EPSG:26916")
chicago <- st_transform(st_as_sf(city_boundaries), crs)
bbox <- st_bbox(chicago)
grid <- 
  bbox %>% 
  st_as_stars(dx=300) %>% 
  st_crop(chicago)

df.sf <- 
  st_as_sf(df, coords = c("longitude", "latitude"), crs = "EPSG:4326") %>% 
  st_transform(coords, crs = "EPSG:26916")

ggplot() + geom_sf(data = chicago) + geom_sf(data = df.sf, mapping = aes (col = pm_25))


### IDW FOR CLEAN DEVICES PLUS THE EAST CHICAGO ONE 
idw = idw(pm_25~1, df.sf, grid)


### MAP AND SAVE MAPS 
#rd_map <- 
  
tm_shape(idw) + tm_raster("var1.pred", palette = "YlOrRd", style = "cont") +
  tm_legend(position = c("left", "bottom")) +
  tm_layout(frame = FALSE) 

tmap_save(rd_map, "YlOrBr.svg") 
tmap_save(rd_map, "YlOrRd.png")



 