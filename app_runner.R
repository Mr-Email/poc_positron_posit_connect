# ============================================================================
# SHINY APP RUNNER - Startet die Budget & Hochrechnung Shiny App
# ============================================================================

# Stelle sicher, dass wir im Projekt-Root sind
if (!file.exists("app.R")) {
  stop("app.R nicht gefunden! Bitte aus dem Projekt-Root-Verzeichnis ausführen.")
}

# Starte die Shiny App
cat("\n")
cat(paste0("🚀 ", strrep("=", 70), "\n"))
cat("STARTE SHINY APP: Budget & Hochrechnung\n")
cat(paste0("🚀 ", strrep("=", 70), "\n\n"))

shiny::runApp("app.R", launch.browser = TRUE)
