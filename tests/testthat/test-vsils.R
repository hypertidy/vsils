# tests/testthat/test-vsils.R

# --- cull_paths ---

test_that("cull_paths removes R source files", {
  paths <- c("pkg/R/foo.R", "pkg/R/bar.r", "pkg/inst/data.gpkg")
  expect_equal(cull_paths(paths), "pkg/inst/data.gpkg")
})

test_that("cull_paths removes compiled files", {
  paths <- c("pkg/src/code.cpp", "pkg/src/code.c", "pkg/src/code.o",
             "pkg/src/pkg.so", "pkg/inst/raster.tif")
  expect_equal(cull_paths(paths), "pkg/inst/raster.tif")
})

test_that("cull_paths removes documentation", {
  paths <- c("pkg/man/foo.Rd", "pkg/README.md", "pkg/NEWS.md",
             "pkg/vignettes/intro.Rmd", "pkg/inst/shapes.shp")
  expect_equal(cull_paths(paths), "pkg/inst/shapes.shp")
})

test_that("cull_paths removes package boilerplate", {
  paths <- c("pkg/DESCRIPTION", "pkg/NAMESPACE", "pkg/LICENSE",
             "pkg/LICENSE.md", "pkg/inst/extdata/file.gpkg")
  expect_equal(cull_paths(paths), "pkg/inst/extdata/file.gpkg")
})

test_that("cull_paths removes spatial weights files", {
  paths <- c("pkg/inst/weights/nb.gal", "pkg/inst/weights/dist.gwt",
             "pkg/inst/weights/mat.swm", "pkg/inst/shapes/world.gpkg")
  expect_equal(cull_paths(paths), "pkg/inst/shapes/world.gpkg")
})

test_that("cull_paths removes directories (trailing slash)", {
  paths <- c("pkg/", "pkg/inst/", "pkg/inst/extdata/", "pkg/inst/extdata/raster.tif")
  expect_equal(cull_paths(paths), "pkg/inst/extdata/raster.tif")
})

test_that("cull_paths is case insensitive", {
  paths <- c("pkg/R/FOO.R", "pkg/src/CODE.CPP", "pkg/inst/DATA.GPKG")
  expect_equal(cull_paths(paths), "pkg/inst/DATA.GPKG")
})

test_that("cull_paths keeps potential spatial files", {
  keepers <- c("pkg/inst/extdata/raster.tif",
               "pkg/inst/extdata/vector.gpkg",
               "pkg/inst/extdata/points.shp",
               "pkg/inst/extdata/data.csv",
               "pkg/inst/extdata/image.png",
               "pkg/inst/extdata/grid.nc")
  expect_equal(cull_paths(keepers), keepers)
})

test_that("cull_paths handles empty input", {
  expect_equal(cull_paths(character(0)), character(0))
})

test_that("cull_paths handles all-filtered input", {
  paths <- c("pkg/R/foo.R", "pkg/DESCRIPTION", "pkg/NAMESPACE")
  expect_equal(cull_paths(paths), character(0))
})

# --- obvious_avoids ---

test_that("obvious_avoids returns character vector", {
  avoids <- obvious_avoids()
  expect_type(avoids, "character")
  expect_true(length(avoids) > 0)
})

test_that("obvious_avoids patterns are valid regex", {
  avoids <- obvious_avoids()
  # Should not error when compiled

  expect_no_error(paste(avoids, collapse = "|"))
  expect_no_error(grepl(paste(avoids, collapse = "|"), "test.R"))
})

# --- identify_safe ---

test_that("identify_safe returns NA_character_ on error", {
  result <- identify_safe("/nonexistent/path/file.tif")
  expect_true(is.na(result))
  expect_type(result, "character")
})

test_that("identify_safe returns NA_character_ for non-GDAL files", {
  skip_if_not_installed("gdalraster")
  # Create a temp text file

  tmp <- tempfile(fileext = ".xyz")
  writeLines("not a spatial file", tmp)
  result <- identify_safe(tmp)
  # May return NA or a driver depending on GDAL's sniffing

  expect_type(result, "character")
  unlink(tmp)
})

# --- package_source_url ---

test_that("package_source_url constructs valid URL", {
  skip_if_offline()
  url <- package_source_url("gdalraster")
  expect_match(url, "^https://")
  expect_match(url, "gdalraster")
  expect_match(url, "\\.tar\\.gz$")
})

