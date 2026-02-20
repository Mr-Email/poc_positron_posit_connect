library(readr)
library(glue)

#' Load single CSV file
#'
#' @param file_path Path to CSV
#' @return tibble
#'
load_csv <- function(file_path) {
  if (!file.exists(file_path)) {
    stop(glue("Datei nicht gefunden: {file_path}"))
  }
  
  read_csv(file_path, show_col_types = FALSE)
}

#' Load all input files
#'
#' @param hochrechnung_path Path to hochrechnung CSV
#' @param rabatt_path Path to rabatt CSV
#' @param betriebskosten_path Path to betriebskosten CSV
#' @param sap_path Path to sap CSV
#'
#' @return List with 4 data frames
#'
load_all_inputs <- function(hochrechnung_path, rabatt_path, betriebskosten_path, sap_path) {
  list(
    hochrechnung = load_csv(hochrechnung_path),
    rabatt = load_csv(rabatt_path),
    betriebskosten = load_csv(betriebskosten_path),
    sap = load_csv(sap_path)
  )
}
