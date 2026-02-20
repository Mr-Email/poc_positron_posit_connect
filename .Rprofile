# Automatisches Setup beim Projekt-Start
if (interactive()) {
  # Setze Projekt-Root
  if (!exists("project_root")) {
    # Versuche hier() zu nutzen
    tryCatch({
      library(here)
      project_root <- here::here()
    }, error = function(e) {
      # Fallback: nutze Umgebungsvariable oder setwd
      project_root <- getwd()
    })
    
    # Exportiere für Shiny
    Sys.setenv(PROJECT_ROOT = project_root)
  }
}

source("renv/activate.R")
