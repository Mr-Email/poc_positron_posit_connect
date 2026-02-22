source("test/_test_helpers.R")

cat("\n")
cat(paste0("🚀 ", strrep("=", 70), "\n"))
cat("🧪 MANUELLE VALIDIERUNGS-TEST\n")
cat(paste0("🚀 ", strrep("=", 70), "\n\n"))

# Lade Validierungsfunktion
source("R/02_validate_data.R")
source("R/01_load_data.R")
source("R/00_config.R")

# ========== LADE DATEN ==========
cat("Lade Input-Dateien...\n")

hochrechnung <- read.csv("data/raw/Input_Hochrechnung_v001.csv")
rabatt <- read.csv("data/raw/Input_Rabatt_v001.csv")
betriebskosten <- read.csv("data/raw/Input_Betriebskosten_v001.csv")
sap <- read.csv("data/raw/Input_SAP_v001.csv")

cat("✅ Dateien geladen\n\n")

# ========== VALIDIERE NORMAL ==========
cat("Test 1: Validiere korrekte Daten\n")

inputs <- list(
  hochrechnung = hochrechnung,
  rabatt = rabatt,
  betriebskosten = betriebskosten,
  sap = sap
)

val_result <- validate_all_inputs(inputs)

if (val_result$success) {
  cat("✅ BESTANDEN - Alle Daten sind valid\n\n")
} else {
  cat("❌ FEHLER:\n")
  for (err in val_result$errors) {
    cat(glue::glue("  - {err}\n"))
  }
  cat("\n")
}

# ========== VALIDIERE MIT NEGATIVEM WERT ==========
cat("Test 2: Validiere mit negativem Bestand\n")

hochrechnung_bad <- hochrechnung
hochrechnung_bad$bestand[1] <- -100

inputs_bad <- list(
  hochrechnung = hochrechnung_bad,
  rabatt = rabatt,
  betriebskosten = betriebskosten,
  sap = sap
)

val_result_bad <- validate_all_inputs(inputs_bad)

if (!val_result_bad$success) {
  cat("✅ FEHLER ERKANNT:\n")
  for (err in val_result_bad$errors) {
    cat(glue::glue("  - {err}\n"))
  }
  cat("\n")
} else {
  cat("❌ FEHLER NICHT ERKANNT\n\n")
}

# ========== VALIDIERE MIT RABATT > 100% ==========
cat("Test 3: Validiere mit Rabatt > 100%\n")

rabatt_bad <- rabatt
rabatt_bad$fam_rab[1] <- 150

inputs_bad <- list(
  hochrechnung = hochrechnung,
  rabatt = rabatt_bad,
  betriebskosten = betriebskosten,
  sap = sap
)

val_result_bad <- validate_all_inputs(inputs_bad)

if (!val_result_bad$success) {
  cat("✅ FEHLER ERKANNT:\n")
  for (err in val_result_bad$errors) {
    cat(glue::glue("  - {err}\n"))
  }
  cat("\n")
} else {
  cat("❌ FEHLER NICHT ERKANNT\n\n")
}

cat(paste0("=" , strrep("=", 70), "\n"))
cat("✅ Manuelles Testen abgeschlossen\n")
cat(paste0("=" , strrep("=", 70), "\n\n"))
