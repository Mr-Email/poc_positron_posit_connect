library(dplyr)
library(readr)

# ============================================================================
# PIPELINE: Load → Validate → Calculate → Output
# ============================================================================

cat("🔄 Pipeline gestartet...\n\n")

# 1. LOAD
source("R/01_load_data.R")
source("R/02_validate_data.R")
source("R/03_calculate.R")

latest_version <- function(pattern) {
  files <- list.files("data/raw", pattern = pattern)
  if (length(files) == 0) stop("Keine Dateien gefunden")
  v <- as.numeric(gsub(".*v(\\d{3})\\.csv", "\\1", files))
  sprintf("%03d", max(v))
}

v_hoch <- latest_version("^Input_Hochrechnung_v\\d{3}\\.csv$")
v_raba <- latest_version("^Input_Rabatt_v\\d{3}\\.csv$")
v_betr <- latest_version("^Input_Betriebskosten_v\\d{3}\\.csv$")
v_sap <- latest_version("^Input_SAP_v\\d{3}\\.csv$")

cat(glue::glue("📂 Lade Inputs: v{v_hoch}, v{v_raba}, v{v_betr}, v{v_sap}\n"))

# 2. LOAD DATA
inputs <- list(
  hochrechnung = load_csv(
    glue::glue("data/raw/Input_Hochrechnung_v{v_hoch}.csv"), 
    "hochrechnung"
  ),
  rabatt = load_csv(
    glue::glue("data/raw/Input_Rabatt_v{v_raba}.csv"), 
    "rabatt"
  ),
  betriebskosten = load_csv(
    glue::glue("data/raw/Input_Betriebskosten_v{v_betr}.csv"), 
    "betriebskosten"
  ),
  sap = load_csv(
    glue::glue("data/raw/Input_SAP_v{v_sap}.csv"), 
    "sap"
  )
)

# 3. VALIDATE
cat("✅ Validiere Daten...\n")
validation <- validate_all_inputs(inputs)
if (!validation$is_valid_all) {
  stop("❌ Validierung fehlgeschlagen!")
}

# 4. CALCULATE
cat("🧮 Berechne KPIs...\n")
result <- calculate_budget(inputs)
summary <- prepare_summary(result)

# 5. OUTPUT
dir.create("output", showWarnings = FALSE)

# Finde nächste Output-Nummer
existing_csvs <- list.files("output", pattern = "^budget_result_\\d{3}\\.csv$")
output_num <- if (length(existing_csvs) == 0) {
  1
} else {
  max(as.numeric(gsub("budget_result_(\\d{3})\\.csv", "\\1", existing_csvs))) + 1
}
output_num_str <- sprintf("%03d", output_num)

output_path <- glue::glue("output/budget_result_{output_num_str}.csv")
write_csv(summary, output_path)

cat(glue::glue("\n✅ Pipeline erfolgreich!\n"))
cat(glue::glue("📊 Output: {output_path}\n"))
print(summary)

cat("\n")
cat("╔════════════════════════════════════════════════════════════════╗\n")
cat("║           BUDGET & HOCHRECHNUNG PIPELINE                       ║\n")
cat("╚════════════════════════════════════════════════════════════════╝\n")
cat("\n")

cat("📂 INPUT FILES (neueste Versionen)\n")
cat("   ├─ Input_Hochrechnung_v", v_hoch, ".csv\n")
cat("   ├─ Input_Rabatt_v", v_raba, ".csv\n")
cat("   ├─ Input_Betriebskosten_v", v_betr, ".csv\n")
cat("   └─ Input_SAP_v", v_sap, ".csv\n")
cat("\n")

cat("▼\n")
cat("📖 LOAD (load_csv)\n")
cat("   ├─ CSV-Dateien laden\n")
cat("   └─ Spalten validieren\n")
cat("\n")

cat("▼\n")
cat("✅ VALIDATE (validate_all_inputs)\n")
cat("   ├─ Data Quality Checks\n")
cat("   └─ Business Rules (pointblanc)\n")
if (!validation$is_valid_all) {
  cat("   ❌ FEHLER - Pipeline abgebrochen\n")
  stop("Validierung fehlgeschlagen!")
}
cat("   ✓ Alle Checks bestanden\n")
cat("\n")

cat("▼\n")
cat("🧮 CALCULATE (calculate_budget)\n")
cat("   ├─ nvp = bvp - (fam_rab + mj_rab)\n")
cat("   ├─ SQ = nvl / nvp\n")
cat("   ├─ vp = nvp - advo - pd\n")
cat("   ├─ va = nvl + sap + sm\n")
cat("   └─ CR = (va + bk) / vp\n")
cat("\n")

cat("▼\n")
cat("📊 PREPARE SUMMARY (prepare_summary)\n")
cat("   ├─ Spalten selektieren\n")
cat("   └─ Nach product_id sortieren\n")
cat("\n")

cat("▼\n")
cat("💾 OUTPUT\n")
cat("   └─ ", output_path, "\n")
cat("\n")
cat("╔════════════════════════════════════════════════════════════════╗\n")
cat("║ ✅ PIPELINE ERFOLGREICH ABGESCHLOSSEN                         ║\n")
cat("╚════════════════════════════════════════════════════════════════╝\n")
