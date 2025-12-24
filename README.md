
# vsils

<!-- badges: start -->

[![R-CMD-check](https://github.com/hypertidy/vsils/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/hypertidy/vsils/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

Scan CRAN packages for GDAL-readable files — without downloading
anything.

vsils queries package source tarballs directly from CRAN using GDAL’s
virtual file system (`/vsitar//vsicurl/`) and identifies spatial data
files by driver.

## Installation

``` r
# install.packages("pak")
pak::pak("mdsumner/vsils")
```

## Example

Scan a single package:

``` r
library(vsils)

scan_package("spData")
#> # A tibble: 19 × 3
#>    package driver         dsn                                                   
#>    <chr>   <chr>          <chr>                                                 
#>  1 spData  CSV            /vsitar//vsicurl/https://CRAN.r-project.org/src/contr…
#>  2 spData  ESRI Shapefile /vsitar//vsicurl/https://CRAN.r-project.org/src/contr…
#>  3 spData  ESRI Shapefile /vsitar//vsicurl/https://CRAN.r-project.org/src/contr…
#>  4 spData  CSV            /vsitar//vsicurl/https://CRAN.r-project.org/src/contr…
#>  5 spData  CSV            /vsitar//vsicurl/https://CRAN.r-project.org/src/contr…
#>  6 spData  GTiff          /vsitar//vsicurl/https://CRAN.r-project.org/src/contr…
#>  7 spData  GTiff          /vsitar//vsicurl/https://CRAN.r-project.org/src/contr…
#>  8 spData  GPKG           /vsitar//vsicurl/https://CRAN.r-project.org/src/contr…
#>  9 spData  GPKG           /vsitar//vsicurl/https://CRAN.r-project.org/src/contr…
#> 10 spData  GPKG           /vsitar//vsicurl/https://CRAN.r-project.org/src/contr…
#> 11 spData  GPKG           /vsitar//vsicurl/https://CRAN.r-project.org/src/contr…
#> 12 spData  GPKG           /vsitar//vsicurl/https://CRAN.r-project.org/src/contr…
#> 13 spData  GeoJSON        /vsitar//vsicurl/https://CRAN.r-project.org/src/contr…
#> 14 spData  GeoJSON        /vsitar//vsicurl/https://CRAN.r-project.org/src/contr…
#> 15 spData  GPKG           /vsitar//vsicurl/https://CRAN.r-project.org/src/contr…
#> 16 spData  GPKG           /vsitar//vsicurl/https://CRAN.r-project.org/src/contr…
#> 17 spData  GPKG           /vsitar//vsicurl/https://CRAN.r-project.org/src/contr…
#> 18 spData  GPKG           /vsitar//vsicurl/https://CRAN.r-project.org/src/contr…
#> 19 spData  PNG            /vsitar//vsicurl/https://CRAN.r-project.org/src/contr…
#> # A tibble: 20 × 3
#>    package driver  dsn
#>    <chr>   <chr>   <chr>
#>  1 spData  GTiff   /vsitar//vsicurl/https://CRAN.r-project.org/src/contrib/spData_2.3.4.tar.gz/spData/inst/raster/elev.tif
#>  2 spData  GPKG    /vsitar//vsicurl/https://CRAN.r-project.org/src/contrib/spData_2.3.4.tar.gz/spData/inst/shapes/world.gpkg
#>
#> # ... 
```

Scan multiple packages:

``` r
packages <- c("gdalraster", "geotargets", "png", "sf", "sfdct", "spData", 
"stars", "terra", "tidync", "vapour")

results <- purrr::map(packages, purrr::possibly(scan_package, NULL), .progress = TRUE) |>
  purrr::list_rbind()
#> ■■■■ 10% | ETA: 22s ■■■■■■■ 20% | ETA: 17s ■■■■■■■■■■ 30% | ETA: 12s
#> ■■■■■■■■■■■■■ 40% | ETA: 14s ■■■■■■■■■■■■■■■■ 50% | ETA: 12s
#> ■■■■■■■■■■■■■■■■■■■ 60% | ETA: 9s ■■■■■■■■■■■■■■■■■■■■■■ 70% | ETA: 7s
#> ■■■■■■■■■■■■■■■■■■■■■■■■■ 80% | ETA: 5s ■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 90% | ETA:
#> 2s
#> GDAL FAILURE 1: PROJ: proj_create: unrecognized format / unknown name
#> 

results |>
  dplyr::count(driver, sort = TRUE)
#> # A tibble: 18 × 2
#>    driver             n
#>    <chr>          <int>
#>  1 GTiff             31
#>  2 ESRI Shapefile    29
#>  3 netCDF            24
#>  4 GPKG              22
#>  5 PNG               10
#>  6 CSV                9
#>  7 GeoJSON            4
#>  8 SQLite             4
#>  9 OSM                3
#> 10 GML                2
#> 11 FlatGeobuf         1
#> 12 HDF5               1
#> 13 LCP                1
#> 14 MapInfo File       1
#> 15 OpenFileGDB        1
#> 16 RRASTER            1
#> 17 WMS                1
#> 18 XYZ                1
```

## Open files directly

The `dsn` column works with any GDAL-based tool:

``` r
res <- scan_package("spData")
gpkg <- res$dsn[res$driver == "GPKG"][1]

terra::vect(gpkg)
#>  class       : SpatVector 
#>  geometry    : polygons 
#>  dimensions  : 281, 12  (geometries, attributes)
#>  extent      : 357628, 480360.3, 4649538, 4808317  (xmin, xmax, ymin, ymax)
#>  source      : NY8_bna_utm18.gpkg (sf_bna2_utm18)
#>  coord. ref. : UTM Zone 18, Northern Hemisphere 
#>  names       :     AREAKEY        AREANAME     X      Y  POP8 TRACTCAS  PROPCAS
#>  type        :       <chr>           <chr> <num>  <num> <num>    <num>    <num>
#>  values      : 36007000100 Binghamton city 4.069 -67.35  3540     3.08  0.00087
#>                36007000200 Binghamton city 4.639 -66.86  3560     4.08 0.001146
#>                36007000300 Binghamton city 5.709 -66.98  3739     1.09 0.000292
#>  PCTOWNHOME PCTAGE65P       Z AVGIDIST PEXPOSURE
#>       <num>     <num>   <num>    <num>     <num>
#>      0.3277    0.1466   0.142   0.2374     3.167
#>      0.4268    0.2351  0.3555   0.2087     3.039
#>      0.3377     0.138 -0.5817   0.1709     2.838
```

No download required — GDAL streams the data directly from CRAN.

## Drivers found

Example from scanning a handful of spatial packages:

    AAIGrid, CSV, ESRI Shapefile, FlatGeobuf, GML, GPKG, GTiff, 
    GeoJSON, HDF5, LCP, MapInfo File, OSM, OpenFileGDB, PNG, 
    RRASTER, SQLite, WMS, XYZ, netCDF

E.g.

``` r
print(sort(unique(results$driver)))
#>  [1] "CSV"            "ESRI Shapefile" "FlatGeobuf"     "GeoJSON"       
#>  [5] "GML"            "GPKG"           "GTiff"          "HDF5"          
#>  [9] "LCP"            "MapInfo File"   "netCDF"         "OpenFileGDB"   
#> [13] "OSM"            "PNG"            "RRASTER"        "SQLite"        
#> [17] "WMS"            "XYZ"
```

## Notes

- Some false positives occur (e.g. CSV, PNG logos, XYZ matching spatial
  weights files)
- Orphan shapefile sidecars (.dbf, .shx) detected as “ESRI Shapefile”
- The CRAN package database is memoised for the session; use
  `cran_db_refresh()` to clear

## See also

- [gdalraster](https://github.com/USDAForestService/gdalraster) — the
  engine under the hood
- [GDAL Virtual File
  Systems](https://gdal.org/user/virtual_file_systems.html)

## Code of Conduct

Please note that the vsils project is released with a [Contributor Code
of
Conduct](https://contributor-covenant.org/version/2/1/CODE_OF_CONDUCT.html).
By contributing to this project, you agree to abide by its terms.