test_that("package_source_url handles @CRAN@ placeholder", {
  skip_if_offline()
  url <- package_source_url("gdalraster", cran = "@CRAN@")
  expect_match(url, "^https://cloud.r-project.org/")
})

test_that("package_source_url handles NULL cran", {
  skip_if_offline()
  url <- package_source_url("gdalraster", cran = NULL)
  expect_match(url, "^https://cloud.r-project.org/")
})

test_that("package_source_url strips trailing slash", {
  skip_if_offline()
  url1 <- package_source_url("gdalraster", cran = "https://cloud.r-project.org")
  url2 <- package_source_url("gdalraster", cran = "https://cloud.r-project.org/")
  expect_equal(url1, url2)
  expect_false(grepl("//src", url1))
})

test_that("package_source_url errors on non-existent package", {
  skip_if_offline()
  expect_error(package_source_url("notarealpackage12345xyz"), "no package found")
})

# --- package_gdal_uri ---

test_that("package_gdal_uri constructs vsitar//vsicurl URI", {
  skip_if_offline()
  uri <- package_gdal_uri("gdalraster")
  expect_match(uri, "^/vsitar//vsicurl/")
  expect_match(uri, "\\.tar\\.gz$")
})

# --- package_ls ---

test_that("package_ls returns character vector of paths", {
  skip_if_offline()
  skip_on_cran()
  skip_if_not_installed("gdalraster")

  paths <- package_ls("gdalraster")
  expect_type(paths, "character")
  expect_true(length(paths) > 0)
  # Should contain typical package structure
  expect_true(any(grepl("DESCRIPTION$", paths)))
  expect_true(any(grepl("/R/", paths)))
})

# --- scan_package ---

test_that("scan_package returns tibble with correct columns", {
  skip_if_offline()
  skip_on_cran()
  skip_if_not_installed("gdalraster")

  result <- scan_package("gdalraster")
  expect_s3_class(result, "tbl_df")
  expect_named(result, c("package", "driver", "dsn"))
})

test_that("scan_package package column matches input", {
  skip_if_offline()
  skip_on_cran()
  skip_if_not_installed("gdalraster")

  result <- scan_package("gdalraster")
  expect_true(all(result$package == "gdalraster"))
})

test_that("scan_package dsn starts with vsitar", {
  skip_if_offline()
  skip_on_cran()
  skip_if_not_installed("gdalraster")

  result <- scan_package("gdalraster")
  expect_true(all(grepl("^/vsitar//vsicurl/", result$dsn)))
})

test_that("scan_package driver is non-empty character", {
  skip_if_offline()
  skip_on_cran()
  skip_if_not_installed("gdalraster")

  result <- scan_package("gdalraster")
  expect_type(result$driver, "character")
  expect_true(all(nchar(result$driver) > 0))
})

test_that("scan_package errors on non-existent package", {
  skip_if_offline()
  expect_error(scan_package("notarealpackage12345xyz"))
})

test_that("scan_package requires length-1 character", {
  expect_error(scan_package(c("sf", "terra")))
  expect_error(scan_package(123))
})

test_that("scan_package finds expected formats in spData", {
  skip_if_offline()
  skip_on_cran()
  skip_if_not_installed("gdalraster")

  result <- scan_package("spData")
  drivers <- unique(result$driver)
  # spData has GeoPackages and GeoTIFFs at minimum
  expect_true("GPKG" %in% drivers)
  expect_true("GTiff" %in% drivers)
})

# --- Integration: dsn actually works ---

test_that("scan_package dsn can be read by GDAL", {
  skip_if_offline()
  skip_on_cran()
  skip_if_not_installed("gdalraster")

  result <- scan_package("spData")
  gpkg_row <- result[result$driver == "GPKG", ][1, ]

  # Should be able to identify the driver from the dsn
  driver <- gdalraster::identifyDriver(gpkg_row$dsn)
  expect_equal(driver, "GPKG")
})

# --- cran_db_refresh ---

test_that("cran_db_refresh returns logical", {
  skip_if_offline()
  # First call populates cache, refresh should return TRUE
  cran_package_db()
  result <- cran_db_refresh()
  expect_type(result, "logical")
})
