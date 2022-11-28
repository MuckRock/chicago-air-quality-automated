
import requests
import json
import pandas as pd
from datetime import date, timedelta
import time
import os 

os.chdir('C:\\Users\\newsd\\home\\code\\chicago-actions-data-release')

UrlGetDeploymentDetails = "https://urban.microsoft.com/api/EclipseData/GetDeploymentDetails"
UrlGetDeviceList = "https://urban.microsoft.com/api/EclipseData/GetDeviceList"
UrlGetLatestReadings = "https://urban.microsoft.com/api/EclipseData/GetLatestReadings"
UrlGetReadings = "https://urban.microsoft.com/api/EclipseData/GetReadings"
access_token = "064D20BA-F452-41F5-B78E-581861340043"

def daterange(start_date, end_date):
    for n in range(int((end_date - start_date).days)):
        yield start_date + timedelta(n)

start_date = date(2022, 7, 19)
end_date = date(2022, 7, 23)
city = "chicago"

df_complete = pd.DataFrame()

for single_date in daterange(start_date, end_date):
    print(single_date)
    startDateTime = single_date.strftime("%Y-%m-%d %H:%M:%S")

    endDateTime = (single_date + timedelta(1)).strftime("%Y-%m-%d %H:%M:%S")

    response = requests.get(UrlGetReadings +
                                f"?city={city}" +
                                f"&devices=2135" +
                                f"&startDateTime={startDateTime}" +
                                f"&endDateTime={endDateTime}",
                            headers={'ApiKey':access_token})

    ReadingsByDateRange = response.json()
    ReadingsByDateRangeDf = pd.DataFrame(ReadingsByDateRange)

    if ReadingsByDateRangeDf.empty:
        time.sleep(3)
        continue
    
    ReadingsByDateRangeDf['readingDateTimeUTC'] = pd.to_datetime(ReadingsByDateRangeDf.readingDateTimeUTC)
    ReadingsByDateRangeDf['readingDateTimeLocal'] = pd.to_datetime(ReadingsByDateRangeDf.readingDateTimeLocal)
    print(ReadingsByDateRangeDf)
    df_complete = pd.concat([df_complete, ReadingsByDateRangeDf])

    time.sleep(3)


### AGGREGATE MINUTE-BY-MINUTE DATA UP TO DAILY AVERAGES ###
hourly_all = (
    df_complete
    .groupby(['msrDeviceNbr', pd.Grouper(key='readingDateTimeLocal', freq="H")])
    .agg({'readingDateTimeUTC':['nunique'], 'calibratedPM25':['mean'], 'latitude':['median'], 'longitude':['median']})
    .reset_index(col_level=1)
)

hourly_all.columns = hourly_all.columns.get_level_values(1)

hourly_all.columns = ['msr_device_nbr', 'date_time', 'nbr_of_readings', 'pm_25', 'latitude', 'longitude']


hourly_all.to_csv('test.csv')








