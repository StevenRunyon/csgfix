# Steve Runyon, Conservation Science Global, 2021
# last updated: 2021-06-08
# requires GDAL

#'changes data to Movebank format for use with ctmm package
#' @param data: dataframe, the input data
#' @param projectionType: character or function, NULL if you don't want to convert lat/long to X/Y (if you want to use an existing X and Y). Otherwise a character (the name of a projection), or a function(lat, long, datetime) where lat and long are vectors of numbers and datetime is a vector of POSIXct corresponding to the time of those observations. should return a data frame with two numeric columns, x and y
#' @param timeformat: character (format for use in as.POSIXct), the format Date_Time is in
#' @param ct: boolean, FALSE if you want time to be saved as a string in move bank format, TRUE if you want it as a POSIXct
#' @param tonad83: boolean, TRUE if you want to convert from WGS84 to NAD83 before projection (only used when projectionType is a character)
bank <- function(data, projectionType="na", timeformat="%m/%d/%Y %T", ct=TRUE, tonad83=FALSE){

  #adds "timestamp" column
  if(ct){
    timeline <- as.POSIXct(data$Date_Time, format=timeformat, tz="GMT")
    data$timestamp <- timeline
  }
  else{
    timeline <- as.POSIXlt(data$Date_Time, format=timeformat, tz="GMT")
    data$timestamp <- paste0((1900+timeline$year),"-",pad(timeline$mon,2),"-",pad(timeline$mday,2)," ",pad(timeline$hour,2),":",pad(timeline$min,2),":",pad(timeline$sec,2),".000")
  }

  # if X and Y, changes them to x and y
  if("X"%in%colnames(data) && "Y"%in%colnames(data)){
    colnames(data)[colnames(data)=="X"] <- "x"
    colnames(data)[colnames(data)=="Y"] <- "y"
  }

  # if no x and y, projects lat and long
  if(!"x"%in%colnames(data) && !"y"%in%colnames(data)){

    #projects coordinates
    if(!is.null(projectionType)){
      if(projectionType==FALSE)
        res <- data.frame(y=data$Latitude, x=data$Longitude)
      else if(typeof(projectionType)%in%c("closure","special","builtin"))
        res <- projectionType(data$Latitude, data$Longitude, timeline)
      else{
        projectionType <- tolower(projectionType)
        if(tonad83)
          outType <- "NAD83"
        else
          outType <- "WGS84"
        if(projectionType%in%c("north_america_equidistant_conic", "na", "north america equidistant conic", "naec")){
          #res <- coordFix(data$Latitude, data$Longitude, timeline) #gets coordinates in NAD83 as "res"
          res <- fixCoords(data$Latitude, data$Longitude, "WGS84", outType)
          res <- projectionNA(res$lat, res$long) #gets X and Y coordinates as "res"
        }
      }
      data$x <- res$x
      data$y <- res$y
    }

  }

  if("GMT_offset"%in%colnames(data))
    data$study.timezone <- paste0("Etc/GMT",c("","+","+")[sign(data$GMT_offset)+2],data$GMT_offset) #adds a study.timezone column, with the time zone given as "Etc/GMT-9" for example
  data$sensor.type <- "gps" #adds a character "gps" called sensor.type

  #adds ASY column if there isn't already one
  if(!"ASY"%in%colnames(data) && all(c("Animal_ID","Season","SeasonYr")%in%colnames(data)))
      data$ASY <- paste0(data$Animal_ID, data$Season, data$SeasonYr) #adds "ASY" column, Animal_ID + Season + SeasonYr

  #renames columns
  oldcolnames <- c("Animal_ID","Latitude","Longitude","KPH","Heading","Altitude","HDOP")
  newcolnames <- c("individual.local.identifier","location.lat","location.long","ground.speed","heading","height.raw","gps.hdop")
  #colnames(data)[match(oldcolnames,colnames(data))] <- newcolnames
   for(x in 1:length(oldcolnames)){
     y <- grep(oldcolnames[x], colnames(data))
     if(length(y)!=0)
       colnames(data)[colnames(data)==oldcolnames[x]] <- newcolnames[x]
   }

  #limits data to necessary columns
  realcolnames <- c("ASY", "x", "y", "timestamp", "individual.local.identifier", "study.timezone", "location.lat", "location.long", "ground.speed", "heading", "sensor.type", "gps.hdop", "study.local.timestamp")
  y <- c() #y will be a vector that tracks the column indecies we want to keep
  for(x in 1:ncol(data)){
    if(colnames(data)[x]%in%realcolnames)
      y <- append(y, x)
  }
  data <- data[y] #limits the columns to the ones we want to keep

  if("ASY"%in%colnames(data) && !"individual.local.identifier"%in%colnames(data))
    data$individual.local.identifier <- data$ASY #adds the ASY as individual.local.identifier if there isn't already one

  return(data)
}

