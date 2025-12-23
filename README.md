
# vsils

<!-- badges: start -->

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
packages <- c("spData", "sf", "terra", "stars", "gdalraster")

results <- purrr::map(packages, purrr::possibly(scan_package, NULL), .progress = TRUE) |>
  purrr::list_rbind()

results |>
  dplyr::count(driver, sort = TRUE)
```

## Open files directly

The `dsn` column works with any GDAL-based tool:

``` r
res <- scan_package("spData")
gpkg <- res$dsn[res$driver == "GPKG"][1]

sf::st_read(gpkg, quiet = TRUE)
```

No download required — GDAL streams the data directly from CRAN.

## Drivers found

Example from scanning a handful of spatial packages:

    AAIGrid, CSV, ESRI Shapefile, FlatGeobuf, GML, GPKG, GTiff, 
    GeoJSON, HDF5, LCP, MapInfo File, OSM, OpenFileGDB, PNG, 
    RRASTER, SQLite, WMS, XYZ, netCDF

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
