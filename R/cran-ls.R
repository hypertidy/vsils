utils::globalVariables(c("package", "driver", "dsn", "path"))

#' Refresh a cached CRAN packages DB.
#'
#' The vsils function `cran_package_db()` is *memoized*, meaning that its output
#' is cached by the memoise package, with a timeout every hour. Manually bust this
#' cache by running `cran_db_refresh()`.
#'
#' @returns logical TRUE, or FALSE if no such cache existed
#' @export
#'
#' @examples
#' \dontrun{
#' cran_db_refresh()
#' }
cran_db_refresh <- function() {
  memoise::forget(cran_package_db)
}

#' Scan a CRAN package for GDAL-readable files
#'
#' Queries a package source tarball directly from CRAN (via `/vsitar//vsicurl/`)
#' and identifies files that GDAL can read. No download required.
#'
#' @param package Character string, name of a package available on CRAN.
#'
#' @returns A tibble with columns:
#'
#' - `package`: the package name
#' - `driver`: GDAL driver name (e.g. "GTiff", "GPKG", "netCDF")
#' - `dsn`: full GDAL-readable URI to the file
#'
#' Returns `NULL` if no GDAL-readable files are found.
#'
#' @details
#' The function reads the package tarball directly from CRAN using GDAL's
#' virtual file system handlers (`/vsitar/` and `/vsicurl/`), so files can
#' be identified without downloading the entire package.
#'
#' The returned `dsn` values can be opened directly with GDAL-based tools
#' (e.g. `new(gdalraster::GDALVector, )`, `new(gdalraster::GDALRaster, )`, `terra::vect()`,
#' `terra::rast()`, `sf::read_sf()`).
#'
#' Some false positives may occur (e.g. CSV files detected as spatial, PNG
#' logos, orphan shapefile sidecars). The XYZ driver in particular may
#' incorrectly match spatial weights files (.gal, .gwt).
#'
#'
#' @export
#'
#' @examples
#' scan_package("gdalraster")
#'
#'
#' # Scan multiple packages
#' packages <- c("spData", "gdalraster", "sf", "terra", "stars", "vapour")
#' results <- purrr::map_dfr(packages, purrr::possibly(scan_package, NULL))
#'
#' # reference a discovered file directly
#' gpkg <- dplyr::filter(results, package == "spData", driver == "GPKG") |> dplyr::slice(1L)
#' v <- new(gdalraster::GDALVector, gpkg$dsn)
#' v$info()
#' v$close()
scan_package <- function(package) {
  stopifnot(length(package) == 1L)
  stopifnot(is.character(package))
  base_uri <- package_gdal_uri(package)
  paths <- cull_paths(package_ls(package))
  if (length(paths) < 1L) return(NULL)
  uris <- paste0(base_uri, "/", paths)

  purrr::map_chr(uris, \(u) identify_safe(u)) |>
    purrr::set_names(paths) |>
    {\(x) x[!is.na(x)]}() |>
    tibble::enframe(name = "path", value = "driver") |>
    dplyr::mutate(
      package = package,
      #sysfile = stringr::str_replace(path, paste0("^", package, "/inst/"), ""),
      dsn = paste0(base_uri, "/", path)
    ) |>
    dplyr::select(package,  driver, dsn)
}



package_source_url <- function(package, cran = getOption("repos")[["CRAN"]]) {
  if (is.null(cran) || cran == "@CRAN@") {
    cran <- "https://cloud.r-project.org/"
  }
  db <- cran_package_db()
  idx <- match(package, db$Package)
  if (is.na(idx) || length(idx) < 1L) stop(sprintf("no package found '%s' on '%s'", package, cran))
  sprintf("%ssrc/contrib/%s_%s.tar.gz", cran, package, db$Version[idx])
}
package_gdal_uri <- function(package) {
  sprintf("/vsitar//vsicurl/%s", package_source_url(package))
}
package_ls <- function(package) {
  gdalraster::vsi_read_dir(package_gdal_uri(package), recursive = TRUE)
}


obvious_avoids <- function() {
  skip <- c(
    ## bare directories
    "/$",
    ## but consider adding
    #spatial_dirs <- c("\\.gdb/?$", ".sdat$", "\\.zarr/?$", "\\.parquet/?$")

    ## found in sf
    "\\.drawio$", "\\.fig$", "\\.repo$",
    # R source/docs
    "\\.R$", "\\.r$", "\\.Rmd$", "\\.Rnw$", "\\.Rd$", "\\.Rproj$",
    "\\.rds$", "\\.rda$", "\\.RData$", "\\.rdb$", "\\.rdx$",

    # C/C++/Fortran
    "\\.cpp$", "\\.c$", "\\.h$", "\\.hpp$", "\\.hh$",
    "\\.f$", "\\.f90$", "\\.f95$", "\\.for$",
    "\\.o$", "\\.so$", "\\.dll$", "\\.a$", "\\.dylib$",
    # Python
    "\\.py$",

    # Rust (savvy!)
    "\\.rs$", "\\.rlib$",

    # Web/docs
    "\\.html$", "\\.htm$", "\\.css$", "\\.js$", "\\.ts$",
    "\\.md$", "\\.txt$", "\\.pdf$", "\\.tex$", "\\.bib$",
    "\\.svg$", "\\.ico$", "\\.gif$",   # non-geo images
    "\\.woff2?$", "\\.ttf$", "\\.eot$", # fonts

    # Config/meta
    "\\.yml$", "\\.yaml$", "\\.json$", "\\.toml$", "\\.dcf$",
    # "\\.xml$",  # risky - some are spatial (KML/GML) but most in packages aren't
    #  "\\.csv$",  # could be spatial but usually not in packages

    "\\.gal$", "\\.gwt$", "\\.swm$",  # spatial weights,

    # Package boilerplate (no extension)
    "DESCRIPTION$", "NAMESPACE$", "LICENSE.*$", "NEWS.*$", "README.*$",
    "Makevars.*$", "configure.*$", "cleanup.*$",
    "\\.Rbuildignore$", "\\.Rinstignore$", "\\.gitignore$",

    #"\\.png$", "\\.jpg$", "\\.jpeg$",  # non-geo images (unless you want worldfiles?)
    #"\\.bmp$", "\\.eps$", "\\.ps$",
    "\\.rmd$",  # you have .Rmd but case matters without ignore.case
    "\\.qmd$",  # quarto
    "\\.stan$", # stan models
    "\\.bug$", "\\.jags$",  # BUGS/JAGS models
    "\\.jar$",  # java
    "\\.mo$", "\\.po$", "\\.pot$",  # translations
    "^\\._",  # macOS resource forks if they sneak in
    "\\.DS_Store$",
    #"\\bman/.*",  # whole man/ directory is all .Rd anyway
    #"\\bR/.*",    # whole R/ directory

    ".*MD5$",
    # Test artifacts
    "\\.Rout.*$"
  )
}

cull_paths <- function(x, skip = obvious_avoids()) {
  pattern <- paste(skip, collapse = "|")
  x[!grepl(pattern, x, ignore.case = TRUE)]

}

identify_safe <- function(uri) {
  tryCatch(
    {
      drv <- gdalraster::identifyDriver(uri)
      if (is.null(drv) || drv == "") NA_character_ else drv
    },
    error = function(e) NA_character_
  )
}





