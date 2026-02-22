source("test/_test_helpers.R")

cat("\n")
cat(paste0("🚀 ", strrep("=", 70), "\n"))
cat("🧪 VALIDIERUNGS-TEST - ALLE 4 INPUT-DATEIEN\n")
cat(paste0("🚀 ", strrep("=", 70), "\n\n"))

source("R/02_validate_data.R")
source("R/01_load_data.R")
source("R/00_config.R")

results <- list()

# ========== LADE ALLE VERFÜGBAREN VERSIONEN ==========
cat("Schritt 1: Suche alle Input-Dateien...\n\n")

hochrechnung_files <- list.files("data/raw", pattern = "^Input_Hochrechnung_v\\d+\\.csv$", full.names = TRUE)
rabatt_files <- list.files("data/raw", pattern = "^Input_Rabatt_v\\d+\\.csv$", full.names = TRUE)
betriebskosten_files <- list.files("data/raw", pattern = "^Input_Betriebskosten_v\\d+\\.csv$", full.names = TRUE)
sap_files <- list.files("data/raw", pattern = "^Input_SAP_v\\d+\\.csv$", full.names = TRUE)

cat(glue::glue("Hochrechnung: {length(hochrechnung_files)} Versionen gefunden\n"))
cat(glue::glue("Rabatt: {length(rabatt_files)} Versionen gefunden\n"))
cat(glue::glue("Betriebskosten: {length(betriebskosten_files)} Versionen gefunden\n"))
cat(glue::glue("SAP: {length(sap_files)} Versionen gefunden\n\n"))

# ========== LADE NEUESTE VERSIONEN ==========
cat("Schritt 2: Lade neueste Versionen...\n\n")

hochrechnung <- read.csv(tail(hochrechnung_files, 1))
rabatt <- read.csv(tail(rabatt_files, 1))
betriebskosten <- read.csv(tail(betriebskosten_files, 1))
sap <- read.csv(tail(sap_files, 1))

cat(glue::glue("✅ Hochrechnung: {nrow(hochrechnung)} Zeilen\n"))
cat(glue::glue("✅ Rabatt: {nrow(rabatt)} Zeilen\n"))
cat(glue::glue("✅ Betriebskosten: {nrow(betriebskosten)} Zeilen\n"))
cat(glue::glue("✅ SAP: {nrow(sap)} Zeilen\n\n"))

# ========== VALIDIERE ALLE DATEIEN ==========
cat("Schritt 3: Validiere alle Dateien...\n\n")

inputs <- list(
  hochrechnung = hochrechnung,
  rabatt = rabatt,
  betriebskosten = betriebskosten,
  sap = sap
)

val_result <- validate_all_inputs(inputs)

cat("\n")
cat(paste0("=" , strrep("=", 70), "\n"))

if (val_result$success) {
  cat("✅ ALLE VALIDIERUNGEN BESTANDEN\n")
  results[[1]] <- test_result("Valid data", TRUE, "Alle Checks bestanden")
} else {
  cat("❌ VALIDIERUNGSFEHLER:\n")
  if (!is.null(val_result$errors)) {
    for (err in val_result$errors) {
      cat(glue::glue("  - {err}\n"))
    }
  }
  results[[1]] <- test_result("Valid data", FALSE, "Fehler gefunden")
}

cat(paste0("=" , strrep("=", 70), "\n\n"))

# ========== EXPORTIERE ALLE REPORTS ==========
cat("Schritt 4: Exportiere Reports für alle Dateien...\n\n")

if (!is.null(val_result$agents)) {
  for (agent_name in names(val_result$agents)) {
    tryCatch({
      report_file <- glue::glue("output/validation_report_{agent_name}_{format(Sys.time(), '%Y%m%d_%H%M%S')}.html")
      
      pointblank::export_report(
        val_result$agents[[agent_name]],
        filename = report_file
      )
      
      cat(glue::glue("✅ {agent_name}: {basename(report_file)}\n"))
      results[[4]] <- test_result("Export report", TRUE, basename(report_file))
    }, error = function(e) {
      cat(glue::glue("❌ {agent_name}: Fehler - {e$message}\n"))
      results[[4]] <- test_result("Export report", FALSE, e$message)
    })
  }
}

cat("\n")
cat(paste0("=" , strrep("=", 70), "\n"))
cat("✅ Test abgeschlossen\n")
cat(paste0("=" , strrep("=", 70), "\n\n"))
