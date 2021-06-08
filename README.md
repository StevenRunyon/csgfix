# csgfix
a simple R package for fixing data for use with the ctmm package

the main function is `bank(data)`. this converts data from our format to the Movebank format (`move(bank(data))`).
you can also generate data to test with using `generateRandomFlight()`.
`projectionNA(lat, long)` projects lat and long to x and y using North America Equidistant Conic projection.
