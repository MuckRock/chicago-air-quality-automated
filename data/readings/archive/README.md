## A note on Device 2135, formerly at 106th and Avenue D
This device has been decomissioned, and because of this, Microsoft no longer makes its data avaiable in historical queries to the UrbanAir API if the request is a bulk request for all data from all sensors. The data for this sensor is still public, but you have to request it by asking the API for data from just that device, e.g. in the header of your request using "devices=2135"

``` response = requests.get(UrlGetReadings +
                                f"?city={city}" +
                                f"&devices=2135" +
                                f"&startDateTime={startDateTime}" +
                                f"&endDateTime={endDateTime}",
                            headers={'ApiKey':access_token}) ```
