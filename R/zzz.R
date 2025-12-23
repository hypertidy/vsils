cran_package_db <- NULL


#' @importFrom digest digest
#' @importFrom memoise memoize
#' @importFrom tools CRAN_package_db
#' @noRd
.onLoad <- function(libname, pkgname) {
  digest::digest("a") ## we have to import digest just for memoise
  cran_package_db <<- memoise::memoize(
    tools::CRAN_package_db,
    cache = memoise::cache_memory(),
    ~memoise::timeout(3600)
  )
}