#'projects lat and long coordinates to x and y with equidistant conic (simple conic) projection
#' @param lat: numeric vector, latitude (lat and long should be the same length)
#' @param long: numeric vector, longitude
#' @param type: character, NULL to use your own parameters, or the name of a preset
#' @param reflat, reflong, sp1, sp2: numeric, parameters for the projection (reflat and reflong are reference latitude and longitude (origin), sp1 and sp2 are standard parallels)
projectionEquidistantConic <- function(lat, long, type=NULL, reflat=0, reflong=0, sp1=20, sp2=60){
  if(!is.null(type)){
    if(type=="North_America_Equidistant_Conic"){ #if you want this to be equivalent to ArcGIS, it must use NAD83 here
      reflat <- 40
      reflong <- -96
      sp1 <- 20
      sp2 <- 60
    }
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
projectionNA <- function(lat, long, v2=NULL){
  return(projectionEquidistantConic(lat, long, "North_America_Equidistant_Conic"))
}

#'projects lat and long coordinates to x and y with cylindrical equal area projection
#' @param lat: numeric vector, latitude (lat and long should be the same length)
#' @param long: numeric vector, longitude
#' @param type: character, NULL to use your own parameters, or the name of a preset ("lambert","behrmann","gall",...)
#' @param standardlong, standardlat: numeric, parameters for the projection
projectionCylindricalEqualArea <- function(lat, long, type=NULL, standardlat=0, standardlong=0){
  if(!is.null(type) && typeof(type)=="character"){
    type <- tolower(type)
    if(type%in%c("lambert","l","0"))
      standardlat <- 0
    else if(type%in%c("behrmann","behrman","b","30"))
      standardlat <- pi/6
    else if(type%in%c("smyth","smyth equal-surface","craster","craster rectangular","2:1","1:2","2"))
      standardlat <- arccos(2/pi)
    else if(type%in%c("edwards","trystan edwards","te","e"))
      standardlat <- 37.24*(pi/180)
    else if(type%in%c("hobo-dyer","dyer","hobo–dyer","hd","d"))
      standardlat <- 37.30*(pi/180)
    else if(type%in%c("gall-peters","gall","gall–peters","gall orthographic","peters","gp","g","45"))
      standardlat <- pi/4
    else if(type%in%c("balthasart","m","50"))
      standardlat <- 5*pi/18
    else if(type%in%c("tobler","square","world in a square","tobler's world in a square","1:1","1"))
      standardlat <- arccos(1/pi)
  }
  x <- (long-standardlong)*cos(standardlat)
  y <- sin(lat)/cos(standardlat)
  return(data.frame(x, y))
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
#' @param rand: function, a function that generates random numbers in [0,1], where the first parameter is the number of numbers to generate
#' @param fakemisc: boolean, if you want to fake the other columns needed for bank()
#' @param n: numeric, the Animal_ID or NULL to randomize it
generateRandomFlight <- function(origin=c(0,0), names="csg", obs=1000, maxturn=15, timestep=3600, timestart=Sys.time(), multi=1/500, rand=stupidRnorm, fakemisc=TRUE, n=NULL){
  #work in progress
  names <- tolower(names)
   lat <- c(origin[1])
  long <- c(origin[2])
  head <- c(runif(1, min=0, max=360))
  time <- c(timestart)
  x <- 0
  while(x<(obs-1)){
    x <- x + 1
    dist <- rand(1)*multi
      oh <- (head[x]-360*as.numeric(head[x]>180))*pi/180
     lat <- append( lat,  lat[x]+dist*sin(oh))
    long <- append(long, long[x]+dist*cos(oh))
    head <- append(head, (head[x]+(rand(1)-0.5)*maxturn*2)%%360)
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
    if(is.null(n))
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



#'converts coordinates from inType to outType (DOES NOT WORK AT THE MOMENT)
#' @param lat: numeric vector, latitude (lat, long, and datetime should be the same length)
#' @param long: numeric vector, longitude
#' @param inType: character, format that lat and long are in
#' @param outType: character, format that you want the coordinates converted to
#' @param datetime: POSIXct vector, the datetime when lat and long were recorded (currently unused)
fixCoords <- function(lat, long, inType="WGS84", outType="NAD83", datetime=NULL){
  #absolutely a work in progresss

  coordf <- data.frame(lat=lat, long=long)

  if(inType==outType)
    return(coordf)

  require(sf)

  inType <- tolower(inType)
  outType <- tolower(outType)

  #creates a sf object with the existing crs
  if(inType%in%c("wgs84","itrf2000","wgs","w","g1150"))
    coordf <- st_as_sf(coordf, coords=c("long","lat"), crs=4326)
  else if(inType%in%c("nad83","nad","n","cors96","nad83 (cors96)"))
    coordf <- st_as_sf(coordf, coords=c("long","lat"), crs=4269)

  #converts datum?
  if(outType%in%c("nad83","nad","n","cors96","nad83 (cors96)")) # ITRF2000 (WHS84 (G1150)) to NAD83 (CORS96)
    coordf <- st_transform(coordf, crs=4269, type="datum")
  else if(outType%in%c("wgs84","itrf2000","wgs","w","g1150"))
    coordf <- st_transform(coordf, crs=4326, type="datum")

  coordf <- st_coordinates(coordf) #changes geometry points to data frame of numeric columns lat and long, then returns it
  return(data.frame(lat=coordf[,2], long=coordf[,1]))
}

#' gets a Move object from data
#' @param data: dataframe, the input data for bank(data)
#' @param proj: CRS object, sent to move::move
#' @param timeformat: character (format for use in as.POSIXct), the format Date_Time is in
#' @param removeDuplicatedTimestamps: boolean, sent to move::move
#' @param projectionType: character or function, sent to bank
quickMove <- function(data, proj=CRS("+init=epsg:4326 +ellps=WGS84 +datum=WGS84 +no_defs +proj=eqdc +lat_1=20 +lat_2=60 +lat_0=0 +lon_0=0"), timeformat="%m/%d/%Y %H:%M", removeDuplicatedTimestamps=FALSE, projectionType=NULL){
  require(move)
  b <- bank(data, projectionType, timeformat)
  m <- move::move(x=b$x, y=b$y, time=b$timestamp, data=b, proj=proj, sensor=b$sensor, animal=b$individual.local.identifier, removeDuplicatedTimestamps=removeDuplicatedTimestamps)
  return(m)
}

#' gets a Telemetry object from data, shortcut for ctmm::as.telemetry(quickMove(data, ...))
#' @param data: dataframe, the input data for bank(data)
#' @param proj: CRS object, sent to move::move
#' @param timeformat: character (format for use in as.POSIXct), the format Date_Time is in
#' @param removeDuplicatedTimestamps: boolean, sent to move::move
#' @param projectionType: character or function, sent to bank
quickTelemetry <- function(data, proj, timeformat){
  require(ctmm)
  m <- quickMove(data, proj, timeformat, removeDuplicatedTimestamps, projectionType)
  t <- ctmm::as.telemetry(m)
  return(t)
}
