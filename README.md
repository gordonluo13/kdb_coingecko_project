# **coingecko kdb+/q Project**

This project aims to employ and cover a select variety of different skills and topics that I have gathered while learning kdb+/q:

- Interacting with the coingecko API
- Parsing, cleaning and formatting the data from an API
- Periodically saving the data to an in-memory table
- Saving the data on-disk, to a partitioned table at the end of the day
- Querying and analysing of the data using utility functions defined in a directory using Q-SQL

Included will be two examples that demonstrate how to run the script, and the key functionality implemented 
within the context of cryptocurrencies categorised as layer-1 or stablecoins.
**In particular, this project will highlight some interesting analysis that can be performed on stablecoins data (Example 2) using kdb+/q**.

Before, starting the script, the user must first define their own schema such that the data from the API is prepared to their desired format 
(I was introduced through this approach by Jonathan Kane's article <sup>[[1]](https://medium.com/version-1/an-introduction-to-interacting-with-rest-apis-in-q-kdb-72fe278e5937)</sup>
which was further supplemented with Rian Ó Cuinneagáin's article <sup>[[2]](https://kx.com/blog/kdb-q-insights-parsing-json-files/)</sup>)</sup>.
An example of a schema .csv file is also provided.

## Example 1 Layer-1 Demonstration:

To start, load in the script and command line options:
- -cat: the category ID from coingecko
- -dec: the precision to decimal points
- -mrkt: the market/category name, this will be appended to "Tb" to format the table name in the partitioned table
- -t: set timer to run every 60s

```q
$q coingecko.q -cat layer-1 -dec 5 -mrkt layerOne -t 60000
```

Then assign the .z.ts to the timeRun function:
```q
.z.ts:timeRun
```
The table **cgTb** stores the data collected from the API, in-memory, and is periodically updated with new data every 60s:
```q
cgTb  /all the data collected from the API as script is running
```

If the user wishes, they can obtain a snapshot of the data at the moment it was last updated from coingecko:
```q
tbNow:dataNow[]  /dataNow function gathers the data at the moment the function is called
```

At the end of the day, **cgTb** is saved on-disk to the directory path **`:geckoDir/2025.04.27/layerOneTb/**, as -mrkt was defined as layerOne at the start.
To load the data in, first load into this directory, and then assign to a new variable:
```q
\l geckoDir
l1Tb:select from layerOneTb where date within 2025.04.27 /assign the historical layer-1 data to l1Tb
system"cd ../"  /load back into the main directory
```

From the list of functions defined in the **tbFunc** directory/namespace (**.ta**), more detailed queries and analysis can be performed on the data collect from the coingecko API.
As an example, for the layer-1 data, an OHLC table can be produced with a vwap over a given **int** minute interval for a given sym:
```q
.ta.ohlc[l1Tb;`btc;5]  /OHLC table with a vwap over a 5 minute interval for bitcoin
```
<img width="452" alt="coingecko  ta ohlc Example" src="https://github.com/user-attachments/assets/1213c874-fecb-42bb-8dac-78083a0d2d79" />

## Example 2 Stablecoins Demonstration:

Similary to Example 1, the script is loaded in with relevant command line options:
```q
$q coingecko.q -cat layer-1 -dec 5 -mrkt usd-stablecoin -t 60000
```

Then again, assign the .z.ts to the timeRun function:
```q
.z.ts:timeRun
```

At the end of the day, **cgTb** is saved on-disk to the directory path **`:geckoDir/2025.04.25/stablecoinsTb/**, follow the same as before:
```q
\l geckoDir
stbTb:select from stablecoinsTb where date within 2025.04.25 /assign the historical usd-pegged stablecoinsdata to stbTb
system"cd ../"  /load back into the main directory
```
With stablecoins, they are cryptocurrencies that are pegged 1:1 with an asset.
In this example, they are pegged 1:1 with the USD.
Using the functions from the **.ta** directory/namespace, price 5 minute -to- 5 minute price variations
of the maximum increase (mxIn) and maximum decrease (mxDe) can be detected:
```q
.ta.dels stbTb
```
<img width="181" alt="coingecko  ta dels Example" src="https://github.com/user-attachments/assets/ae74d146-d539-42f2-a503-ab716ee00c2e" />

Additionally, one of note with regards to stablecoins, is depegging i.e., when their value drops below $1 USD. 
With the **.ta.dep** function, for each sym, the function will return a table keyed to the sym and period - where each period is the time that a depegging event has occurred:
```q
.ta.depeg stbTb
```
<img width="311" alt="coingecko  ta depeg Example" src="https://github.com/user-attachments/assets/22a15862-97f7-4ebb-8a3b-4b679a9f7940" />

Furthermore, a **pivot** table function can be utilised to create show the prices of each symbol during each period of depegging:
```q
dpgTb:.ta.depeg stbTb
.ta.pivot[select by sym,period from dpgTb]`price
```
<img width="758" alt="coingecko  ta pivot Example" src="https://github.com/user-attachments/assets/1dc52408-8cbf-4f37-a628-72c60c0445c7" />

*Note: no attributes were applied to the partitioned tables as with coingecko, on the demo version, 
prices only update once every minute i.e., 360000 rows across one day (for stablecoins, it is approximately once every 2 minutes), thus the memory overhead of applying 
for example, a grouped `g# attribute is not worth it.*

### References
[[1]](https://medium.com/version-1/an-introduction-to-interacting-with-rest-apis-in-q-kdb-72fe278e5937) **An Introduction to Interacting with REST APIs in Q/KDB+**, Jonathan Kane (2024)\
[[2]](https://kx.com/blog/kdb-q-insights-parsing-json-files/) **A developers guide to JSON parsing in kdb+**, Rian Ó Cuinneagáin (2025)
