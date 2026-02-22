# ============================================================================
# TARGETS PIPELINE - Best Practice Struktur
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

# ============================================================================
# HELPERS
# ============================================================================

get_latest_input_path <- function(input_name) {
  pattern <- glue::glue("^{input_name}_v\\d+\\.csv$")
  files <- list.files("data/raw", pattern = pattern, full.names = TRUE)
  if (length(files) == 0) {
    stop(glue::glue("Keine {input_name} Dateien gefunden"))
  }
  versions <- stringr::str_extract(basename(files), "\\d+") |> as.numeric()
  files[which.max(versions)]
}

get_next_output_version <- function() {
  files <- list.files("output", pattern = "^bu_v\\d+\\.csv$", full.names = FALSE)
  if (length(files) == 0) return("001")
  versions <- stringr::str_extract(files, "\\d+") |> as.numeric()
  sprintf("%03d", max(versions) + 1)
}

targets::tar_config_set(store = "_targets", script = "_targets.R")

# ============================================================================
# PIPELINE
# ============================================================================

list(
  # ─────────────────────────────────────────────────────────────────────
  # STAGE 1: INPUT FILES (einfach - nur 1 Target, kein branching)
  # ─────────────────────────────────────────────────────────────────────
  
  tar_target(
    input_hochrechnung_path,
    get_latest_input_path("Input_Hochrechnung"),
    format = "file"
  ),
  
  tar_target(
    input_rabatt_path,
    get_latest_input_path("Input_Rabatt"),
    format = "file"
  ),
  
  tar_target(
    input_betriebskosten_path,
    get_latest_input_path("Input_Betriebskosten"),
    format = "file"
  ),
  
  tar_target(
    input_sap_path,
    get_latest_input_path("Input_SAP"),
    format = "file"
  ),
  
  # ─────────────────────────────────────────────────────────────────────
  # STAGE 2: LOAD DATA
  # ─────────────────────────────────────────────────────────────────────
  
  tar_target(hochrechnung, load_csv(input_hochrechnung_path)),
  tar_target(rabatt, load_csv(input_rabatt_path)),
  tar_target(betriebskosten, load_csv(input_betriebskosten_path)),
  tar_target(sap, load_csv(input_sap_path)),
  
  # ─────────────────────────────────────────────────────────────────────
  # STAGE 2.5: COMBINE LOADED DATA (Junction)
  # ─────────────────────────────────────────────────────────────────────
  
  tar_target(
    inputs_combined,
    list(
      hochrechnung = hochrechnung,
      rabatt = rabatt,
      betriebskosten = betriebskosten,
      sap = sap
    )
  ),
  
  # ─────────────────────────────────────────────────────────────────────
  # STAGE 3: VALIDATE DATA
  # ─────────────────────────────────────────────────────────────────────
  
  tar_target(
    validation_result,
    {
      result <- validate_all_inputs(inputs_combined)
      
      log_msg <- glue::glue("[{format(Sys.time(), '%Y-%m-%d %H:%M:%S')}] VALIDIERUNG")
      if (result$success) {
        log_msg <- glue::glue("{log_msg}: ✅ ERFOLGREICH")
        cat("\n✅ VALIDIERUNG ERFOLGREICH\n")
      } else {
        log_msg <- glue::glue("{log_msg}: ❌ FEHLER")
        cat("\n❌ VALIDIERUNG FEHLGESCHLAGEN\n")
        if (!is.null(result$errors) && length(result$errors) > 0) {
          cat("Fehler:\n")
          cat(paste("  -", result$errors, collapse = "\n"), "\n")
        }
      }
      
      result
    }
  ),
  
  # ─────────────────────────────────────────────────────────────────────
  # STAGE 4: PREPARE DATA (nach erfolgreicher Validierung)
  # ─────────────────────────────────────────────────────────────────────
  
  tar_target(
    validated_inputs,
    {
      if (!validation_result$success) {
        errors <- validation_result$errors %||% "Unbekannter Fehler"
        stop(glue::glue("Validierung fehlgeschlagen:\n{paste(errors, collapse = '\n')}"))
      }
      
      list(
        hochrechnung = hochrechnung,
        rabatt = rabatt,
        betriebskosten = betriebskosten,
        sap = sap
      )
    }
  ),
  
  # ─────────────────────────────────────────────────────────────────────
  # STAGE 5: CALCULATE
  # ─────────────────────────────────────────────────────────────────────
  
  tar_target(
    berechnung,
    {
      cat("\n📊 BERECHNUNG GESTARTET...\n")
      result <- calculate_budget(validated_inputs)
      cat("✅ BERECHNUNG ERFOLGREICH\n\n")
      result
    }
  ),
  
  # ─────────────────────────────────────────────────────────────────────
  # STAGE 6: OUTPUT
  # ─────────────────────────────────────────────────────────────────────
  
  tar_target(
    output_file,
    {
      if (!dir.exists("output")) {
        dir.create("output", showWarnings = FALSE)
      }
      
      version <- get_next_output_version()
      filename <- glue::glue("output/bu_v{version}.csv")
      readr::write_csv(berechnung, filename)
      
      cat(glue::glue("💾 Output gespeichert: {filename}\n\n"))
      filename
    },
    format = "file"
  )
)
