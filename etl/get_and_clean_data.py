import requests
import json
import pandas as pd
from datetime import date, timedelta, datetime
import time
import os 


### SET VARIABLES TO MICROSOFT API ENDPOINTS ###
device_list_url = "https://urban.microsoft.com/api/EclipseData/GetDeviceList"
readings_url = "https://urban.microsoft.com/api/EclipseData/GetReadings"
city = "chicago"
api_key = os.environ["MICROSOFT_TOKEN"]

### MAKE FUNCTION TO GET READINGS IN A DATE RANGE ###
def daterange(start_date, end_date):
    for n in range(int((end_date - start_date).days)):
        yield start_date + timedelta(n)
start_date = date.today() - timedelta(days=1)
end_date = date.today()

### GET DATES IN RANGE AND PULL DATA FROM API ###
# this is meant to help others change this code easily to specify their own dates of interest 
# as is though, this function isn't really necessary for daily pulls 
df_complete = pd.DataFrame()
for single_date in daterange(start_date, end_date):
    print(single_date)
    start_date = single_date.strftime("%Y-%m-%d %H:%M:%S")

    end_date = (single_date + timedelta(1)).strftime("%Y-%m-%d %H:%M:%S")

    response = requests.get(readings_url +
                                f"?city={city}" +
                                f"&startDateTime={start_date}" +
                                f"&endDateTime={end_date}",
                            headers={'ApiKey':api_key})

    readings = response.json()
    readings = pd.DataFrame(readings)

    if readings.empty:
        time.sleep(3)
        continue
    
    readings['readingDateTimeUTC'] = pd.to_datetime(readings.readingDateTimeUTC)
    readings['readingDateTimeLocal'] = pd.to_datetime(readings.readingDateTimeLocal)
    print(readings)
    df_complete = pd.concat([df_complete, readings])

    time.sleep(3)

### AGGREGATE MINUTE-BY-MINUTE DATA UP TO DAILY AVERAGES ###
hourly_all = (
    df_complete
    .groupby(['msrDeviceNbr', pd.Grouper(key='readingDateTimeLocal', freq="H")])
    .agg({'readingDateTimeUTC':['nunique'], 'calibratedPM25':['mean']})
    .reset_index(col_level=1)
)

hourly_all.columns = hourly_all.columns.get_level_values(1)

# apply date completeness criteria of 75% of total possible readings in one hour
hourly_clean = (
    hourly_all
    .rename(columns={'msrDeviceNbr': 'msr_device_nbr', 'readingDateTimeLocal': 'date_time', 'nunique': 'nbr_of_readings', 'mean': 'pm_25'})
    .query('nbr_of_readings > 9')
)

daily_all = (
    hourly_clean
    .groupby(['msr_device_nbr', pd.Grouper(key='date_time', freq="D")])
    .agg({'pm_25':['mean'], 'nbr_of_readings':['sum']})
    .reset_index(col_level=1)
)

daily_all.columns = daily_all.columns.get_level_values(1)

# apply date completeness criteria of 75% of total possible readings in one day 
daily_clean = (
    daily_all
    .rename(columns={'mean':'pm_25','sum':'nbr_of_readings'})
    .query('nbr_of_readings > 216')
    .drop(['nbr_of_readings'], axis = 1)
    .set_index('msr_device_nbr')
)


### GET DEVICE LIST FOR CANNONICAL LAT/LONGS ###
# lat/longs from individual readings occassionally drift slightly, and we want one cannonical lat/long for each device 
list_response = requests.get(device_list_url + f"?city={city}", headers={'ApiKey':api_key})
device_list = list_response.json()
device_list_df = pd.DataFrame(device_list)
device_list_df = (
    device_list_df[['msrDeviceNbr', 'deviceFriendlyName', 'deploymentStartDateTime', 'latitude', 'longitude', 'miscAnnotation']]
    .rename(columns={'msrDeviceNbr': 'msr_device_nbr','deviceFriendlyName':'device_friendly_name','deploymentStartDateTime': 'time_stamp', 'miscAnnotation': 'misc_annotation'})
)

device_list_df['time_stamp'] = pd.to_datetime(device_list_df['time_stamp'])

updated_list = device_list_df.sort_values(by=['time_stamp']).drop_duplicates(['msr_device_nbr'], keep='last')

### JOIN CANNONICAL LAT/LONGS TO MOST RECENT DATA ###
update_complete = pd.merge(daily_clean, updated_list, on='msr_device_nbr', how='left')
update_complete = (
    update_complete
    .set_index('msr_device_nbr')
    .drop(['time_stamp'], axis = 1)
)

### WRITE UPDATED DATA TO NEW CSV FOR EACH WEEK
today = date.today()
if date.today().weekday() == 0:
    output_path='data/readings/daily/' +'week_start_' + str(datetime.now().strftime('%Y_%m_%d')) + '.csv'
    update_complete.to_csv(output_path)
else:
    output_path='data/readings/daily/' + 'week_start_' + str((today - timedelta(days=today.weekday())).strftime('%Y_%m_%d')) + '.csv'
    update_complete.to_csv(output_path, mode='a', header=False)






