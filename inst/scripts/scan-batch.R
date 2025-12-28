#!/usr/bin/env Rscript
# inst/scripts/scan-batch.R
# Scan a batch of CRAN packages for GDAL-readable files

args <- commandArgs(trailingOnly = TRUE)
batch_size <- if (length(args)) as.integer(args[1]) else 500L

library(vsils)
library(arrow)
library(dplyr)

# Load existing state
scanned <- read_parquet("scranned.parquet")
message(sprintf("Loaded catalog: %d rows, %d packages",
                nrow(scanned), n_distinct(scanned$package)))

# Get current CRAN state
db <- cran_package_db()
current <- tibble::tibble(
  package = db$Package,
  version = db$Version
)
message(sprintf("CRAN has %d packages", nrow(current)))

# Find packages needing scan (new or updated version)
done_key <- paste(scanned$package, scanned$version)
cran_key <- paste(current$package, current$version)
todo <- current[!cran_key %in% done_key, ]

message(sprintf("%d packages to scan", nrow(todo)))

if (nrow(todo) == 0) {
  message("Nothing to do!")
  quit(status = 0)
}

# Take a batch
batch <- head(todo, batch_size)
message(sprintf("Scanning batch of %d packages...", nrow(batch)))

# Scan each package
results <- purrr::map(seq_len(nrow(batch)), function(i) {
  pkg <- batch$package[i]
  ver <- batch$version[i]
  message(sprintf("[%d/%d] %s %s", i, nrow(batch), pkg, ver))

  tryCatch({
    res <- scan_package(pkg)
    if (!is.null(res)) {
      res$version <- ver
      res$scanned_at <- Sys.time()
    }
    res
  }, error = function(e) {
    message("  Error: ", conditionMessage(e))
    # Record that we tried, so we don't retry forever
    tibble::tibble(
      package = pkg,
      driver = NA_character_,
      dsn = NA_character_,
      version = ver,
      scanned_at = Sys.time()
    )
  })
}) |> purrr::list_rbind()

message(sprintf("Scanned %d files from %d packages",
                sum(!is.na(results$driver)), n_distinct(results$package)))

# Combine with existing
combined <- bind_rows(scanned, results) |>
  arrange(package, driver)

# Save
write_parquet(combined, "scranned.parquet")

message(sprintf("Catalog now has %d rows, %d packages",
                nrow(combined), n_distinct(combined$package)))

# Summary
message("\nDriver counts this batch:")
#results |>
#  filter(!is.na(driver)) |>
#  count(driver, sort = TRUE) |>
#  print(n = 20)
