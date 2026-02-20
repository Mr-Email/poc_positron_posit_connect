# ============================================================================
# TARGETS PIPELINE - Elegant mit versionierten Dateien
# ============================================================================

library(targets)
library(dplyr)
library(readr)
library(glue)

# Source helper functions
source("R/03_calculate.R")
source("R/02_validate_data.R")

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

get_latest_input_files <- function() {
  raw_files <- list.files("data/raw", pattern = "\\.csv$", full.names = TRUE)
  
  list(
    hochrechnung = raw_files[grepl("Input_Hochrechnung", raw_files)] |> 
      sort(by = file.info(...)$mtime) |> tail(1),
    rabatt = raw_files[grepl("Input_Rabatt", raw_files)] |> 
      sort(by = file.info(...)$mtime) |> tail(1),
    betriebskosten = raw_files[grepl("Input_Betriebskosten", raw_files)] |> 
      sort(by = file.info(...)$mtime) |> tail(1),
    sap = raw_files[grepl("Input_SAP", raw_files)] |> 
      sort(by = file.info(...)$mtime) |> tail(1)
  )
}

needs_processing <- function(input_files) {
  # Get max timestamp of ALL input files
  max_input_time <- max(
    file.info(input_files$hochrechnung)$mtime,
    file.info(input_files$rabatt)$mtime,
    file.info(input_files$betriebskosten)$mtime,
    file.info(input_files$sap)$mtime
  )
  
  # Get latest report timestamp (if exists)
  latest_report <- list.files("data/processed", pattern = "results.csv", 
                             recursive = TRUE, full.names = TRUE) |>
    sort(decreasing = TRUE) |> head(1)
  
  if (length(latest_report) == 0) {
    return(TRUE)  # No report exists, process
  }
  
  report_time <- file.info(latest_report)$mtime
  max_input_time > report_time  # TRUE if ANY input newer than report
}

# ============================================================================
# PIPELINE
# ============================================================================

list(
  # TARGET 1: Detect latest inputs by timestamp
  tar_target(
    input_files,
    get_latest_input_files()
  ),
  
  # TARGET 2: Check if processing needed (ANY file newer than report)
  tar_target(
    should_process,
    needs_processing(input_files)
  ),
  
  # TARGET 3: Load data (only if should_process = TRUE)
  tar_target(
    data_loaded,
    {
      if (!should_process) return(NULL)
      
      list(
        hochrechnung = read_csv(input_files$hochrechnung, show_col_types = FALSE),
        rabatt = read_csv(input_files$rabatt, show_col_types = FALSE),
        betriebskosten = read_csv(input_files$betriebskosten, show_col_types = FALSE),
        sap = read_csv(input_files$sap, show_col_types = FALSE)
      )
    }
  ),
  
  # TARGET 4: Validate using R/02_validate_data.R
  tar_target(
    validated,
    {
      if (is.null(data_loaded)) return(NULL)
      
      validation <- validate_all_inputs(data_loaded)
      
      if (!validation$success) {
        stop("Validierung fehlgeschlagen:\n", 
             paste(validation$errors, collapse = "\n"))
      }
      
      data_loaded
    }
  ),
  
  # TARGET 5: Calculate
  tar_target(
    results,
    {
      if (is.null(validated)) return(NULL)
      calculate_budget(validated)
    }
  ),
  
  # TARGET 6: Save
  tar_target(
    output,
    {
      if (is.null(results)) return("Skipped (no update needed)")
      
      version <- format(Sys.time(), "%Y%m%d_%H%M%S")
      output_dir <- glue("data/processed/v{version}")
      dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
      
      write_csv(results, glue("{output_dir}/results.csv"))
      write_csv(prepare_summary(results), glue("{output_dir}/summary.csv"))
      
      glue("✅ Results saved to {output_dir}")
    }
  )
)
