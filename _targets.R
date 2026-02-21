# ============================================================================
# TARGETS PIPELINE - Elegant mit versionierten Dateien
# ============================================================================

Sys.setenv(RENV_VERBOSE = "false")

library(targets)
library(readr)
library(glue)
library(stringr)
library(tarchetypes)

# Load config & helper functions
source("R/00_config.R")
source("R/01_load_data.R")
source("R/02_validate_data.R")
source("R/03_calculate.R")

# Helper: Get latest input file version
get_latest_input_path <- function(input_name) {
  pattern <- glue::glue("^{input_name}_v\\d+\\.csv$")
  files <- list.files("data/raw", pattern = pattern, full.names = TRUE)
  
  if (length(files) == 0) {
    stop(glue::glue("Keine {input_name} Dateien gefunden"))
  }
  
  # Extract version numbers and return path with highest version
  versions <- stringr::str_extract(basename(files), "\\d+") |> as.numeric()
  files[which.max(versions)]
}

# Helper: Initialize log file
init_logfile <- function() {
  if (!dir.exists("output")) {
    dir.create("output", showWarnings = FALSE)
  }
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  logfile <- glue::glue("output/pipeline_{timestamp}.log")
  logfile
}

# Helper: Get latest output version
get_next_output_version <- function() {
  files <- list.files("output", pattern = "^bu_v\\d+\\.csv$", full.names = FALSE)
  
  if (length(files) == 0) {
    return("001")
  }
  
  versions <- stringr::str_extract(files, "\\d+") |> as.numeric()
  next_version <- max(versions) + 1
  sprintf("%03d", next_version)
}

targets::tar_config_set(
  store = "_targets",
  script = "_targets.R"
)

# ============================================================================
# Define pipeline
# ============================================================================
list(
  # Track all input files (triggers rebuild if ANY file changes)
  tar_files(
    input_files_changed,
    list.files("data/raw", pattern = "^Input_.*\\.csv$", full.names = TRUE)
  ),
  
  # File paths depend on input_files_changed
  tar_target(
    hochrechnung_path,
    {
      input_files_changed  # Force dependency
      get_latest_input_path("Input_Hochrechnung")
    }
  ),
  
  tar_target(
    rabatt_path,
    {
      input_files_changed
      get_latest_input_path("Input_Rabatt")
    }
  ),
  
  tar_target(
    betriebskosten_path,
    {
      input_files_changed
      get_latest_input_path("Input_Betriebskosten")
    }
  ),
  
  tar_target(
    sap_path,
    {
      input_files_changed
      get_latest_input_path("Input_SAP")
    }
  ),
  
  # Load data
  tar_target(hochrechnung, load_csv(hochrechnung_path)),
  tar_target(rabatt, load_csv(rabatt_path)),
  tar_target(betriebskosten, load_csv(betriebskosten_path)),
  tar_target(sap, load_csv(sap_path)),
  
  # Combine
  tar_target(
    inputs_combined,
    list(
      hochrechnung = hochrechnung,
      rabatt = rabatt,
      betriebskosten = betriebskosten,
      sap = sap
    )
  ),
  
  # Validate - mit Logging
  tar_target(
    validation_result,
    {
      result <- validate_all_inputs(inputs_combined)
      
      # Log Validierungsergebnis
      log_msg <- glue::glue("[{format(Sys.time(), '%Y-%m-%d %H:%M:%S')}] VALIDIERUNG")
      
      if (result$success) {
        log_msg <- glue::glue("{log_msg}: ✅ ERFOLGREICH")
        cat("\n✅ VALIDIERUNG ERFOLGREICH\n")
      } else {
        log_msg <- glue::glue("{log_msg}: ⚠️ MIT WARNUNGEN")
        cat("\n⚠️ VALIDIERUNG MIT WARNUNGEN\n")
        if (!is.null(result$warnings) && length(result$warnings) > 0) {
          cat("Warnungen:\n")
          cat(paste("  -", result$warnings, collapse = "\n"))
          cat("\n")
          log_msg <- glue::glue("{log_msg}\nWarnungen:\n{paste('  -', result$warnings, collapse = '\n')}")
        }
      }
      
      # Schreibe in Logfile
      write(log_msg, file = logfile, append = TRUE)
      
      result
    }
  ),
  
  tar_target(
    validated_inputs,
    {
      result <- validation_result
      if (!result$success && !is.null(result$errors) && length(result$errors) > 0) {
        log_msg <- glue::glue(
          "[{format(Sys.time(), '%Y-%m-%d %H:%M:%S')}] ❌ VALIDIERUNG FEHLGESCHLAGEN\n",
          "Fehler:\n{paste('  -', result$errors, collapse = '\n')}"
        )
        write(log_msg, file = logfile, append = TRUE)
        stop(glue::glue(
          "Validierung fehlgeschlagen:\n{paste('  -', result$errors, collapse = '\n')}"
        ))
      }
      inputs_combined
    }
  ),
  
  # Calculate
  tar_target(
    berechnung,
    {
      log_msg <- glue::glue("[{format(Sys.time(), '%Y-%m-%d %H:%M:%S')}] BERECHNUNG: ✅ GESTARTET")
      write(log_msg, file = logfile, append = TRUE)
      calculate_budget(validated_inputs)
    }
  ),
  
  # Output
  tar_target(
    output_file,
    {
      if (!dir.exists("output")) {
        dir.create("output", showWarnings = FALSE)
      }
      
      version <- get_next_output_version()
      filename <- glue::glue("output/bu_v{version}.csv")
      readr::write_csv(berechnung, filename)
      
      # Log Output-Generierung
      log_msg <- glue::glue("[{format(Sys.time(), '%Y-%m-%d %H:%M:%S')}] OUTPUT: ✅ {filename} generiert")
      write(log_msg, file = logfile, append = TRUE)
      
      filename
    }
  ),
  
  # Initialize logfile - MUSS bei jedem Run neu erstellt werden
  tar_target(
    logfile,
    {
      # Force re-evaluation: Hänge Dateiabhängigkeit an
      input_files_changed
      
      if (!dir.exists("output")) {
        dir.create("output", showWarnings = FALSE)
      }
      timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
      logfile_path <- glue::glue("output/pipeline_{timestamp}.log")
      logfile_path
    }
  )
)
