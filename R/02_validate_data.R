library(dplyr)

# Lade Config
source("R/00_config.R")

# ============================================================================
# VALIDIERUNG MIT AUSSAGEKRÄFTIGEN ERROR-MESSAGES
# ============================================================================

#' Validate Single Data Frame
#'
#' Generische Validierungsfunktion die Config nutzt
#'
#' @param data Tibble to validate
#' @param file_key Key aus INPUT_FILES (z.B. "hochrechnung")
#'
#' @return List with:
#'   - is_valid: TRUE/FALSE
#'   - errors: Character vector mit Fehler-Details
#'   - warnings: Character vector mit Warnungen
#'
validate_data <- function(data, file_key) {
  
  file_config <- INPUT_FILES[[file_key]]
  rules_config <- BUSINESS_RULES[[file_key]]
  errors <- c()
  warnings <- c()
  
  # ========================================================================
  # 1. STRUKTUR-CHECKS
  # ========================================================================
  
  # Prüfe ob erwartete Spalten vorhanden sind
  expected_cols <- file_config$columns
  missing_cols <- setdiff(expected_cols, names(data))
  
  if (length(missing_cols) > 0) {
    errors <- c(errors, paste(
      "Fehlende Spalten:", paste(missing_cols, collapse = ", ")
    ))
    return(list(is_valid = FALSE, errors = errors, warnings = warnings))
  }
  
  # Prüfe ob Daten vorhanden sind
  if (nrow(data) == 0) {
    errors <- c(errors, "Datei ist leer (keine Zeilen vorhanden)")
    return(list(is_valid = FALSE, errors = errors, warnings = warnings))
  }
  
  # ========================================================================
  # 2. DATENTYP-CHECKS
  # ========================================================================
  
  expected_types <- file_config$types
  for (col in names(expected_types)) {
    expected_type <- expected_types[[col]]
    actual_type <- typeof(data[[col]])
    
    # Vereinfachte Typ-Prüfung (c = character, d = double/numeric)
    if (expected_type == "c" && !is.character(data[[col]])) {
      errors <- c(errors, paste(
        "Spalte '", col, "' sollte Text sein, ist aber", actual_type
      ))
    }
    if (expected_type == "d" && !is.numeric(data[[col]])) {
      errors <- c(errors, paste(
        "Spalte '", col, "' sollte Zahl sein, ist aber", actual_type
      ))
    }
  }
  
  if (length(errors) > 0) {
    return(list(is_valid = FALSE, errors = errors, warnings = warnings))
  }
  
  # ========================================================================
  # 3. NULL/NA-CHECKS
  # ========================================================================
  
  for (col in expected_cols) {
    na_count <- sum(is.na(data[[col]]))
    if (na_count > 0) {
      errors <- c(errors, paste(
        "Spalte '", col, "' hat", na_count, "fehlende Werte (NA)"
      ))
    }
  }
  
  # ========================================================================
  # 4. PRODUCT_ID CHECKS
  # ========================================================================
  
  # Prüfe gültige Produkte
  invalid_products <- setdiff(unique(data$product_id), VALID_PRODUCTS)
  if (length(invalid_products) > 0) {
    errors <- c(errors, paste(
      "Ungültige Produkt-IDs:", paste(invalid_products, collapse = ", "),
      "\nErlaubte Produkte:", paste(VALID_PRODUCTS, collapse = ", ")
    ))
  }
  
  # Prüfe Duplikate
  duplicates <- data$product_id[duplicated(data$product_id)]
  if (length(duplicates) > 0) {
    errors <- c(errors, paste(
      "Duplikate in product_id:", paste(unique(duplicates), collapse = ", ")
    ))
  }
  
  # Prüfe ob alle 5 Produkte vorhanden sind
  if (length(unique(data$product_id)) != 5) {
    errors <- c(errors, paste(
      "Es müssen alle 5 Produkte vorhanden sein.",
      "Gefunden:", length(unique(data$product_id))
    ))
  }
  
  # ========================================================================
  # 5. BUSINESS RULES (aus Config)
  # ========================================================================
  
  # Spezielle Behandlung pro File-Type
  if (file_key == "hochrechnung") {
    errors <- c(errors, validate_hochrechnung_rules(data))
  }
  
  if (file_key == "rabatt") {
    errors <- c(errors, validate_rabatt_rules(data))
  }
  
  if (file_key == "betriebskosten") {
    errors <- c(errors, validate_betriebskosten_rules(data))
  }
  
  if (file_key == "sap") {
    errors <- c(errors, validate_sap_rules(data))
  }
  
  # ========================================================================
  # RETURN
  # ========================================================================
  
  is_valid <- length(errors) == 0
  
  list(
    is_valid = is_valid,
    errors = if (length(errors) > 0) errors else NULL,
    warnings = if (length(warnings) > 0) warnings else NULL
  )
}

# ============================================================================
# SPEZIFISCHE BUSINESS RULES PRO FILE-TYPE
# ============================================================================

