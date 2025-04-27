
/// TABLE ANALYSIS DIRECTORY FUNCTIONS:
\d .ta
//OHLC lookup
/arguments:table, symbol 
ohlc:{[t;s]
    select open:first price, high:max price, low:min price, close:last price,
    vol:sum totVol, vwap:totVol wavg price by 5 xbar time.minute
    from t where sym = s
    }

//5 min - 5 min price changes
/argument:table
dels:{
    /Create the del5 table grouped by sym and binned every 5mins 
    del5:select delPrice:first distinct price by sym, 5 xbar time.minute from x;
    del5:update deltas delPrice from del5;
    /Find the indices where each symbol first occurs, and set that change 
    /in price to be 0f as there can be no change in price for the first price
    idx:first each where each 1=(exec sym from del5)=/:distinct 
    exec sym from del5;
    del5:update delPrice:0f from del5 where i in idx;
    /Create final table
    select mxIn:max delPrice, mxDe:min delPrice by sym from del5
    }

//Periods of depegging
/argument:table
depeg:{
    /Select where prices are not pegged to $1
    dpg:select from x where price < 1;
    dpg:update ts:`second$time from dpg;
    /Create peiod index based on how many times there is a gap of more than
    /150s between rows of each sym (150s done as the data from coingecko updates
    /approximately ever 120s) 
    dpg:update period:1+sums(ts-prev ts)>=150 by sym from dpg;
    /Create the main table
    dpg:select min price, start:first time.minute, end:last time.minute
    by sym, period from dpg;
    /Add column of duration of depegging
    dpg:update duration:end-start from dpg;
    /Filter out occurences where duration is 0mins, and update the period index
    dpg:select from dpg where duration > 00:00;
    dpg:update period: 1+til count i by sym from dpg
    }

//Pivot table function
/argument:[select by x,y from table;symbol]
/x will be the rows, y will be the columns;symbol will be the value
pivot:{[t;ascVal] 
    /unique list to reshape the dictionary to conform the shape
    reshape:`$string asc distinct last f:flip key t;
    /pivot function that reshapes the dictionary
    pF:{x#(`$string y)!z};
    /
    pS:?[t;();g!g:-1_k;(pF;`reshape;last k:key f;ascVal)];
    pS
    }
\d