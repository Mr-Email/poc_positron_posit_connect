library(dplyr)

# ============================================================================
# BERECHNUNG: FORMELWERK IMPLEMENTIEREN
# ============================================================================

#' Calculate Budget & KPIs
#'
#' Formelwerk:
#' nvp = bvp - (fam_rab + mj_rab)
#' SQ = nvl / nvp
#' vp = nvp - advo - pd
#' va = nvl + sap + sm
#' CR = (va + bk) / vp
#'
#' @param inputs List of data frames (hochrechnung, rabatt, betriebskosten, sap)
#'
#' @return Tibble with all calculations
#'
calculate_budget <- function(inputs) {
  
  # Starte mit Hochrechnung
  result <- inputs$hochrechnung |>
    
    # Join mit allen anderen Inputs
    left_join(inputs$rabatt, by = "product_id") |>
    left_join(inputs$betriebskosten, by = "product_id") |>
    left_join(inputs$sap, by = "product_id") |>
    
    # Berechne Metriken
    mutate(
      # nvp = bvp - (fam_rab + mj_rab)
      nvp = bvp - (fam_rab + mj_rab),
      
      # SQ = nvl / nvp (Schadenquote)
      sq = nvl / nvp,
      
      # vp = nvp - advo - pd (Verdiente Prämie)
      vp = nvp - advo - pd,
      
      # va = nvl + sap + sm (Versicherungs-Aufwand)
      va = nvl + sap + sm,
      
      # CR = (va + bk) / vp (Combined Ratio)
      cr = (va + bk) / vp,
      
      # Delta zum SAP
      sap_delta = sap - (nvp * bestand),
      
      .keep = "all"
    ) |>
    
    # Runde für Lesbarkeit
    mutate(
      across(where(is.numeric), ~ round(., 2))
    )
  
  result
}

#' Prepare Summary Table
#'
#' Wähle wichtigste Spalten für Report
#'
#' @param calculation_result Tibble from calculate_budget()
#'
#' @return Clean summary tibble
#'
prepare_summary <- function(calculation_result) {
  
  calculation_result |>
    select(
      product_id,
      bestand,
      bvp,
      nvp,
      nvl,
      sq,
      advo,
      pd,
      vp,
      sap,
      sm,
      va,
      bk,
      cr,
      sap_delta
    ) |>
    arrange(product_id)
}