#' Validate Hochrechnung Business Rules
validate_hochrechnung_rules <- function(data) {
  errors <- c()
  
  # bestand > 0
  invalid_bestand <- data |>
    filter(bestand <= 0) |>
    pull(product_id)
  if (length(invalid_bestand) > 0) {
    errors <- c(errors, paste(
      "bestand <= 0 bei:", paste(invalid_bestand, collapse = ", "),
      "| Regel: bestand muss > 0 sein"
    ))
  }
  
  # bvp > 0
  invalid_bvp <- data |>
    filter(bvp <= 0) |>
    pull(product_id)
  if (length(invalid_bvp) > 0) {
    errors <- c(errors, paste(
      "bvp <= 0 bei:", paste(invalid_bvp, collapse = ", "),
      "| Regel: bvp muss > 0 sein"
    ))
  }
  
  # nvl > 0
  invalid_nvl <- data |>
    filter(nvl <= 0) |>
    pull(product_id)
  if (length(invalid_nvl) > 0) {
    errors <- c(errors, paste(
      "nvl <= 0 bei:", paste(invalid_nvl, collapse = ", "),
      "| Regel: nvl muss > 0 sein"
    ))
  }
  
  errors
}

#' Validate Rabatt Business Rules
validate_rabatt_rules <- function(data) {
  errors <- c()
  
  # fam_rab: 0 <= x < 100
  invalid_fam <- data |>
    filter(fam_rab < 0 | fam_rab >= 100) |>
    pull(product_id)
  if (length(invalid_fam) > 0) {
    errors <- c(errors, paste(
      "fam_rab außerhalb 0-100 bei:", paste(invalid_fam, collapse = ", ")
    ))
  }
  
  # mj_rab: 0 <= x < 100
  invalid_mj <- data |>
    filter(mj_rab < 0 | mj_rab >= 100) |>
    pull(product_id)
  if (length(invalid_mj) > 0) {
    errors <- c(errors, paste(
      "mj_rab außerhalb 0-100 bei:", paste(invalid_mj, collapse = ", ")
    ))
  }
  
  # Sum: fam_rab + mj_rab < 100
  invalid_sum <- data |>
    mutate(sum_rab = fam_rab + mj_rab) |>
    filter(sum_rab >= 100) |>
    pull(product_id)
  if (length(invalid_sum) > 0) {
    errors <- c(errors, paste(
      "Summe Rabatten >= 100 bei:", paste(invalid_sum, collapse = ", "),
      "| Regel: fam_rab + mj_rab < 100"
    ))
  }
  
  errors
}

#' Validate Betriebskosten Business Rules
validate_betriebskosten_rules <- function(data) {
  errors <- c()
  
  # sm: 0.5 <= x <= 1.5
  invalid_sm <- data |>
    filter(sm < 0.5 | sm > 1.5) |>
    pull(product_id)
  if (length(invalid_sm) > 0) {
    errors <- c(errors, paste(
      "sm außerhalb 0.5-1.5 bei:", paste(invalid_sm, collapse = ", ")
    ))
  }
  
  # bk >= 0
  invalid_bk <- data |>
    filter(bk < 0) |>
    pull(product_id)
  if (length(invalid_bk) > 0) {
    errors <- c(errors, paste(
      "bk < 0 bei:", paste(invalid_bk, collapse = ", "),
      "| Regel: bk darf nicht negativ sein"
    ))
  }
  
  errors
}

#' Validate SAP Business Rules
validate_sap_rules <- function(data) {
  errors <- c()
  
  # advo >= 0
  invalid_advo <- data |>
    filter(advo < 0) |>
    pull(product_id)
  if (length(invalid_advo) > 0) {
    errors <- c(errors, paste(
      "advo < 0 bei:", paste(invalid_advo, collapse = ", ")
    ))
  }
  
  # pd >= 0
  invalid_pd <- data |>
    filter(pd < 0) |>
    pull(product_id)
  if (length(invalid_pd) > 0) {
    errors <- c(errors, paste(
      "pd < 0 bei:", paste(invalid_pd, collapse = ", ")
    ))
  }
  
  # sap >= 0
  invalid_sap <- data |>
    filter(sap < 0) |>
    pull(product_id)
  if (length(invalid_sap) > 0) {
    errors <- c(errors, paste(
      "sap < 0 bei:", paste(invalid_sap, collapse = ", ")
    ))
  }
  
  errors
}

# ============================================================================
# WRAPPER: VALIDIERE ALLE INPUTS
# ============================================================================

#' Validate All Input Files
#'
#' @param inputs List mit hochrechnung, rabatt, betriebskosten, sap
#'
#' @return List with validation results for each file
#'   - is_valid_all: TRUE/FALSE
#'   - results: Named list mit Ergebnissen pro File
#'
validate_all_inputs <- function(inputs) {
  
  file_keys <- c("hochrechnung", "rabatt", "betriebskosten", "sap")
  results <- list()
  
  for (key in file_keys) {
    results[[key]] <- validate_data(inputs[[key]], key)
  }
  
  # Prüfe ob ALLE valid sind
  is_valid_all <- all(sapply(results, function(x) x$is_valid))
  
  list(
    is_valid_all = is_valid_all,
    results = results
  )
}

#' Format Validation Results for Display
#'
#' @param validation_result Result aus validate_all_inputs()
#'
#' @return Character string mit formatierter Ausgabe
#'
format_validation_output <- function(validation_result) {
  
  output <- c()
  
  for (file_key in names(validation_result$results)) {
    result <- validation_result$results[[file_key]]
    file_name <- INPUT_FILES[[file_key]]$name
    
    if (result$is_valid) {
      output <- c(output, paste("✅", file_name, "- OK"))
    } else {
      output <- c(output, paste("❌", file_name, "- FEHLER:"))
      output <- c(output, paste("   ", result$errors))
    }
    output <- c(output, "")
  }
  
  paste(output, collapse = "\n")
}
