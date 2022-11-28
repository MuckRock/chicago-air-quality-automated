
import requests
import json
import pandas as pd
from datetime import date, timedelta
import time
import os 

os.chdir('C:\\Users\\newsd\\home\\code\\chicago-actions-data-release\\update_historical_data')

UrlGetDeploymentDetails = "https://urban.microsoft.com/api/EclipseData/GetDeploymentDetails"
UrlGetDeviceList = "https://urban.microsoft.com/api/EclipseData/GetDeviceList"
UrlGetLatestReadings = "https://urban.microsoft.com/api/EclipseData/GetLatestReadings"
UrlGetReadings = "https://urban.microsoft.com/api/EclipseData/GetReadings"
access_token = "064D20BA-F452-41F5-B78E-581861340043"

def daterange(start_date, end_date):
    for n in range(int((end_date - start_date).days)):
        yield start_date + timedelta(n)
# weird things happens and API sends back data from night before along with the day you start at (from 7pm to midnight) and does go through, but only up to end date
# so clean out date of day before that you don't want later, and make sure to go one day beyond the last day you want data from 
start_date = date(2022, 10, 30)
end_date = date(2022, 11, 28)
city = "chicago"

df_complete = pd.DataFrame()

for single_date in daterange(start_date, end_date):
    print(single_date)
    startDateTime = single_date.strftime("%Y-%m-%d %H:%M:%S")

    endDateTime = (single_date + timedelta(1)).strftime("%Y-%m-%d %H:%M:%S")

    response = requests.get(UrlGetReadings +
                                f"?city={city}" +
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
    .groupby(['deviceFriendlyName', pd.Grouper(key='readingDateTimeLocal', freq="H")])
    .agg({'readingDateTimeUTC':['nunique'], 'calibratedPM25':['mean'], 'latitude':['median'], 'longitude':['median']})
    .reset_index(col_level=1)
)

hourly_all.columns = hourly_all.columns.get_level_values(1)

hourly_all.columns = ['device_friendly_name', 'date_time', 'nbr_of_readings', 'pm_25', 'latitude', 'longitude']

# apply date completeness criteria of 75% of total possible readings in one hour
hourly_clean = (
    hourly_all
    .query('nbr_of_readings >= 9')
)

daily_all = (
    hourly_clean
    .groupby(['device_friendly_name', pd.Grouper(key='date_time', freq="D")])
    .agg({'nbr_of_readings':['sum'], 'pm_25':['mean'], 'latitude':['median'], 'longitude':['median']})
    .reset_index(col_level=1)
)

daily_all.columns = daily_all.columns.get_level_values(1)
daily_all.columns = ['device_friendly_name', 'date_time', 'nbr_of_readings', 'pm_25', 'latitude', 'longitude']

# apply date completeness criteria of 75% of total possible readings in one day 
daily_clean = (
    daily_all
    .query('nbr_of_readings >= 216')
    .set_index('device_friendly_name')
)

daily_clean.to_csv('november_daily.csv')






