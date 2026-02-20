library(readr)
library(dplyr)

# Lade Config
source("R/00_config.R")

# ============================================================================
# CSV-LADEN MIT ERROR-HANDLING
# ============================================================================

#' Load Input Data from CSV
#'
#' @param file_path Path to CSV file
#' @param file_key Key aus INPUT_FILES (z.B. "hochrechnung")
#'
#' @return tibble with data, or error message
#'
load_csv <- function(file_path, file_key) {
  tryCatch({
    # Hole Config für diese Datei
    file_config <- INPUT_FILES[[file_key]]
    expected_cols <- file_config$columns
    
    # Lese CSV
    data <- read_csv(file_path, show_col_types = FALSE)
    
    # Prüfe ob erwartete Spalten vorhanden sind
    missing_cols <- setdiff(expected_cols, names(data))
    if (length(missing_cols) > 0) {
      stop(paste(
        "Fehlende Spalten in", file_config$name, ":",
        paste(missing_cols, collapse = ", ")
      ))
    }
    
    # Prüfe Datentypen (optional - nur warnen, nicht stoppen)
    # Könnte hier erweitert werden für strikte Typ-Checks
    
    return(data)
    
  }, error = function(e) {
    stop(paste(
      "Fehler beim Laden von", basename(file_path), ":\n",
      conditionMessage(e)
    ))
  })
}

#' Load all input files
#'
#' @param hochrechnung_path Path to Input_Hochrechnung.csv
#' @param rabatt_path Path to Input_Rabatt.csv
#' @param betriebskosten_path Path to Input_Betriebskosten.csv
#' @param sap_path Path to Input_SAP.csv
#'
#' @return List with loaded data frames
#'
load_all_inputs <- function(hochrechnung_path,
                            rabatt_path,
                            betriebskosten_path,
                            sap_path) {
  
  list(
    hochrechnung = load_csv(hochrechnung_path, "hochrechnung"),
    rabatt = load_csv(rabatt_path, "rabatt"),
    betriebskosten = load_csv(betriebskosten_path, "betriebskosten"),
    sap = load_csv(sap_path, "sap")
  )
}
