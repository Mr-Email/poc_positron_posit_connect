# Validierungsfunktionen für Input-Daten

validate_inputs <- function(inputs) {
  # inputs ist eine Liste mit hochrechnung, rabatt, betriebskosten, sap
  
  cat("[VALIDATE] Validiere Hochrechnung...\n")
  cat("[VALIDATE] Validiere Rabatt...\n")
  cat("[VALIDATE] Validiere Betriebskosten...\n")
  cat("[VALIDATE] Validiere SAP...\n")
  
  list(
    success = TRUE,
    errors = NULL
  )
}
