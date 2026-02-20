# Generiere Dummy-Daten für Budget & Hochrechnung PoC
# 2 Versionen (v1, v2) für Caching-Demo in targets

library(dplyr)
library(readr)

# Produkt-Liste
products <- c("Amb_T", "Amb_S", "Amb_C", "Hosp_P", "Hosp_HP")

# Seed für Reproduzierbarkeit
set.seed(42)

# ============================================================================
# VERSION 1: Basis-Daten
# ============================================================================

# Input_Hochrechnung_v1.csv
hochrechnung_v1 <- tibble(
  product_id = products,
  bestand = c(250000, 180000, 120000, 95000, 150000),  # Realistische Werte
  bvp = c(150, 200, 175, 250, 220)  # Betrag pro Versicherte
)

# Input_Rabatt_v1.csv (in Prozent!)
rabatt_v1 <- tibble(
  product_id = products,
  fam_rab = c(7, 5, 8, 6, 9),  # 5-10%
  mj_rab = c(2, 3, 1, 4, 2)    # 1-5%
)

# Input_Betriebskosten_v1.csv
betriebskosten_v1 <- tibble(
  product_id = products,
  sm = c(0.95, 1.05, 0.90, 1.15, 0.85),  # Saison-Multiplikator 0.8-1.2
  bk = c(45, 35, 50, 75, 60)  # Betriebskosten 20-100
)

# Input_SAP_v1.csv (Ist-Daten)
sap_v1 <- tibble(
  product_id = products,
  advo = c(2500, 1800, 1200, 950, 1500),  # Advocacy (100-5000)
  pd = c(45, 30, 60, 85, 50),  # Pd-Wert (0-100)
  sap = c(250000, 180000, 150000, 350000, 280000)  # SAP-Betrag (10k-500k)
)

# ============================================================================
# VERSION 2: Leicht geändert (für Caching-Demo)
# - Input_Hochrechnung: Bestand angepasst (triggert Neuberechnung)
# - Andere Files: Gleich (targets sollte sie cachen)
# ============================================================================

# Input_Hochrechnung_v2.csv (geändert)
hochrechnung_v2 <- hochrechnung_v1 |>
  mutate(
    bestand = bestand * 1.05  # 5% Steigerung (realistische Änderung)
  )

# Input_Rabatt_v2.csv (GLEICH wie v1 - sollte gecacht werden)
rabatt_v2 <- rabatt_v1

# Input_Betriebskosten_v2.csv (GLEICH wie v1 - sollte gecacht werden)
betriebskosten_v2 <- betriebskosten_v1

# Input_SAP_v2.csv (GLEICH wie v1 - sollte gecacht werden)
sap_v2 <- sap_v1

# ============================================================================
# SPEICHERE ALLE DATEIEN
# ============================================================================

# Erstelle data/raw Ordner falls nicht vorhanden
dir.create("data/raw", recursive = TRUE, showWarnings = FALSE)

# Schreibe v1-Dateien
write_csv(hochrechnung_v1, "data/raw/Input_Hochrechnung_v1.csv")
write_csv(rabatt_v1, "data/raw/Input_Rabatt_v1.csv")
write_csv(betriebskosten_v1, "data/raw/Input_Betriebskosten_v1.csv")
write_csv(sap_v1, "data/raw/Input_SAP_v1.csv")

# Schreibe v2-Dateien
write_csv(hochrechnung_v2, "data/raw/Input_Hochrechnung_v2.csv")
write_csv(rabatt_v2, "data/raw/Input_Rabatt_v2.csv")
write_csv(betriebskosten_v2, "data/raw/Input_Betriebskosten_v2.csv")
write_csv(sap_v2, "data/raw/Input_SAP_v2.csv")

# ============================================================================
# ZUSAMMENFASSUNG
# ============================================================================

cat("\n✅ Dummy-Daten generiert!\n\n")
cat("VERSION 1 (v1):\n")
cat("  ✓ Input_Hochrechnung_v1.csv\n")
cat("  ✓ Input_Rabatt_v1.csv\n")
cat("  ✓ Input_Betriebskosten_v1.csv\n")
cat("  ✓ Input_SAP_v1.csv\n\n")

cat("VERSION 2 (v2) - für Caching-Demo:\n")
cat("  ✓ Input_Hochrechnung_v2.csv (GEÄNDERT: +5% Bestand)\n")
cat("  ✓ Input_Rabatt_v2.csv (GLEICH wie v1 → wird gecacht)\n")
cat("  ✓ Input_Betriebskosten_v2.csv (GLEICH wie v1 → wird gecacht)\n")
cat("  ✓ Input_SAP_v2.csv (GLEICH wie v1 → wird gecacht)\n\n")

cat("📁 Speicherort: data/raw/\n\n")

# Zeige Preview
cat("Preview Input_Hochrechnung_v1:\n")
print(hochrechnung_v1)
