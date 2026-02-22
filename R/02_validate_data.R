library(pointblank)
library(dplyr)
library(glue)

# ============================================================================
# VALIDIERUNG MIT POINTBLANK + MANUELLE BUSINESS RULES
# ============================================================================

#' Validate all inputs using pointblank
#'
#' @param inputs List of data frames (hochrechnung, rabatt, betriebskosten, sap)
#'
#' @return List with validation results and agents
#'
validate_all_inputs <- function(inputs) {
  
  cat("\n[VALIDATE] Starte Validierung mit pointblank...\n")
  
  results <- list(
    success = TRUE,
    errors = NULL,
    warnings = NULL,
    agents = list()
  )
  
  error_list <- c()
  
  # ========== HOCHRECHNUNG VALIDIERUNG ==========
  cat("[VALIDATE] Validiere Hochrechnung...\n")
  
  # 1. Prüfe negative Werte MANUELL
  if (any(inputs$hochrechnung$bestand < 0, na.rm = TRUE)) {
    neg_rows <- which(inputs$hochrechnung$bestand < 0)
    error_list <- c(error_list, 
                   glue::glue("Hochrechnung: Negative Bestandswerte in Zeilen {paste(neg_rows, collapse=', ')}"))
    cat("[VALIDATE] ❌ Negative Bestandswerte gefunden!\n")
  }
  
  if (any(inputs$hochrechnung$bvp < 0, na.rm = TRUE)) {
    neg_rows <- which(inputs$hochrechnung$bvp < 0)
    error_list <- c(error_list, 
                   glue::glue("Hochrechnung: Negative BVP-Werte in Zeilen {paste(neg_rows, collapse=', ')}"))
    cat("[VALIDATE] ❌ Negative BVP-Werte gefunden!\n")
  }
  
  # 2. Pointblank für Standard-Prüfungen
  agent_hochrechnung <- pointblank::create_agent(
    tbl = inputs$hochrechnung
  ) |>
    pointblank::col_exists(columns = c("product_id", "bestand", "bvp", "nvl")) |>
    pointblank::col_is_numeric(columns = c("bestand", "bvp", "nvl")) |>
    pointblank::interrogate()
  
  results$agents$hochrechnung <- agent_hochrechnung
  
  # ========== RABATT VALIDIERUNG ==========
  cat("[VALIDATE] Validiere Rabatt...\n")
  
  # 1. Prüfe Rabatt > 100% MANUELL
  if (any(inputs$rabatt$fam_rab > 100, na.rm = TRUE)) {
    bad_rows <- which(inputs$rabatt$fam_rab > 100)
    error_list <- c(error_list, 
                   glue::glue("Rabatt: fam_rab > 100% in Zeilen {paste(bad_rows, collapse=', ')}"))
    cat("[VALIDATE] ❌ Familienrabatt > 100% gefunden!\n")
  }
  
  if (any(inputs$rabatt$mj_rab > 100, na.rm = TRUE)) {
    bad_rows <- which(inputs$rabatt$mj_rab > 100)
    error_list <- c(error_list, 
                   glue::glue("Rabatt: mj_rab > 100% in Zeilen {paste(bad_rows, collapse=', ')}"))
    cat("[VALIDATE] ❌ Mehrjährig-Rabatt > 100% gefunden!\n")
  }
  
  # 2. Pointblank für Standard-Prüfungen
  agent_rabatt <- pointblank::create_agent(
    tbl = inputs$rabatt
  ) |>
    pointblank::col_exists(columns = c("product_id", "fam_rab", "mj_rab")) |>
    pointblank::col_is_numeric(columns = c("fam_rab", "mj_rab")) |>
    pointblank::interrogate()
  
  results$agents$rabatt <- agent_rabatt
  
  # ========== BETRIEBSKOSTEN VALIDIERUNG ==========
  cat("[VALIDATE] Validiere Betriebskosten...\n")
  
  agent_betriebskosten <- pointblank::create_agent(
    tbl = inputs$betriebskosten
  ) |>
    pointblank::col_exists(columns = c("product_id", "bk", "sm")) |>
    pointblank::col_is_numeric(columns = c("bk", "sm")) |>
    pointblank::interrogate()
  
  results$agents$betriebskosten <- agent_betriebskosten
  
  # ========== SAP VALIDIERUNG ==========
  cat("[VALIDATE] Validiere SAP...\n")
  
  agent_sap <- pointblank::create_agent(
    tbl = inputs$sap
  ) |>
    pointblank::col_exists(columns = c("product_id", "sap", "advo", "pd")) |>
    pointblank::col_is_numeric(columns = c("sap", "advo", "pd")) |>
    pointblank::interrogate()
  
  results$agents$sap <- agent_sap
  
  # ========== AUSWERTUNG ==========
  if (length(error_list) > 0) {
    results$success <- FALSE
    results$errors <- error_list
    cat(glue::glue("[VALIDATE] ❌ {length(error_list)} Validierungsfehler gefunden\n"))
  } else {
    results$success <- TRUE
    cat("[VALIDATE] ✅ Alle Validierungen bestanden\n")
  }
  
  cat("[VALIDATE] Validierung abgeschlossen\n\n")
  
  results
}

#' Get pointblank validation report as HTML
#'
#' @param agent Pointblank agent object
#'
#' @return HTML string for report display
#'
get_validation_report_html <- function(agent) {
  
  if (is.null(agent)) {
    return("<div class='alert alert-info'>Keine Validierung durchgeführt</div>")
  }
  
  # Generiere HTML-Report
  tryCatch({
    report_html <- pointblank::get_agent_report(
      agent,
      arrange_by = "eval"
    )
    
    # Konvertiere zu HTML-String
    html_string <- knitr::kable(report_html, format = "html")
    html_string
    
  }, error = function(e) {
    glue::glue("<div class='alert alert-danger'>Fehler beim Report: {e$message}</div>")
  })
}

#' Validate single file with pointblank
#'
#' @param data Data frame to validate
#' @param file_key Key to determine validation rules
#'
#' @return Pointblank agent
#'
validate_file <- function(data, file_key) {
  
  agent <- pointblank::create_agent(
    tbl = data
  )
  
  # Basis-Validierungen für alle Dateien
  agent <- agent |>
    pointblank::col_exists(columns = "product_id")
  
  # Spezifische Validierungen je nach Dateityp
  if (grepl("Hochrechnung", file_key)) {
    agent <- agent |>
      pointblank::col_is_numeric(columns = c("bestand", "bvp", "nvl")) |>
      pointblank::col_vals_gt(columns = "bestand", value = 0) |>
      pointblank::col_vals_gt(columns = "bvp", value = 0)
  }
  
  if (grepl("Rabatt", file_key)) {
    agent <- agent |>
      pointblank::col_is_numeric(columns = c("fam_rab", "mj_rab")) |>
      pointblank::col_vals_between(columns = "fam_rab", left = 0, right = 100)
  }
  
  agent |> pointblank::interrogate()
}
