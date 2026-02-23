# ============================================================================
# INITIALISIERE DUMMY-DATEN
# ============================================================================
# Führe dieses Skript AUS, um zum ersten Mal Rohdaten zu generieren!
# Danach kannst du die Pipeline mit tar_make() starten.

cat("\n")
cat(paste0("🚀 ", strrep("=", 70), "\n"))
cat("INITIALISIERE DUMMY-DATEN FÜR ERSTES MAL\n")
cat(paste0("🚀 ", strrep("=", 70), "\n\n"))

# Erstelle Verzeichnis
dir.create("data/raw", recursive = TRUE, showWarnings = FALSE)

# Generiere erste Version (v001)
cat("Generiere erste Input-Dateien (v001)...\n\n")

library(dplyr)
library(readr)
source("R/00_config.R")

# ============================================================================
# Hochrechnung v001
# ============================================================================
set.seed(1)
hochrechnung <- tibble(
  product_id = VALID_PRODUCTS,
  bestand = c(75000, 85000, 95000, 110000, 120000),
  bvp = c(180, 190, 200, 210, 220),
  nvl = c(54, 57, 60, 63, 66)
)
write_csv(hochrechnung, "data/raw/Input_Hochrechnung_v001.csv")
cat("✅ Input_Hochrechnung_v001.csv erstellt\n")

# ============================================================================
# Rabatt v001
# ============================================================================
set.seed(1)
rabatt <- tibble(
  product_id = VALID_PRODUCTS,
  fam_rab = c(7.5, 7.5, 8.0, 8.5, 9.0),
  mj_rab = c(2.5, 2.5, 3.0, 3.0, 3.5)
)
write_csv(rabatt, "data/raw/Input_Rabatt_v001.csv")
cat("✅ Input_Rabatt_v001.csv erstellt\n")

# ============================================================================
# Betriebskosten v001
# ============================================================================
set.seed(1)
betriebskosten <- tibble(
  product_id = VALID_PRODUCTS,
  sm = c(0.8, 0.9, 1.0, 1.1, 1.2),
  bk = c(12, 14, 16, 18, 20)
)
write_csv(betriebskosten, "data/raw/Input_Betriebskosten_v001.csv")
cat("✅ Input_Betriebskosten_v001.csv erstellt\n")

# ============================================================================
# SAP v001
# ============================================================================
set.seed(1)
sap <- tibble(
  product_id = VALID_PRODUCTS,
  advo = c(1.5, 2.0, 2.5, 3.0, 3.5),
  pd = c(1.0, 1.5, 2.0, 2.5, 3.0),
  sap = c(0.5, 1.0, 1.5, 2.0, 2.5)
)
write_csv(sap, "data/raw/Input_SAP_v001.csv")
cat("✅ Input_SAP_v001.csv erstellt\n")

cat("\n")
cat(paste0("✅ ", strrep("=", 70), "\n"))
cat("INITIALISIERUNG ABGESCHLOSSEN\n")
cat("Starte jetzt die Pipeline mit: tar_make()\n")
cat(paste0("✅ ", strrep("=", 70), "\n\n"))
