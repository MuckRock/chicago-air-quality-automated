## A note on Device 2135, formerly at 106th and Avenue D
This device has been decomissioned, and because of this, Microsoft no longer makes its data available in historical queries to the UrbanAir API if the request is a bulk request for all data from all sensors. There is now a new device at at 106th and Avenue D. The data for the sensor that used to be in that location is still public, but you have to request it by asking the API for data from only that device, e.g. in the header of your request, by specificing "devices=2135".
### Example query using Python's requests library
``` 
response = requests.get(UrlGetReadings +
                                f"?city={city}" +
                                f"&devices=2135" +
                                f"&startDateTime={startDateTime}" +
                                f"&endDateTime={endDateTime}",
                            headers={'ApiKey':access_token}) 
```

## How to see the history of a device, when it was sited, and when it was it decomissioned
In general, if it seems like a device went on or offline in the time series that you're analyzing, the best way to check the history of a device is by requesting the `device list` from the UrbainAir API.
### Example query using Python's requests library
``` device_list_url = "https://urban.microsoft.com/api/EclipseData/GetDeviceList"
readings_url = "https://urban.microsoft.com/api/EclipseData/GetReadings"
city = "chicago"
api_key = "secret_api_key"
list_response = requests.get(device_list_url + f"?city={city}", headers={'ApiKey':api_key})
device_list = list_response.json()
device_list_df = pd.DataFrame(device_list)```
