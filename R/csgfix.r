# Steve Runyon, Conservation Science Global, 2021
# last updated: 2021-06-08
# requires GDAL

#'changes data to Movebank format for use with ctmm package
#' @param data: dataframe, the input data
#' @param projectionType: boolean or character, FALSE if you don't want to convert lat/long to X/Y (if you want to use an existing X and Y). Accepted values: "North_America_Equidistant_Conic"
#' @param timeformat: character (format for use in as.POSIXct), the format Date_Time is in
#' @param ct: boolean, FALSE if you want time to be saved as a string in move bank format, TRUE if you want it as a POSIXct
#' @param coordFix: function, a function that converts lat and long at datetime to NAD83, inputs are vectors lat (numeric), long (numeric), and datetime (POSIXct). returns a data frame with columns "lat" and "long". FALSE if you don't want to change the coords at all.
bank <- function(data, projectionType="na", timeformat="%m/%d/%Y %T", ct=TRUE, coordFix=function(lat,long,n){return(data.frame(lat,long))} ){

  #adds "timestamp" column
  if(ct){
    timeline <- as.POSIXct(data$Date_Time, format="%m/%d/%Y %T", tz="GMT")
    data$timestamp <- timeline
  }
  else{
    timeline <- as.POSIXlt(data$Date_Time, format="%m/%d/%Y %T", tz="GMT")
    data$timestamp <- paste0((1900+timeline$year),"-",pad(timeline$mon,2),"-",pad(timeline$mday,2)," ",pad(timeline$hour,2),":",pad(timeline$min,2),":",pad(timeline$sec,2),".000")
  }

  #projects coordinates if using north america equidistant conic
  if(tolower(projectionType)%in%c("north_america_equidistant_conic", "na", "north america equidistant conic", "naec")){
    res <- coordFix(data$Latitude, data$Longitude, timeline) #gets coordinates in NAD83 as "res"
    res2 <- projectionNA(res$lat, res$long) #gets X and Y coordinates as "res"
    data$x <- res2$x
    data$y <- res2$y
  }

  if("GMT_offset"%in%colnames(data))
    data$study.timezone <- paste0("Etc/GMT",c("","+","+")[sign(data$GMT_offset)+2],data$GMT_offset) #adds a study.timezone column, with the time zone given as "Etc/GMT-9" for example
  data$sensor.type <- "gps" #adds a character "gps" called sensor.type

  ##removed local timestamp for now, timezones don't work properly
  #if("LocalTime"%in%colnames(data)){ #if there exists a "LocalTime" column
  #  if(ct){
  #    timeline <- as.POSIXct(data$LocalTime, format="%m/%d/%Y %T", tz=data$study.timezone)
  #    data$study.local.timestamp <- timeline
  #  }
  #  else{
  #    timeline <- as.POSIXlt(data$LocalTime, format="%m/%d/%Y %T", tz=data$study.timezone)
  #    data$study.local.timestamp <- paste0((1900+timeline$year),"-",pad(timeline$mon,2),"-",pad(timeline$mday,2)," ",pad(timeline$hour,2),":",pad(timeline$min,2),":",pad(timeline$sec,2),".000")
  #  }
  #  #adds "study.local.timestamp" column (same way as timestamp)
  #}

  #adds ASY column if there isn't already one
  if(!"ASY"%in%colnames(data) && all(c("Animal_ID","Season","SeasonYr")%in%colnames(data)))
      data$ASY <- paste0(data$Animal_ID, data$Season, data$SeasonYr) #adds "ASY" column, Animal_ID + Season + SeasonYr

  #renames columns
  oldcolnames <- c("Animal_ID","Latitude","Longitude","KPH","Heading","Altitude","HDOP")
  newcolnames <- c("individual.local.identifier","location.lat","location.long","ground.speed","heading","height.raw","gps.hdop")
  colnames(data)[match(oldcolnames,colnames(data))] <- newcolnames

  #limits data to necessary columns
  data <- data[c("ASY", "x", "y",
                   "timestamp", "individual.local.identifier", "study.timezone", "location.lat", "location.long",
                   "ground.speed", "heading", "sensor.type", "gps.hdop")] #, "study.local.timestamp"

  return(data)
}

#'projects lat and long coordinates to x and y with equidistant conic (simple conic) projection
#' @param lat: numeric vector, latitude (lat and long should be the same length)
#' @param long: numeric vector, longitude
#' @param type: boolean or character, FALSE to use your own parameters, or the name of a preset
#' @param reflat, reflong, sp1, sp2: numeric, parameters for the projection (reflat and reflong are reference latitude and longitude (origin), sp1 and sp2 are standard parallels)
projectionEquidistantConic <- function(lat, long, type=FALSE, reflat=0, reflong=0, sp1=20, sp2=60){
  if(type=="North_America_Equidistant_Conic"){ #if you want this to be equivalent to ArcGIS, it must use NAD83 here
    reflat <- 40
    reflong <- -96
    sp1 <- 20
    sp2 <- 60
  }
  nn <- (cos(sp1)-cos(sp2))/(sp2-sp1)
  G <- cos(sp1)/nn + sp1
  refrho <- G - reflat
  x <- c()
  y <- c()
  for(i in 1:length(lat)){
    rho <- G - lat[i]
    z <- nn*(long[i]-reflong)
    x <- append(x,  (rho*sin(z)) )
    y <- append(y, (refrho - rho*cos(z)) )
  }
  return(data.frame(x, y))
}

