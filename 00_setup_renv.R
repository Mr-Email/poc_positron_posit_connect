# ============================================================================
# RENV SETUP SCRIPT
# ============================================================================
# Dieses Skript initialisiert renv und dokumentiert alle Projekt-Dependencies
# 
# Ausführung:
#   source("00_setup_renv.R")
# ============================================================================

cat("🚀 Budget & Hochrechnung PoC - renv Setup\n")
cat("==========================================\n\n")

# ============================================================================
# 1. INSTALLIERE RENV FALLS NÖTIG
# ============================================================================

if (!require("renv", quietly = TRUE)) {
  cat("📦 Installiere renv...\n")
  install.packages("renv")
}

# ============================================================================
# 2. INITIALISIERE RENV
# ============================================================================

cat("📝 Initialisiere renv im Projekt...\n")

if (!file.exists("renv.lock")) {
  renv::init()
  cat("✅ renv initialisiert\n\n")
} else {
  cat("ℹ️ renv.lock existiert bereits\n\n")
}

# ============================================================================
# 3. INSTALLIERE PROJEKT-DEPENDENCIES
# ============================================================================

cat("📦 Installiere Projekt-Abhängigkeiten...\n\n")

required_packages <- c(
  # Core Shiny
  "shiny",
  "bslib",
  "shinyjs",
  
  # Data Manipulation
  "dplyr",
  "tidyr",
  "readr",
  "stringr",
  "glue",
  "scales",
  
  # UI Components
  "reactable",
  "DT",
  "htmlwidgets",
  
  # Visualisierung
  "ggplot2",
  "plotly",
  
  # Data Validation
  "pointblank",
  
  # Reporting
  "quarto",
  "rmarkdown",
  "knitr",
  
  # Testing
  "testthat",
  
  # Workflow
  "targets",
  "crew",
  
  # Utilities
  "tidyverse",
  "here"
)

for (pkg in required_packages) {
  if (!require(pkg, quietly = TRUE, character.only = TRUE)) {
    cat(sprintf("  📥 Installiere %s...\n", pkg))
    install.packages(pkg)
  } else {
    cat(sprintf("  ✅ %s bereits installiert\n", pkg))
  }
}

cat("\n")

# ============================================================================
# 4. SNAPSHOT DEPENDENCIES
# ============================================================================

cat("📸 Erstelle renv.lock Snapshot...\n")
renv::snapshot()

cat("\n")

# ============================================================================
# 5. VERIFICATION
# ============================================================================

cat("✅ RENV SETUP ABGESCHLOSSEN!\n\n")
cat("Was wurde gemacht:\n")
cat("  ✓ renv initialisiert\n")
cat("  ✓ Alle Dependencies installiert\n")
cat("  ✓ renv.lock erstellt (für Reproduzierbarkeit)\n\n")

cat("Nächste Schritte:\n")
cat("  1. renv.lock zu Git hinzufügen: git add renv.lock\n")
cat("  2. Projekt-Entwicklung starten\n")
cat("  3. Bei neuen Packages: renv::snapshot() ausführen\n\n")

cat("Informationen:\n")
cat("  - renv.lock: Dokumentiert alle Package-Versionen\n")
cat("  - .Rprofile: Aktiviert renv automatisch\n")
cat("  - renv/ Ordner: Offline-Cache (optional)\n\n")

# ============================================================================
# 6. INFO ZU BESTEHENDEN UMGEBUNGEN
# ============================================================================

cat("Status renv-Umgebung:\n")
cat(sprintf("  R Version: %s\n", R.version$version.string))
cat(sprintf("  renv Version: %s\n", packageVersion("renv")))
cat(sprintf("  Projekt-Pfad: %s\n", getwd()))

cat("\n📚 Weitere Infos: https://rstudio.github.io/renv/\n")
