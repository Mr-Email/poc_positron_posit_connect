# Generiere Dummy-Daten für Budget & Hochrechnung PoC
# Rückwärts-Berechnung: CR & SQ Ziele → Input-Parameter
# 2 Versionen (v1, v2) für Caching-Demo in targets

library(dplyr)
library(readr)

# Produkte
products <- c("Amb_T", "Amb_S", "Amb_C", "Hosp_P", "Hosp_HP")
set.seed(42)

# ============================================================================
# FORMELWERK (für Verständnis)
# ============================================================================
# nvp = bvp - (fam_rab + mj_rab)           # Netto-Versicherungsprämie
# SQ = nvl / nvp                            # Schadenquote (Ziel: 60-80%)
# vp = nvp - advo - pd                      # Verdiente Prämie
# va = nvl + sap + sm                       # Versicherungs-Aufwand
# CR = (va + bk) / vp                       # Combined Ratio (Ziel: 85-105%)

# ============================================================================
# VERSION 1: Rückwärts-Generierung für sinnvolle KPIs
# ============================================================================

base_params <- tibble(
  product_id = products,
  bestand = c(250000, 180000, 120000, 95000, 150000),
  bvp_target = c(200, 180, 220, 280, 240),
  sq_target = c(0.70, 0.68, 0.72, 0.65, 0.75),
  cr_target = c(0.92, 0.95, 0.90, 0.88, 0.98)
)

# Rabatte (prozentual)
rabatt_v1 <- tibble(
  product_id = products,
  fam_rab = c(7, 5, 8, 6, 9),    # 5-10%
  mj_rab = c(2, 3, 1, 4, 2)      # 1-5%
)

# Berechne nvp aus bvp und Rabatten
hochrechnung_v1 <- base_params |>
  left_join(rabatt_v1, by = "product_id") |>
  mutate(
    nvp = bvp_target - (fam_rab + mj_rab),
    nvl = sq_target * nvp,
    bvp = bvp_target
  ) |>
  select(product_id, bestand, bvp, nvl)

# Betriebskosten
betriebskosten_v1 <- base_params |>
  left_join(rabatt_v1, by = "product_id") |>
  left_join(
    hochrechnung_v1 |> select(product_id, nvl, bvp),
    by = "product_id"
  ) |>
  mutate(
    nvp = bvp - (fam_rab + mj_rab),
    sm = c(0.95, 1.05, 0.90, 1.15, 0.85),
    advo = c(2500, 1800, 1200, 950, 1500),
    pd = c(45, 30, 60, 85, 50),
    sap = c(250000, 180000, 150000, 350000, 280000),
    vp = nvp - advo - pd,
    va = nvl + sap + sm,
    bk = cr_target * vp - va
  ) |>
  select(product_id, sm, bk) |>
  mutate(bk = pmax(bk, 10))

# SAP-Daten
sap_v1 <- tibble(
  product_id = products,
  advo = c(2500, 1800, 1200, 950, 1500),
  pd = c(45, 30, 60, 85, 50),
  sap = c(250000, 180000, 150000, 350000, 280000)
)

# ============================================================================
# VERSION 2: REALE ÄNDERUNGEN (nicht nur Bestand!)
# ============================================================================

# Input_Hochrechnung_v2: Bestand +5%, BVP angepasst (Inflation)
hochrechnung_v2 <- hochrechnung_v1 |>
  mutate(
    bestand = bestand * 1.05,      # +5% Bestandswachstum
    bvp = bvp * 1.03                # +3% Preis-Anpassung (Inflation)
  )

# Input_Rabatt_v2: Leicht andere Rabatt-Struktur
rabatt_v2 <- tibble(
  product_id = products,
  fam_rab = c(8, 5, 9, 6, 10),     # Unterschiedlich von v1!
  mj_rab = c(2, 4, 1, 3, 2)        # Unterschiedlich von v1!
)

# Input_Betriebskosten_v2: Saisonalität & Kostenänderung
betriebskosten_v2 <- tibble(
  product_id = products,
  sm = c(0.92, 1.08, 0.88, 1.18, 0.82),  # Unterschiedlich (Saisonalität)
  bk = c(48, 38, 52, 78, 62)               # +5-10% Kosten-Inflation
)

# Input_SAP_v2: Advocacy & PD angepasst, SAP variiert
sap_v2 <- tibble(
  product_id = products,
  advo = c(2700, 1900, 1300, 1050, 1600),  # Unterschiedlich von v1!
  pd = c(48, 32, 62, 87, 52),              # Unterschiedlich von v1!
  sap = c(265000, 190000, 160000, 370000, 295000)  # Unterschiedlich von v1!
)

# ============================================================================
# SPEICHERE ALLE DATEIEN
# ============================================================================

dir.create("data/raw", recursive = TRUE, showWarnings = FALSE)

# VERSION 1
write_csv(hochrechnung_v1, "data/raw/Input_Hochrechnung_v1.csv")
write_csv(rabatt_v1, "data/raw/Input_Rabatt_v1.csv")
write_csv(betriebskosten_v1, "data/raw/Input_Betriebskosten_v1.csv")
write_csv(sap_v1, "data/raw/Input_SAP_v1.csv")

# VERSION 2 - ALLE UNTERSCHIEDLICH
write_csv(hochrechnung_v2, "data/raw/Input_Hochrechnung_v2.csv")
write_csv(rabatt_v2, "data/raw/Input_Rabatt_v2.csv")
write_csv(betriebskosten_v2, "data/raw/Input_Betriebskosten_v2.csv")
write_csv(sap_v2, "data/raw/Input_SAP_v2.csv")

# ============================================================================
# ZUSAMMENFASSUNG & VALIDIERUNG
# ============================================================================

cat("✅ Dummy-Daten generiert!\n\n")
cat("VERSION 1 (v1):\n")
cat("  ✓ Input_Hochrechnung_v1.csv\n")
cat("  ✓ Input_Rabatt_v1.csv\n")
cat("  ✓ Input_Betriebskosten_v1.csv\n")
cat("  ✓ Input_SAP_v1.csv\n\n")

cat("VERSION 2 (v2) - Unterschiedliche Werte:\n")
cat("  ✓ Input_Hochrechnung_v2.csv (GEÄNDERT: +5% Bestand, +3% BVP)\n")
cat("  ✓ Input_Rabatt_v2.csv (GEÄNDERT: andere Rabatt-Struktur)\n")
cat("  ✓ Input_Betriebskosten_v2.csv (GEÄNDERT: neue Saisonalität & Kosten)\n")
cat("  ✓ Input_SAP_v2.csv (GEÄNDERT: neue Advocacy, PD, SAP-Werte)\n\n")

# Preview & Vergleich
cat("Preview Input_Hochrechnung_v1:\n")
print(hochrechnung_v1)

cat("\nPreview Input_Hochrechnung_v2 (UNTERSCHIEDLICH):\n")
print(hochrechnung_v2)

cat("\nPreview Input_Rabatt_v1:\n")
print(rabatt_v1)

cat("\nPreview Input_Rabatt_v2 (UNTERSCHIEDLICH):\n")
print(rabatt_v2)
