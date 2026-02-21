# ============================================================================
# VALIDATE: Datenvalidierung mit Warnings (pointblanc-Ready)
# ============================================================================
# HINWEIS: Diese Funktion ist vorbereitet für zukünftige Integration mit pointblanc
# Aktuell: Warnings bei Validierungsfehlern, Pipeline läuft weiter
# TODO: Mit pointblanc ersetzen für schönere Darstellung und erweiterte Features

library(dplyr)
library(glue)

source("R/00_config.R")

# ============================================================================
# Main Validation Function
# ============================================================================

validate_all_inputs <- function(inputs) {
  # Returns list: list(success = TRUE/FALSE, warnings = c(...), errors = c(...))
  
  warnings <- c()
  errors <- c()
  
  # Validate each input file
  file_errors <- validate_file(inputs$hochrechnung, "hochrechnung")
  errors <- c(errors, file_errors$errors)
  warnings <- c(warnings, file_errors$warnings)
  
  file_errors <- validate_file(inputs$rabatt, "rabatt")
  errors <- c(errors, file_errors$errors)
  warnings <- c(warnings, file_errors$warnings)
  
  file_errors <- validate_file(inputs$betriebskosten, "betriebskosten")
  errors <- c(errors, file_errors$errors)
  warnings <- c(warnings, file_errors$warnings)
  
  file_errors <- validate_file(inputs$sap, "sap")
  errors <- c(errors, file_errors$errors)
  warnings <- c(warnings, file_errors$warnings)
  
  # Validate business rules (nur wenn keine kritischen Fehler)
  if (length(errors) == 0) {
    warnings <- c(warnings, validate_business_rules(inputs))
  }
  
  # Remove NULL/empty warnings
  warnings <- warnings[!is.null(warnings) & warnings != ""]
  
  list(
    success = length(errors) == 0,  # ← Nur TRUE wenn NO ERRORS
    warnings = if (length(warnings) > 0) warnings else NULL,
    errors = if (length(errors) > 0) errors else NULL
  )
}

# ============================================================================
# File-Level Validation (GEÄNDERT: Return list mit errors + warnings)
# ============================================================================

validate_file <- function(data, file_key) {
  warnings <- c()
  errors <- c()
  
  if (!is.data.frame(data)) {
    errors <- c(errors, glue::glue("❌ {file_key}: Ist kein Data Frame"))
    return(list(warnings = warnings, errors = errors))
  }
  
  # Get expected columns from config
  file_config <- INPUT_FILES[[file_key]]
  expected_cols <- file_config$columns
  
  # Check: Pflicht-Spalten vorhanden? (JETZT ERRORS statt WARNINGS!)
  missing_cols <- setdiff(expected_cols, names(data))
  if (length(missing_cols) > 0) {
    errors <- c(errors, glue::glue(
      "❌ {file_key}: Spalten fehlen: {paste(missing_cols, collapse = ', ')}"
    ))
    # STOP HERE - keine weiteren Checks wenn Spalten fehlen!
    return(list(warnings = warnings, errors = errors))
  }
  
  # Check: Keine NAs in Pflicht-Spalten
  for (col in expected_cols) {
    if (col %in% names(data) && any(is.na(data[[col]]))) {
      na_count <- sum(is.na(data[[col]]))
      warnings <- c(warnings, glue::glue(
        "⚠️ {file_key}: {na_count} NA-Werte in Spalte '{col}'"
      ))
    }
  }
  
  # Check: Keine Duplikate bei product_id
  if ("product_id" %in% names(data)) {
    dups <- sum(duplicated(data$product_id))
    if (dups > 0) {
      warnings <- c(warnings, glue::glue(
        "⚠️ {file_key}: {dups} doppelte product_id Einträge"
      ))
    }
  }
  
  # Check: Alle 5 Produkte vorhanden
  if ("product_id" %in% names(data)) {
    missing_products <- setdiff(VALID_PRODUCTS, data$product_id)
    if (length(missing_products) > 0) {
      warnings <- c(warnings, glue::glue(
        "⚠️ {file_key}: Produkte fehlen: {paste(missing_products, collapse = ', ')}"
      ))
    }
  }
  
  list(warnings = warnings, errors = errors)
}

# ============================================================================
# Business Rules Validation (GEÄNDERT: Return vector, nicht list)
# ============================================================================

validate_business_rules <- function(inputs) {
  warnings <- c()
  
  # HOCHRECHNUNG: bestand > 0
  if ("hochrechnung" %in% names(inputs)) {
    hr <- inputs$hochrechnung
    invalid <- which(hr$bestand <= 0)
    if (length(invalid) > 0) {
      warnings <- c(warnings, glue::glue(
        "⚠️ Hochrechnung: {length(invalid)} Zeile(n) mit bestand ≤ 0"
      ))
    }
  }
  
  # HOCHRECHNUNG: bvp > 0
  if ("hochrechnung" %in% names(inputs)) {
    hr <- inputs$hochrechnung
    invalid <- which(hr$bvp <= 0)
    if (length(invalid) > 0) {
      warnings <- c(warnings, glue::glue(
        "⚠️ Hochrechnung: {length(invalid)} Zeile(n) mit bvp ≤ 0"
      ))
    }
  }
  
  # RABATT: fam_rab + mj_rab < 100
  if ("rabatt" %in% names(inputs)) {
    rab <- inputs$rabatt
    rab$total_rab <- rab$fam_rab + rab$mj_rab
    invalid <- which(rab$total_rab >= 100)
    if (length(invalid) > 0) {
      invalid_products <- rab$product_id[invalid]
      warnings <- c(warnings, glue::glue(
        "⚠️ Rabatt: {paste(invalid_products, collapse = ', ')} hat Gesamtrabatt ≥ 100%"
      ))
    }
  }
  
  # BETRIEBSKOSTEN: sm zwischen 0.5 und 1.5
  if ("betriebskosten" %in% names(inputs)) {
    bk <- inputs$betriebskosten
    invalid <- which(bk$sm < 0.5 | bk$sm > 1.5)
    if (length(invalid) > 0) {
      invalid_products <- bk$product_id[invalid]
      warnings <- c(warnings, glue::glue(
        "⚠️ Betriebskosten: {paste(invalid_products, collapse = ', ')} hat sm außerhalb [0.5, 1.5]"
      ))
    }
  }
  
  # BETRIEBSKOSTEN: bk >= 0
  if ("betriebskosten" %in% names(inputs)) {
    bk <- inputs$betriebskosten
    invalid <- which(bk$bk < 0)
    if (length(invalid) > 0) {
      invalid_products <- bk$product_id[invalid]
      warnings <- c(warnings, glue::glue(
        "⚠️ Betriebskosten: {paste(invalid_products, collapse = ', ')} hat negative bk"
      ))
    }
  }
  
  warnings
}

# ============================================================================
# Future Integration: pointblanc
# ============================================================================
# TODO: Diese Funktion mit pointblanc ersetzen für:
# - Elegantere Regel-Definition
# - Strukturierte Validierungsreports
# - Interaktive Fehlervisualisierung
#
# Beispiel (Pseudo-Code):
# pointblanc::add_rule(
#   name = "bestand_positive",
#   description = "Bestand muss > 0 sein",
#   rule_fn = function(x) x$bestand > 0,
#   level = "warning"  # oder "error"
# )
