import requests
import json
import pandas as pd
from datetime import date, timedelta, datetime, timezone
from zoneinfo import ZoneInfo
import os 


### SET VARIABLES TO MICROSOFT API ENDPOINTS ###
device_list_url = "https://urban.microsoft.com/api/EclipseData/GetDeviceList"
readings_url = "https://urban.microsoft.com/api/EclipseData/GetReadings"
city = "chicago"
api_key = os.environ["MICROSOFT_TOKEN"]

### MAKE FUNCTION TO GET READINGS IN A DATE RANGE ###
# start at beginning of yesterday Chicago time

ct_start_datetime = datetime.now(tz = ZoneInfo("America/Chicago")).replace(hour=0, minute=0, second=0) + timedelta(days=-1)
ct_end_datetime = datetime.now(tz = ZoneInfo("America/Chicago")).replace(hour=23, minute=59, second=59) + timedelta(days=-1)

start_datetime = ct_start_datetime.astimezone(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
end_datetime = ct_end_datetime.astimezone(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")

### GET DATES IN RANGE AND PULL DATA FROM API ###
df_complete = pd.DataFrame()
response = requests.get(readings_url +
                        f"?city={city}" +
                        f"&startDateTime={start_datetime}" +
                        f"&endDateTime={end_datetime}",
                    headers={'ApiKey':api_key})

readings = response.json()
readings = pd.DataFrame(readings)

readings['readingDateTimeUTC'] = pd.to_datetime(readings.readingDateTimeUTC)
readings['readingDateTimeLocal'] = pd.to_datetime(readings.readingDateTimeLocal)
print(readings)
df_complete = pd.concat([df_complete, readings])


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

### WRITE UPDATED DATA TO NEW CSV FOR EACH WEEK
today = date.today()
if date.today().weekday() == 1:
    output_path='data/readings/daily_updates/' +'week_start_' + str((today - timedelta(days=today.weekday())).strftime('%Y-%m-%d')) + '.csv'
    daily_clean.to_csv(output_path)
elif date.today().weekday() == 0:
    output_path='data/readings/daily_updates/' +'week_start_' + str(((today - timedelta(days=1)) - timedelta(days=today.weekday())).strftime('%Y-%m-%d')) + '.csv'
    daily_clean.to_csv(output_path, mode='a', header=False)
else:
    output_path='data/readings/daily_updates/' + 'week_start_' + str((today - timedelta(days=today.weekday())).strftime('%Y-%m-%d')) + '.csv'
    daily_clean.to_csv(output_path, mode='a', header=False)






