#' Get CRAN package database.
#'
#' This is a memoized (cached) copy of `tools::CRAN_package_db()`, it refreshes once an
#' hour.
#'
#' Force refresh with `cran_db_refresh()`.
#'
#' @seealso cran_db_refresh
#' @export
#' @name cran_package_db
#' @examples
#' \donttest{
#' cran_package_db()
#' }
cran_package_db <- NULL


#' @importFrom digest digest
#' @importFrom memoise memoize
#' @importFrom tools CRAN_package_db
#' @noRd
.onLoad <- function(libname, pkgname) {
  digest::digest("a") ## we have to import digest just for memoise
  cran_package_db <<- memoise::memoize(
    function() {tools::CRAN_package_db()},
    cache = memoise::cache_memory(),
    ~memoise::timeout(3600)
  )
}
