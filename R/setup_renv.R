# ============================================================================
# renv SETUP & INITIALIZATION
# ============================================================================

setup_renv <- function(reinstall = FALSE) {
  
  cat("\n")
  cat(strrep("=", 70), "\n")
  cat("🔧 renv SETUP\n")
  cat(strrep("=", 70), "\n\n")
  
  # 1. Prüfe ob renv initialisiert ist
  if (!file.exists("renv.lock")) {
    cat("📦 Initialisiere renv...\n")
    renv::init()
  } else {
    cat("✅ renv bereits initialisiert\n")
  }
  
  # 2. Definiere alle benötigten Packages
  required_packages <- list(
    # Shiny UI & Interaktion
    shiny = "latest",
    bslib = "latest",
    reactable = "latest",
    
    # Data Manipulation
    dplyr = "latest",
    tidyr = "latest",
    readr = "latest",
    stringr = "latest",
    glue = "latest",
    scales = "latest",
    
    # Visualisierung
    ggplot2 = "latest",
    
    # Workflow & Validierung
    targets = "latest",
    pointblanc = "latest",
    
    # Testing & Reporting
    testthat = "latest",
    knitr = "latest",
    quarto = "latest"
  )
  
  cat("\n📋 Erforderliche Packages:\n")
  for (pkg in names(required_packages)) {
    cat(glue("   • {pkg}\n"))
  }
  
  # 3. Installiere Packages
  cat("\n⬇️  Installiere Packages...\n")
  
  if (reinstall) {
    cat("   (mit Neuinstallation)\n\n")
    renv::install(names(required_packages), rebuild = TRUE)
  } else {
    cat("   (Update nur wenn notwendig)\n\n")
    renv::install(names(required_packages))
  }
  
  # 4. Snapshot erstellen
  cat("\n💾 Erstelle Snapshot...\n")
  renv::snapshot(prompt = FALSE)
  
  # 4.5 Installiere TinyTeX für PDF-Reports
  cat("\n📄 Installiere TinyTeX für PDF-Reports...\n")
  tryCatch({
    quarto::quarto_install_tinytex()
    cat("   ✅ TinyTeX installiert\n")
  }, error = function(e) {
    cat("   ⚠️ TinyTeX-Installation übersprungen\n")
    cat("   Später manuell ausführen: quarto::quarto_install_tinytex()\n")
  })
  
  # 5. Status prüfen
  cat("\n✅ Status:\n")
  status <- renv::status()
  
  if (nrow(status) == 0) {
    cat("   ✓ Alle Packages sind synchronisiert\n")
  } else {
    cat(glue("   ⚠️  {nrow(status)} Unterschiede gefunden\n"))
    print(status)
  }
  
  cat("\n")
  cat(strrep("=", 70), "\n")
  cat("✅ Setup abgeschlossen!\n")
  cat(strrep("=", 70), "\n\n")
  
  cat("Nächste Schritte:\n")
  cat("  1. source('R/setup_renv.R')\n")
  cat("  2. setup_renv()  # Einmalig ausführen\n")
  cat("  3. shiny::runApp('app.R')\n\n")
}

# ============================================================================
# RESTORE DEPENDENCIES (Falls renv.lock bereits vorhanden)
# ============================================================================

restore_renv <- function() {
  
  cat("\n")
  cat(strrep("=", 70), "\n")
  cat("📥 renv RESTORE\n")
  cat(strrep("=", 70), "\n\n")
  
  if (!file.exists("renv.lock")) {
    stop("❌ renv.lock nicht gefunden. Bitte zuerst setup_renv() ausführen!")
  }
  
  cat("Stellt alle Packages aus renv.lock wieder her...\n\n")
  renv::restore(prompt = FALSE)
  
  cat("\n✅ Restore abgeschlossen!\n")
  cat(strrep("=", 70), "\n\n")
}

# ============================================================================
# QUICK CHECK
# ============================================================================

check_dependencies <- function() {
  
  cat("\n")
  cat(strrep("=", 70), "\n")
  cat("🔍 DEPENDENCY CHECK\n")
  cat(strrep("=", 70), "\n\n")
  
  required_packages <- c(
    "shiny", "dplyr", "reactable", "bslib", "targets",
    "glue", "readr", "ggplot2", "tidyr", "stringr",
    "scales", "pointblanc", "testthat", "knitr", "quarto"
  )
  
  missing <- c()
  
  for (pkg in required_packages) {
    if (require(pkg, character.only = TRUE, quietly = TRUE)) {
      cat(glue("✅ {pkg}\n"))
    } else {
      cat(glue("❌ {pkg} FEHLT\n"))
      missing <- c(missing, pkg)
    }
  }
  
  cat("\n")
  
  if (length(missing) == 0) {
    cat("✅ Alle Abhängigkeiten vorhanden!\n")
  } else {
    cat(glue("❌ {length(missing)} Packages fehlen:\n"))
    cat(paste("   •", missing, collapse = "\n"))
    cat("\nAusführen:\n")
    cat("  renv::install(c('", paste(missing, collapse = "', '"), "'))\n")
  }
  
  cat(strrep("=", 70), "\n\n")
}
