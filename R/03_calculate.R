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
  # Join alle Inputs auf hochrechnung
  result <- inputs$hochrechnung |>
    left_join(inputs$rabatt, by = "product_id") |>
    left_join(inputs$betriebskosten, by = "product_id") |>
    left_join(inputs$sap, by = "product_id") |>
    mutate(
      # Netto-Versicherungsprämie
      nvp = bvp - (fam_rab + mj_rab),
      
      # Verdiente Prämie
      vp = nvp - advo - pd,
      
      # Versicherungs-Aufwand
      va = nvl + sap + sm,
      
      # Combined Ratio
      cr = (va + bk) / vp,
      
      # Status (Ampel für CR)
      cr_status = case_when(
        cr < 0.85 ~ "Grün (sehr gut)",
        cr <= 1.05 ~ "Gelb (OK)",
        TRUE ~ "Rot (kritisch)"
      ),

      # Schadenquote
      sq = nvl / nvp,

      # Status (Ampel für SQ)
      sq_status = case_when(
        sq < 0.60 ~ "Zu niedrig",
        sq <= 0.80 ~ "OK",
        TRUE ~ "Zu hoch"
      )
    ) |>
    select(product_id, bestand, bvp, fam_rab, mj_rab, nvp, nvl,
           advo, pd, vp, sap, sm, va, bk, sq, sq_status, cr, cr_status)
  
  result
}
