# ============================================================================
# DEPLOYMENT SCRIPT - Deploy Shiny App zu Posit Connect Cloud
# ============================================================================

# ============================================================================
# CONFIGURATION
# ============================================================================

APP_DIR <- getwd()
APP_NAME <- "budget-hochrechnung"
SERVER <- "connect.posit.cloud"
FORCE_UPDATE <- TRUE

# ============================================================================
# CHECKS
# ============================================================================

cat("\n")
cat(paste0("🚀 ", strrep("=", 70), "\n"))
cat("POSIT CONNECT CLOUD DEPLOYMENT\n")
cat(paste0("🚀 ", strrep("=", 70), "\n\n"))

# Check if rsconnect is installed
if (!require("rsconnect", quietly = TRUE)) {
  cat("❌ rsconnect nicht gefunden. Installiere...\n")
  install.packages("rsconnect")
  library(rsconnect)
}

cat("✅ rsconnect geladen\n")

# Check if account is registered
cat("\n📋 Prüfe Posit Connect Account...\n")
accounts <- tryCatch({
  rsconnect::accounts()
}, error = function(e) {
  NULL
})

if (is.null(accounts) || nrow(accounts) == 0) {
  cat("❌ Kein Account registriert!\n\n")
  cat("Bitte führe folgendes aus:\n")
  cat("  rsconnect::connectCloudUser()\n\n")
  stop("Account-Registrierung erforderlich")
}

cat(paste0("✅ Account gefunden: ", accounts$account[1], "\n"))

# ============================================================================
# PRE-DEPLOYMENT CHECKS
# ============================================================================

cat("\n📦 Pre-Deployment Checks:\n")

# Check renv.lock
if (!file.exists("renv.lock")) {
  cat("⚠️  renv.lock nicht gefunden. Erstelle...\n")
  renv::snapshot()
  cat("✅ renv.lock erstellt\n")
} else {
  cat("✅ renv.lock vorhanden\n")
}

# Check app.R
if (!file.exists("app.R")) {
  cat("❌ app.R nicht gefunden!\n")
  stop("app.R ist erforderlich für Deployment")
}
cat("✅ app.R vorhanden\n")

# Check _targets.R
if (!file.exists("_targets.R")) {
  cat("⚠️  _targets.R nicht gefunden\n")
} else {
  cat("✅ _targets.R vorhanden\n")
}

# ============================================================================
# DEPLOYMENT
# ============================================================================

cat("\n🌐 Starte Deployment...\n\n")

deployment_result <- tryCatch({
  rsconnect::deployApp(
    appDir = APP_DIR,
    appName = APP_NAME,
    server = SERVER,
    forceUpdate = FORCE_UPDATE,
    launch.browser = FALSE
  )
  
  cat("\n")
  cat(paste0("✅ ", strrep("=", 70), "\n"))
  cat("DEPLOYMENT ERFOLGREICH!\n")
  cat(paste0("✅ ", strrep("=", 70), "\n\n"))
  
  cat(glue::glue("App URL: https://{SERVER}/{accounts$account[1]}/content/\n\n"))
  
  TRUE
  
}, error = function(e) {
  cat("\n")
  cat(paste0("❌ ", strrep("=", 70), "\n"))
  cat("DEPLOYMENT FEHLGESCHLAGEN\n")
  cat(paste0("❌ ", strrep("=", 70), "\n\n"))
  
  cat("Fehler:\n")
  cat(paste0("  ", e$message, "\n\n"))
  
  cat("Lösungsoptionen:\n")
  cat("  1. Erneut versuchen: source('deploy.R')\n")
  cat("  2. Mit neuem App-Namen: Ändere APP_NAME in diesem Skript\n")
  cat("  3. Alt-App löschen auf https://connect.posit.cloud\n\n")
  
  FALSE
})

# ============================================================================
# SUMMARY
# ============================================================================

if (deployment_result) {
  cat("📊 Deployment Summary:\n")
  cat(glue::glue("  - App Name: {APP_NAME}\n"))
  cat(glue::glue("  - Server: {SERVER}\n"))
  cat(glue::glue("  - Zeit: {format(Sys.time(), '%Y-%m-%d %H:%M:%S')}\n\n"))
  
  cat("Nächste Schritte:\n")
  cat("  1. App testen: https://connect.posit.cloud\n")
  cat("  2. Dashboard öffnen und 'Starte Pipeline' Button klicken\n")
  cat("  3. Reports und Daten validieren\n\n")
} else {
  cat("Bitte überprüfe die Fehler oben und versuche erneut.\n\n")
}
