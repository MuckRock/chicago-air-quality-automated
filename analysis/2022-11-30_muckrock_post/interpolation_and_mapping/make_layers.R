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
library(plotly)
library(htmlwidgets)
### load data
chiCA <- read_sf(here("data", "chicago_community_areas")) %>% 
  st_transform(crs = "EPSG:26916")

boundaries <- st_read(here("data", "chicago_boundaries", "chicago_boundaries.shp"))
crs = st_crs("EPSG:26916")
chicago <- st_transform(st_as_sf(boundaries), crs)
community_areas <- st_transform(st_as_sf(chiCA), crs)

device_list <- read_csv(here("data", "map_device_points.csv")) 

### boundaries
boundaries <- ggplot() + geom_sf(data = chicago, fill = "transparent") + 
  theme(axis.line=element_blank(),axis.text.x=element_blank(),
          axis.text.y=element_blank(),axis.ticks=element_blank(),
          axis.title.x=element_blank(),
          axis.title.y=element_blank(),legend.position="none",
          panel.background=element_blank(),panel.border=element_blank(),panel.grid.major=element_blank(),
          panel.grid.minor=element_blank(),plot.background=element_blank())

ggsave("bounds.png", boundaries, bg = "transparent")
ggsave("bounds.svg", boundaries, bg = "transparent")

### comm areas and points 
## grey and much smaller than now, but twice the first one 

comm_areas_points <-  ggplot() + geom_sf(data = community_areas, fill = "transparent") + geom_sf(data = df.sf, mapping = aes (col = device_friendly_name), size = 1)


ggplotly(comm_areas_points)

ggsave("comm_areas_points_grey_100.svg", comm_areas_points, bg = "transparent")
### get community area with device numbers and names

