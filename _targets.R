# ============================================================================
# TARGETS PIPELINE
# ============================================================================
# Workflow-Orchestrierung für Budget & Hochrechnung PoC
#
# DAG:
#   Input Files (v1) → Validate → Calculate → Output (CSV + Report Data)
#
# Verwendung:
#   targets::tar_make()      # Führe Pipeline aus
#   targets::tar_visnetwork() # Zeige DAG Visualisierung
# ============================================================================

library(targets)
library(tarchetypes)

# Lade Config & Funktionen
source("R/00_config.R")
source("R/01_load_data.R")
source("R/02_validate_data.R")
source("R/03_calculate.R")

# ============================================================================
# PIPELINE KONFIGURATION
# ============================================================================

tar_option_set(
  packages = c("dplyr", "readr"),
  format = "rds"  # Caching Format
)

# ============================================================================
# TARGETS
# ============================================================================

list(
  
  # ========================================================================
  # 1. LOAD INPUT FILES (v1)
  # ========================================================================
  
  tar_file(
    name = file_hochrechnung,
    path = "data/raw/Input_Hochrechnung_v1.csv",
    deployment = "main"
  ),
  
  tar_file(
    name = file_rabatt,
    path = "data/raw/Input_Rabatt_v1.csv",
    deployment = "main"
  ),
  
  tar_file(
    name = file_betriebskosten,
    path = "data/raw/Input_Betriebskosten_v1.csv",
    deployment = "main"
  ),
  
  tar_file(
    name = file_sap,
    path = "data/raw/Input_SAP_v1.csv",
    deployment = "main"
  ),
  
  # ========================================================================
  # 2. LOAD & PARSE DATA
  # ========================================================================
  
  tar_target(
    name = load_hochrechnung,
    command = load_csv(file_hochrechnung, "hochrechnung"),
    deployment = "main"
  ),
  
  tar_target(
    name = load_rabatt,
    command = load_csv(file_rabatt, "rabatt"),
    deployment = "main"
  ),
  
  tar_target(
    name = load_betriebskosten,
    command = load_csv(file_betriebskosten, "betriebskosten"),
    deployment = "main"
  ),
  
  tar_target(
    name = load_sap,
    command = load_csv(file_sap, "sap"),
    deployment = "main"
  ),
  
  # ========================================================================
  # 3. COMBINE INPUTS
  # ========================================================================
  
  tar_target(
    name = combined_inputs,
    command = list(
      hochrechnung = load_hochrechnung,
      rabatt = load_rabatt,
      betriebskosten = load_betriebskosten,
      sap = load_sap
    ),
    deployment = "main"
  ),
  
  # ========================================================================
  # 4. VALIDATE DATA
  # ========================================================================
  
  tar_target(
    name = validation_check,
    command = {
      result <- validate_all_inputs(combined_inputs)
      
      if (!result$is_valid_all) {
        stop("Validierung fehlgeschlagen. Bitte überprüfen Sie die Input-Daten.")
      }
      
      result
    },
    deployment = "main"
  ),
  
  # ========================================================================
  # 5. CALCULATE BUDGET & KPIs
  # ========================================================================
  
  tar_target(
    name = calculation_result,
    command = calculate_budget(combined_inputs),
    deployment = "main"
  ),
  
  # ========================================================================
  # 6. PREPARE SUMMARY
  # ========================================================================
  
  tar_target(
    name = summary_table,
    command = prepare_summary(calculation_result),
    deployment = "main"
  ),
  
  # ========================================================================
  # 7. SAVE OUTPUT
  # ========================================================================
  
  tar_file(
    name = output_csv,
    command = {
      dir.create(OUTPUT_DIR, showWarnings = FALSE)
      output_path <- file.path(OUTPUT_DIR, 
                              paste0("budget_result_", Sys.Date(), ".csv"))
      readr::write_csv(summary_table, output_path)
      output_path
    },
    deployment = "main"
  ),
  
  # ========================================================================
  # 8. PREPARE REPORT DATA
  # ========================================================================
  
  tar_target(
    name = report_data,
    command = {
      list(
        summary = summary_table,
        validation = validation_check,
        timestamp = Sys.time()
      )
    },
    deployment = "main"
  )
)
