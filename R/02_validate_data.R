library(dplyr)
library(glue)

source("R/00_config.R")

#' Validate all inputs
#'
#' @param inputs List with hochrechnung, rabatt, betriebskosten, sap
#'
#' @return List with success (TRUE/FALSE) and errors vector
#'
validate_all_inputs <- function(inputs) {
  errors <- c()
  
  # Check if all 4 files present
  if (is.null(inputs$hochrechnung)) errors <- c(errors, "Hochrechnung fehlt")
  if (is.null(inputs$rabatt)) errors <- c(errors, "Rabatt fehlt")
  if (is.null(inputs$betriebskosten)) errors <- c(errors, "Betriebskosten fehlt")
  if (is.null(inputs$sap)) errors <- c(errors, "SAP fehlt")
  
  if (length(errors) > 0) {
    return(list(success = FALSE, errors = errors))
  }
  
  # Validate each file
  errors <- c(errors, validate_file(inputs$hochrechnung, "hochrechnung"))
  errors <- c(errors, validate_file(inputs$rabatt, "rabatt"))
  errors <- c(errors, validate_file(inputs$betriebskosten, "betriebskosten"))
  errors <- c(errors, validate_file(inputs$sap, "sap"))
  
  # Check business rules
  errors <- c(errors, validate_business_rules(inputs))
  
  list(success = length(errors) == 0, errors = errors)
}

#' Validate single file structure
#'
validate_file <- function(data, file_key) {
  errors <- c()
  
  if (nrow(data) == 0) {
    return(c(errors, glue("{file_key}: Datei ist leer")))
  }
  
  # Get expected columns from config
  expected_cols <- INPUT_FILES[[file_key]]$columns
  
  # Check required columns exist
  missing_cols <- setdiff(expected_cols, names(data))
  if (length(missing_cols) > 0) {
    errors <- c(errors, glue("{file_key}: Fehlende Spalten: {paste(missing_cols, collapse=', ')}"))
  }
  
  errors
}

#' Validate business rules (3 einfache Regeln)
#'
validate_business_rules <- function(inputs) {
  errors <- c()
  
  # REGEL 1: Kein NA-Wert darf vorkommen
  for (file_key in names(inputs)) {
    if (any(is.na(inputs[[file_key]]))) {
      errors <- c(errors, glue("{file_key}: NA-Werte gefunden"))
    }
  }
  
  # REGEL 1b: Keine 0-Werte dürfen vorkommen
  for (file_key in names(inputs)) {
    if (any(inputs[[file_key]] == 0, na.rm = TRUE)) {
      errors <- c(errors, glue("{file_key}: 0-Werte gefunden"))
    }
  }
  
  # REGEL 2: Alle 5 Produkte vorhanden
  products <- unique(inputs$hochrechnung$product_id)
  missing <- setdiff(VALID_PRODUCTS, products)
  if (length(missing) > 0) {
    errors <- c(errors, glue("Fehlende Produkte: {paste(missing, collapse=', ')}"))
  }
  
  # REGEL 3: Bestand <= 250000
  if (any(inputs$hochrechnung$bestand > 250000)) {
    errors <- c(errors, "Hochrechnung: bestand > 250000")
  }
  
  list(success = length(errors) == 0, errors = errors)
}
