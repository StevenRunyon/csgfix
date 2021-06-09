# csgfix
A simple R package for fixing data for use with the `ctmm` package

## Installation


The package can be installed from GitHub using the `devtools` package.    
```r
#install.packages("devtools")
devtools::install_github("StevenRunyon/csgfix")
```

In addition, the `fixCoords` function requires the packages `sp` and `rgdal`. These can be downloaded from CRAN.    
```r
install.packages("sp")
install.packages("rgdal")
```   
rgdal requires GDAL version >= 1.11.4, and PROJ version >= 4.8.0.

## Functions and Parameters
#### bank
  the primary function of the package, changes data from the input format to a data frame in the Movebank format (for use with the _move_ function)    
  `data`: dataframe, see "Data Input"    
  `projectionType`: boolean or character, FALSE or the name of a projection (like "na" for North America Equidistant Conic)     
  `timeformat`: character, the format Date_Time is in (for use with as.POSIXct)    
  `ct`: boolean, TRUE to use POSIXct timestamps, FALSE to use characters that are in the Movebank format    
  `coordFix`: function, a function that returns a data frame with "lat" and "long" in the desired , it has 3 inputs, numeric vectors for lat and long and a POSIXct vector for timestamp    
    (by default, this simply returns a dataframe of the first two inputs)

#### quickMove    
  shortcut for creating Move object from data   
  `data`: dataframe, the data used for _bank_   
  `proj`: CRS object, the projection type for _move::move_    
  `removeDuplicatedTimestamps`: boolean, just what it says, sent to _move::move_    

#### projectionEquidistantConic    
  projects lat and long to x and y using equidistant conic projection    
  `lat` and `long`: numeric vectors of latitude and longitude (to be equivalent to ArcGIS, these must be in NAD83)     
  `type`: boolean or character, FALSE or the name of a preset set of parameters (like "na" for North America Equidistant Conic)    
  `reflat`, `reflong`, `sp1`, `sp2`: numeric, parameters for the projection if not using _type_ (reference latitude, reference longitude, and standard parallels)    

#### projectionNA    
  shortcut for projectionEquidistantConic(lat, long, "na")     
  `lat` and `long`: numeric vectors, same as _projectionEquidistantConic_       
   
#### fixCoords    
  a function meant to change coordinates from inType to outType      
  right now it uses the _spTransform_ function to change this type but it gives the same input, so it doesn't seem to be working properly right now
  because of this, this function can be ignored for now    
  `lat` and `long`: numeric vectors of latitude and longitude in inType    
  `datetime`: POSIXct vector of datetime if it's needed (currently unused, ignore this)    
  `inType`: character, name of the coordinate type _lat_ and _long_ are in (currently supports "WGS84")     
  `outType`: character, name of the coordinate type you want to convert to (currently supports "NAD83")    

#### generateRandomFlight    
  creates a dataframe of random flight data that is totally random and nothing like a real bird, but still useful for testing     
  `origin`: numeric vector of length 2, the coordinates where bird will start    
  `names`: character, "csg" or "movebank", depending on how you want the columns of the resulting data to be named    
  `obs`: numeric, number of observations to create    
  `maxturn`: numeric, the maximum change in heading in each step (measured in degrees, can turn _maxturn_ left or right)
  `timestep`: numeric, the number of seconds between each observation    
  `timestart`: POSIXct, the time you want the first observation to be    
  `multi`: numeric, the distance the bird travels in each observation (in change in lat/long) will be a random number with a minimum of 0 and a maximum of multi    
  `fakemisc`: boolean, if you want to fake the other columns needed for _bank_    
  `n`: numeric, the Animal_ID or FALSE to randomize it (used only if _fakemisc_ is TRUE)    
 
## Data Input    
`bank` uses specific column names of the data. Specifically, it needs columns named
"Animal_ID", "Date_Time", "GMT_offset", "Latitude", "Longitude", "KPH", "Heading", "Altitude", "HDOP"
and either "ASY" or "Season" and "SeasonYr"
