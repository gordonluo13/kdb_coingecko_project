///QUERYING VARIABLES AND URLS:

//Adjust accordingly to your own API key
apiKEY:"your API key"	

//Market filter functions
/arguments: currency;category,order;records per page;how many pages;percision
mrkFilterF:{[cur;cat;ord;pp;pg;dec]
    `vs_currency`category`order`per_page`page`precision!(cur;cat;ord;pp;pg;dec)
    }

/Default filter parameters obtained from command line arguments
fltDic:.Q.opt .z.X
category:fltDic[`cat]
percision:fltDic[`dec]
market:fltDic[`mrkt]
mrkdFlt:mrkFilterF["usd";"coinbase-50-index";"market_cap_desc";"250";"1";
    raze raze percision]

/Filters that users wish to query 
mrkFlts:mrkFilterF["usd";raze raze category;"market_cap_desc";"250";"1";
    raze raze percision]

//Filters for historical OHLC - only available on the paid plan
/arguments:start time;end time;interval type - daily or hourly
ohlcFilterF:{[start;end;int]`from`to`interval!(start;end;int)}
/Converts q timestamps to UNIX timestamps
unix:{string floor((`long$"p"$x)-`long$1970.01.01D00:00)*1e-9} 

//Function to format the filters into appropriate string
buildFltStr:"&" sv value {[filt] {x,"=",y}'[string key filt;filt]}@ 

//Function that creates the query URL 
/arguments:endpoint;filters;your API key
queryUrlF:{[endPt;flt;apiKy]
    /API url
    loc_rootURL:`:https://api.coingecko.com/api/v3;
    /Demo API string for free version on coinbase
    loc_demoAPI:"x_cg_demo_api_key=";
    /If the filter variable is not a char (e.g., empty); then
    /the string to connect with the URL only consists of the demoAPI string and 
    /your API key; otherwise it will build the string to format in the filters
    $[10=type flt;
        str:endPt,"?",loc_demoAPI,apiKy;
        str:endPt,"?",(buildFltStr flt), "&",loc_demoAPI,apiKy
        ];
    /Joins the two symbols to format the whole URL
    .Q.dd[loc_rootURL;`$str]
    }

//Query URLs
queryURL:queryUrlF["coins/markets";mrkFlts;apiKEY] 
queryDefault:queryUrlF["coins/markets";mrkdFlt;apiKEY]
/Can't use this on the demo version
queryOHLC:{[coin;start;end;int]
    queryUrlF["coins/",coin,"/ohlc/range";ohlcFilterF[start;end;int];apiKEY]
    }

//Ping to make sure you are connected to the API:
pingQ:queryUrlF["ping";"";apiKEY]

/When wanting to query/use the data from cgTb, this functions refines the data
queryData:{
    /Select rows where there are no price data (and thus any occurrences where
    /there are no dates/times)
    r:?[x;enlist(~:;(=;`price;0n));0b;()];
    /This allows each-right to be used to format the char strings of the 
    /datetimes from cgTb and then use tok to convert them into timespan for q
    r:update "P"$-1_/:time, "P"$-1_/:athDate, "P"$-1_/:atlDate from r;
    update `time$time from r
    }

///PARSING AND DEFINING SCHEMA OF DATA:

/Take the schema you want to apply from a predefined .csv file 
schema:("sscb";enlist ",") 0: `:coingeckoSchema.csv
//Function that parses the JSON and applies the schema 
applySchema:{[sch;tb]
    /Define table schema by only selecting enabled columns
    sch:select from sch where enable;
    tb:#[;tb] cols[tb] inter exec OGcolumn from sch;          
    /Rename Original columns taken from API to New column names in Q
    tb:xcol[;tb] exec OGcolumn!Qcolumn from sch;       
    /Cast columns to appropriate data type using the cast function
    tb:cast[cols tb;exec (Qcolumn!typ) cols tb from sch;tb];    
    tb
    }

//Cast column types in table
cast:{[clmns;typ;tb]
    /Dict. mapping of columns (key) with their respective data types (values)
    colTyp:clmns!typ;
    /From the meta of tb, collect the data types and convert 
    colTyp,:exec c!upper colTyp c from meta tb where t="C";
    /Dynammically select tb in which each appropiate data type (values) are 
    /casted (tok) against the relavent column(s) (key)
    ![tb;();0b;key[colTyp]!{($;x;y)}'[value colTyp;key colTyp]]
    }

//Creating the table
/Keeps the schema the same, but empties the table
cgTb:0#queryData applySchema[schema;.j.k .Q.hg queryDefault]

///RUNNING AND ACQUIRING THE DATA:

//Function assigned to retrieve data from coingecko and upsert into cgTb:
/Assigned within the timeRun function which itself is assigned to .z.ts to get 
/the data at regular intervals and cgTb can also be called to query in memory
getData:{
    data:queryData applySchema[schema;.j.k .Q.hg queryURL];
    `cgTb upsert data;
    }

//Function to get the data at the moment it is called
dataNow:{queryData applySchema[schema;.j.k .Q.hg queryURL]}

//Function that creates the partition path upon which the data is saved at 
/the end of day, on disk, partitioned by date
saveData:{
    partition:string .z.D;
    geckDir:`:geckoDir;
    tbName:raze raze market,"Tb"; 
    path:` sv geckDir,`$partition,"/", tbName,"/";
    path set .Q.en[geckDir] cgTb
    }

currentDay:.z.D
//Function that is assigned to .z.ts
/When the day is over, it saves the data and sets the global currentDay
/variable to be the next day and repeats.
timeRun:{
    today:.z.D;
    if[currentDay = today;
        getData[];];
    if[currentDay <> today;
        saveData[];
        `currentDay set .z.D;
        `cgTb set 0#queryData applySchema[schema;.j.k .Q.hg queryDefault];]
    }
