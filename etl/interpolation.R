library(gstat)
library(sf)
library(dplyr) 
library(readr)
library(ggplot2)
library(here)
library(janitor)
library(stars)
library(tmap)
library(purrr)
library(lubridate)

### LOAD SHAPEFILES FOR MAPPING ###
com_areas <- read_sf(here("data", "mapping", "chicago_community_areas")) %>% 
  st_transform(crs = "EPSG:26916")
city_bounds <- st_read(here("data", "mapping", "chicago_boundaries", "chicago_boundaries.shp"))

### LOAD THIS MONTH'S DAILY READINGS ### 
# make empty dataframe and identify what dates are "this month" 
file_names <- list.files('data/readings/daily')
start_date <- floor_date(Sys.Date() %m-% months(1), 'month') 
end_date <- ceiling_date(Sys.Date() %m-% months(1), 'month') %m-% days(1)
cols <- c("msr_device_nbr", "date_time","pm_25", "device_friendly_name", "latitude", "longitude", "misc_annotation")
df <- data.frame(matrix(nrow = 0, ncol = length(cols)))
colnames(df) <- cols 
# loop through directory and concatenate files from this month 
index <- 1
for (file in file_names){
  current_file <- file_names[index]
  date <- as.Date(substr(current_file, 12, 21))   
  if (date >= start_date & date <= end_date){
    data <- read_csv(paste0("data/readings/daily/", current_file))
    df <- rbind(df, data)
  }
  
index <- index + 1 

}

                           
### PREPARE THE DATA FOR GEOSPATIAL ANALYSIS ###
crs = st_crs("EPSG:26916")
chicago <- st_transform(st_as_sf(city_bounds), crs)
bbox <- st_bbox(chicago)
grid <- 
  bbox %>% 
  st_as_stars(dx=300) %>% 
  st_crop(chicago)

df.sf <- 
  st_as_sf(df, coords = c("longitude", "latitude"), crs = "EPSG:4326") %>% 
  st_transform(coords, crs = "EPSG:26916")

# Inverse Distance Weighting 
idw = idw(pm_25~1, df.sf, grid)


### MAKE MAPS ###
map <- tm_shape(idw) + tm_raster("var1.pred", style = "fisher", palette = "YlOrRd") +
  tm_legend(position = c("left", "bottom")) +
  tm_layout(frame = FALSE) 

# Export maps 
month <- format(start_date,"%Y-%m")
tmap_save(map, paste0("viz/static/maps/", month,".svg"))
tmap_save(map, paste0("viz/static/maps/", month,".png"))
          





 