#'projects lat and long coordinates to x and y with North American equidistant conic projection
#' @param lat: numeric vector, latitude (lat and long should be the same length)
#' @param long: numeric vector, longitude
projectionNA <- function(lat, long){
  return(projectionEquidistantConic(lat, long, "North_America_Equidistant_Conic"))
}

#'converts coordinates from inType to outType
#' @param lat: numeric vector, latitude (lat, long, and datetime should be the same length)
#' @param long: numeric vector, longitude
#' @param datetime: POSIXct vector, the datetime when lat and long were recorded
#' @param inType: character, format that lat and long are in
#' @param outType: character, format that you want the coordinates converted to
fixCoords <- function(lat, long, datetime=FALSE, inType="WGS84", outType="NAD83"){
  #absolutely a work in progresss

  if(inType==outType)
    return(data.frame(lat=lat, long=long))

  #packages tried: htdp, gdalUtils
  # if i have to port over FORTRAN code...
  if(inType%in%c("WGS84","ITRF2000") && outType=="NAD83"){ # ITRF2000 (WHS84 (G1150)) to NAD83 (CORS96)
    require(sp)
    require(rgdal)
    coords <- data.frame(lat, long)
    coordinates(coords) <- c("long","lat") #adds coordinates to coords
    proj4string(coords) <- CRS("+init=epsg:4326 +ellps=WGS84 +datum=WGS84 +proj=longlat") #adds WGS84 CRS to coordinates
    coords <- spTransform(coords, CRS("+init=epsg:4269 +ellps=GRS80 +datum=NAD83")) #transforms to NAD83
    return(data.frame(lat=coords$lat, long=coords$long))
  }

  return(data.frame(lat=lat, long=long))
}

#'pads out an integer x to width with zeroes (to the left)
#' @param x: numeric or character, thing you want to pad
#' @param width: numberic, the width to pad to
pad <- function(x, width=3){
  return(formatC(x, width=width, format='d', flag='0'))
}

#'generates a fake flight data. it's all random so it doesn't behave like an actual bird.
#' @param origin: numeric vector of length 2, the coordinates where bird will start
#' @param names: character, "csg" or "movebank", depending on how you want the columns of the resulting data to be named
#' @param obs: numeric, number of observations to create
#' @param maxturn: numeric, the maximum change in heading in each step (measured in degrees). can turn maxturn left or right.
#' @param timestep: numeric, the number of seconds between each observation
#' @param timestart: POSIXct, the time you want the first observation to be
#' @param multi: numeric, the distance the bird travels in each observation (in change in lat/long) will be a random number in [0,multi)
#' @param fakemisc: boolean, if you want to fake the other columns needed for bank()
#' @param n: numeric, the Animal_ID or FALSE to randomize it
generateRandomFlight <- function(origin=c(0,0), names="csg", obs=1000, maxturn=15, timestep=3600, timestart=Sys.time(), multi=1/500, fakemisc=TRUE, n=FALSE){
  #work in progress
  names <- tolower(names)
   lat <- c(origin[1])
  long <- c(origin[2])
  head <- c(runif(1, min=0, max=360))
  time <- c(timestart)
  x <- 0
  while(x<(obs-1)){
    x <- x + 1
    dist <- stupidRnorm(1)*multi
      oh <- (head[x]-360*as.numeric(head[x]>180))*pi/180
     lat <- append( lat,  lat[x]+dist*sin(oh))
    long <- append(long, long[x]+dist*cos(oh))
    head <- append(head, (head[x]+(stupidRnorm(1)-0.5)*maxturn*2)%%360)
    time <- append(time, time[x]+timestep)
  }
  data <- data.frame(lat, long, head, time)
  #if(plot){ require(ggplot2)
  #     ggplot(data=data, aes(x=lat, y=long)) + geom_point() + geom_point(data=head(data,1), color='green') + geom_point(data=tail(data,1), color='red') + ylab("Longitude") + xlab("Latitude") }
  if(tolower(names)%in%c("csg"))
    colnames(data) <- c("Latitude", "Longitude", "Heading", "Date_Time")
  if(tolower(names)%in%c("movebank","mb","move"))
    colnames(data) <- c("location.lat", "location.long", "heading", "timestamp")
  if(fakemisc){
    if(n==FALSE)
      n <- floor(runif(1,min=1,max=1000))
      data$Animal_ID <- n
      data$ASY <- paste0(n, "Random", format(time[1], "%Y"))
      data$KPH <- 0
      data$Altitude <- 0
      data$HDOP <- 0 #0 temporarily, will make these something better later
      data$GMT_offset <- 0
  }
  return(data)
}

#' dumb thing to get random values with normal distribution, mean=0.5, sd=0.125, limited to [0,1]
#' @param n: numeric, number of numbers to generate
stupidRnorm <- function(n, mean=0.5, sd=0.125){
  x <- rnorm(n, mean=mean, sd=sd)
  x[x>1] <- x[x>1] - 1
  x[x<0] <- x[x<0] + 1
  return(x)
}

#' gets a Move object from data
#' @param data: dataframe, the input data for bank(data)
#' @param proj: CRS object, sent to move::move
#' @param removeDuplicatedTimestamps: boolean, sent to move::move
quickMove <- function(data, proj=CRS("+init=epsg:4326 +proj=longlat +ellps=WGS84 +datum=WGS84"), removeDuplicatedTimestamps=FALSE){
  require(move)
  b <- bank(data, coordFix = fixCoords)
  return(move(x=b$x, y=b$y, time=b$timestamp, proj=proj, data=b, animal=b$individual.local.identifier, sensor=b$sensor, removeDuplicatedTimestamps=removeDuplicatedTimestamps))
}
