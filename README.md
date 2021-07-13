# csgfix
A simple R package for fixing data for use with the `ctmm` package

## Installation


The package can be installed from GitHub using the `devtools` package.    
```r
#install.packages("devtools")
devtools::install_github("StevenRunyon/csgfix")
```

In addition,  the packages `move` and `ctmm` are required. These can be downloaded from CRAN.    
```r
install.packages("move")
install.packages("ctmm")
```   

## Functions and Parameters
#### bank
  the primary function of the package, changes data from the input format to a data frame in the Movebank format (for use with the _move_ function)    
  `data`: dataframe, see "Data Input"    
  `projectionType`: logical or character or function, how the coordinates should be projected, FALSE or the name of a projection (like "na" for North America Equidistant Conic) or a function(_lat_, _long_, _datetime_) where _lat_ and _long_ are vectors of numbers and _datetime_ is a vector of POSIXct corresponding to the time of those observations. Should return a data frame with two numeric columns, _x_ and _y_.        
  `timeformat`: character, the format Date_Time is in (for use with as.POSIXct)    
  `ct`: logical, TRUE to use POSIXct timestamps, FALSE to use characters that are in the Movebank format    
  `tonad83`: logical, TRUE if you want to convert from WGS84 to NAD83 before projection (only used when projectionType is a character)
  example:    
  ```r
    data <- read.csv("AKgoeasHrly_ex.txt")
    data2 <- bank(data)
  ```

#### quickMove    
  shortcut for creating Move object from data   
  `data`: dataframe, the data used for _bank_   
  `proj`: CRS object, the projection type for _move::move_    
  `timeformat`: character, the format Date_Time is in for use with as.POSIXct ("%m/%d/%Y %T" by default, see: https://stat.ethz.ch/R-manual/R-devel/library/base/html/strptime.html)    
  `removeDuplicatedTimestamps`: logical, just what it says, sent to _move::move_ (FALSE by default)   
  `projectionType`: logical or character or function, sent to _bank_ (FALSE by default, make sure you also change _proj_ to reflect any changes made here)      
  example:    
  ```r
    data <- read.csv("AKgoeasHrly_ex.txt")
	proj <- sp::CRS("+proj=latlong+ellps=WGS84 +datum=WGS84")
    movedata <- quickMove(data, proj=proj, timeformat="%m/%d/%Y %H:%M")
  ```
  
#### quickTelemetry    
  shortcut for creating a Telemetry object from a Move object from data   
  shortcut for `ctmm::as.telemetry(quickMove(data, ...), proj)`, uses all the same parameters as _quickMove_
  example:    
  ```r
    data <- read.csv("AKgoeasHrly_ex.txt")
	proj <- sp::CRS("+proj=latlong+ellps=WGS84 +datum=WGS84")
    telemetry <- quickTelemetry(data, proj=proj, timeformat="%m/%d/%Y %H:%M")
  ```

#### projectionEquidistantConic    
  projects lat and long to x and y using equidistant conic projection    
  `lat` and `long`: numeric vectors of latitude and longitude (to be equivalent to ArcGIS, these must be in NAD83)     
  `type`: logical or character, FALSE or the name of a preset set of parameters (like "na" for North America Equidistant Conic) accepted values: "na"   
  `reflat`, `reflong`, `sp1`, `sp2`: numeric, parameters for the projection if not using _type_ (reference latitude, reference longitude, and standard parallels)     
  example:    
  ```r
    cartesian <- projectionEquidistantConic(data$Latitude, data$Longitude, "na")
  ```

#### projectionNA    
  shortcut for projectionEquidistantConic(lat, long, "na")     
  `lat` and `long`: numeric vectors, same as _projectionEquidistantConic_           
  example:    
  ```r
    cartesian <- projectionNA(data$Latitude, data$Longitude)
  ```

#### generateRandomFlight    
  creates a dataframe of random flight data that is totally random and nothing like a real bird, but still useful for testing     
  `origin`: numeric vector of length 2, the coordinates where bird will start    
  `names`: character, "csg" or "movebank", depending on how you want the columns of the resulting data to be named    
  `obs`: numeric, number of observations to create     
  `maxturn`: numeric, the maximum change in heading in each step (measured in degrees, can turn _maxturn_ left or right)     
  `timestep`: numeric, the number of seconds between each observation    
  `timestart`: POSIXct, the time you want the first observation to be    
  `multi`: numeric, the distance the bird travels in each observation (in change in lat/long) will be a random number with a minimum of 0 and a maximum of multi    
  `rand`: function, a function that generates random numbers in [0,1], where the first parameter is the number of numbers to generate (default is normal distribution, mean=0.5, sd=0.125, limited to [0,1])     
  `fakemisc`: logical, if you want to fake the other columns needed for _bank_    
  `n`: numeric, the Animal_ID or FALSE to randomize it (used only if _fakemisc_ is TRUE)        
  example:    
  ```r
    dataG1 <- generateRandomFlight() #every parameter has a default value, running the function with no parameters will work fine
    dataG2 <- generateRandomFlight(origin=c(63.53, -150.27), obs=500)
  ```

## Data Input    
_bank_ uses specific column names of the data. Specifically, it needs columns named
"Animal_ID", "Date_Time", "GMT_offset", "Latitude", "Longitude", "KPH", "Heading", "Altitude", "HDOP"
and either "ASY" or "Season" and "SeasonYr"
