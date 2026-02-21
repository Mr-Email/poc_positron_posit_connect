# ============================================================================
# TARGETS PIPELINE - Elegant mit versionierten Dateien
# ============================================================================

# Unterdrücke renv "out-of-sync" Warnung (optional)
Sys.setenv(RENV_VERBOSE = "false")

library(targets)
library(readr)
library(glue)
library(stringr)
library()

# Load configuration and functions
source("R/00_config.R")
source("R/01_load_data.R")
source("R/02_validate_data.R")
source("R/03_calculate.R")

# ============================================================================
# targets Configuration
# ============================================================================
targets::tar_config_set(
  store = "_targets",
  script = "_targets.R"
)

# ============================================================================
# Helper: Get latest input file version
# ============================================================================
get_latest_input_path <- function(input_name) {
  pattern <- glue::glue("^{input_name}_v\\d+\\.csv$")
  files <- list.files("data/raw", pattern = pattern, full.names = TRUE)
  
  if (length(files) == 0) {
    stop(glue::glue("Keine {input_name} Dateien in data/raw/ gefunden"))
  }
  
  # Extract version numbers and return file with highest version
  versions <- str_extract(basename(files), "\\d+") |> as.numeric()
  files[which.max(versions)]
}

# ============================================================================
# Pipeline Definition
# ============================================================================
list(
  
  # -------------------------------------------------------------------------
  # STAGE 1: File Path Resolution
  # Tracks which input files exist and triggers updates on file changes
  # -------------------------------------------------------------------------
  
  tar_target(
    hochrechnung_path,
    get_latest_input_path("Input_Hochrechnung"),
    format = "file"
  ),
  
  tar_target(
    rabatt_path,
    get_latest_input_path("Input_Rabatt"),
    format = "file"
  ),
  
  tar_target(
    betriebskosten_path,
    get_latest_input_path("Input_Betriebskosten"),
    format = "file"
  ),
  
  tar_target(
    sap_path,
    get_latest_input_path("Input_SAP"),
    format = "file"
  ),
  
  # -------------------------------------------------------------------------
  # STAGE 2: Data Loading
  # Only re-loads when corresponding *_path target changes
  # -------------------------------------------------------------------------
  
  tar_target(
    hochrechnung,
    load_csv(hochrechnung_path)
  ),
  
  tar_target(
    rabatt,
    load_csv(rabatt_path)
  ),
  
  tar_target(
    betriebskosten,
    load_csv(betriebskosten_path)
  ),
  
  tar_target(
    sap,
    load_csv(sap_path)
  ),
  
  # -------------------------------------------------------------------------
  # STAGE 3: Input Combination
  # -------------------------------------------------------------------------
  
  tar_target(
    inputs_combined,
    list(
      hochrechnung = hochrechnung,
      rabatt = rabatt,
      betriebskosten = betriebskosten,
      sap = sap
    )
  ),
  
  # -------------------------------------------------------------------------
  # STAGE 4: Validation
  # Logs warnings but continues pipeline (failure = warnings only)
  # -------------------------------------------------------------------------
  
  tar_target(
    validation_result,
    validate_all_inputs(inputs_combined)
  ),
  
  tar_target(
    validated_inputs,
    {
      # Log warnings if any
      if (!is.null(validation_result$warnings) && length(validation_result$warnings) > 0) {
        for (warning_msg in validation_result$warnings) {
          warning(warning_msg)
        }
      }
      # Pipeline läuft weiter (success = TRUE)
      inputs_combined
    }
  ),
  
  # -------------------------------------------------------------------------
  # STAGE 5: Calculation
  # Computes all metrics based on validated inputs
  # -------------------------------------------------------------------------
  
  tar_target(
    berechnung,
    calculate_budget(validated_inputs)
  ),
  
  # -------------------------------------------------------------------------
  # STAGE 6: Output Export
  # Saves combined data with calculations to CSV
  # -------------------------------------------------------------------------
  
  tar_target(
    output_file,
    {
      timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
      file_path <- glue::glue("output/berechnung_{timestamp}.csv")
      dir.create("output", showWarnings = FALSE)
      
      write_csv(berechnung, file_path)
      file_path
    },
    format = "file"
  )
)
