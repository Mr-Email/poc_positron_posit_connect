library(shiny)
library(dplyr)
library(bslib)
library(glue)
library(readr)
library(ggplot2)
library(tidyr)

source("R/00_config.R")
source("R/01_load_data.R")
source("R/03_calculate.R")

# ============================================================================
# UI
# ============================================================================

ui <- page_navbar(
  title = "Budget & Hochrechnung",
  theme = bs_theme(preset = "flatly"),
  
  # TAB 1: Dashboard
  nav_panel(
    "Dashboard",
    layout_sidebar(
      sidebar = sidebar(
        h4("Aktionen"),
        actionButton("btn_generate", "🎲 Generiere Daten",
                     class = "btn-info btn-lg w-100 mb-2"),
        actionButton("btn_pipeline", "🚀 Starte Pipeline",
                     class = "btn-success btn-lg w-100 mb-3"),
        hr(),
        h5("Status"),
        textOutput("status")
      ),
      
      card(
        card_header("Aktuelle Berechnung"),
        tableOutput("dashboard_table")
      )
    )
  ),
  
  # TAB 2: Änderungen
  nav_panel(
    "Änderungen",
    layout_sidebar(
      sidebar = sidebar(
        h4("Vergleich"),
        selectInput("file1", "Erste Berechnung:", choices = character(0), width = "100%"),
        br(),
        selectInput("file2", "Zweite Berechnung:", choices = character(0), width = "100%"),
        br(),
        actionButton("btn_compare", "Vergleichen",
                     class = "btn-primary w-100")
      ),
      
      # Analyse & Grafiken
      card(
        card_header("📊 Unterschiede Visualisiert"),
        plotOutput("plot_changes", height = "400px")
      ),
      br(),
      card(
        card_header("📈 Detaillierter Vergleich"),
        tableOutput("analysis_differences")
      )
    )
  )
)

# ============================================================================
# SERVER
# ============================================================================

server <- function(input, output, session) {
  
  rv <- reactiveValues(
    status = "Bereit",
    latest_data = NULL,
    compare_data1 = NULL,
    compare_data2 = NULL,
    output_files = NULL
  )
  
  # ========== UPDATE OUTPUT FILES LIST ==========
  update_file_list <- function() {
    files <- list.files("output", pattern = "^bu_v.*\\.csv$", full.names = TRUE)
    
    if (length(files) > 0) {
      # Sortiere nach Änderungsdatum (neueste zuerst)
      file_info <- file.info(files)
      files <- files[order(file_info$mtime, decreasing = TRUE)]
      rv$output_files <- files
      
      # Update Dropdowns
      file_names <- basename(files)
      updateSelectInput(session, "file1", choices = file_names)
      updateSelectInput(session, "file2", choices = file_names)
    }
  }
  
  # ========== LOAD CSV ==========
  load_csv <- function(file_path) {
    tryCatch({
      read_csv(file_path, show_col_types = FALSE)
    }, error = function(e) {
      NULL
    })
  }
  
  # ========== BEIM APP-START ==========
  observeEvent(TRUE, {
    update_file_list()
    
    # Lade neueste Berechnung
    if (!is.null(rv$output_files) && length(rv$output_files) > 0) {
      latest <- load_csv(rv$output_files[1])
      if (!is.null(latest)) {
        rv$latest_data <- latest
        rv$status <- "✅ Bereit"
      }
    } else {
      rv$status <- "ℹ️ Keine Daten vorhanden"
    }
  }, once = TRUE)
  
  # ========== BUTTON 1: GENERIERE DATEN ==========
  observeEvent(input$btn_generate, {
    rv$status <- "⏳ Generiere Daten..."
    
    tryCatch({
      source("R/00_generate_dummy_data.R")
      rv$status <- "✅ Daten generiert"
      showNotification("✅ Daten generiert!", type = "message", duration = 3)
    }, error = function(e) {
      rv$status <- paste("❌ Fehler:", e$message)
      showNotification(paste("Fehler:", e$message), type = "error")
    })
  })
  
  # ========== BUTTON 2: PIPELINE ==========
  observeEvent(input$btn_pipeline, {
    rv$status <- "⏳ Pipeline läuft..."
    
    tryCatch({
      targets::tar_make(callr_function = NULL)
      
      # Lade neueste Ergebnisse
      update_file_list()
      
      if (!is.null(rv$output_files) && length(rv$output_files) > 0) {
        latest <- load_csv(rv$output_files[1])
        if (!is.null(latest)) {
          rv$latest_data <- latest
          rv$status <- "✅ Pipeline abgeschlossen"
          showNotification("✅ Pipeline erfolgreich!", type = "message", duration = 3)
        }
      }
    }, error = function(e) {
      rv$status <- paste("❌ Fehler:", e$message)
      showNotification(paste("Fehler:", e$message), type = "error")
    })
  })
  
  # ========== BUTTON: VERGLEICHEN ==========
  observeEvent(input$btn_compare, {
    if (is.null(input$file1) || is.null(input$file2)) {
      showNotification("Bitte beide Dateien wählen", type = "warning")
      return()
    }
    
    # Finde vollen Pfad
    file1_path <- rv$output_files[basename(rv$output_files) == input$file1][1]
    file2_path <- rv$output_files[basename(rv$output_files) == input$file2][1]
    
    # Lade Daten
    rv$compare_data1 <- load_csv(file1_path)
    rv$compare_data2 <- load_csv(file2_path)
    
    showNotification("✅ Vergleich geladen", type = "message", duration = 2)
  })
  
  # ========== OUTPUT: STATUS ==========
  output$status <- renderText({
    rv$status
  })
  
  # ========== OUTPUT: DASHBOARD TABLE ==========
  output$dashboard_table <- renderTable({
    if (is.null(rv$latest_data)) {
      return(data.frame(Message = "Keine Daten - bitte Pipeline starten"))
    }
    
    rv$latest_data
  }, striped = TRUE)
  
  # ========== OUTPUT: ANALYSE - UNTERSCHIEDE ==========
  output$analysis_differences <- renderTable({
    if (is.null(rv$compare_data1) || is.null(rv$compare_data2)) {
      return(data.frame(Message = "Bitte Vergleichen klicken"))
    }
    
    # Extrahiere nur SQ und CR Spalten
    data1 <- rv$compare_data1 |>
      select(product_id, sq, cr) |>
      rename(sq_alt = sq, cr_alt = cr)
    
    data2 <- rv$compare_data2 |>
      select(product_id, sq, cr) |>
      rename(sq_neu = sq, cr_neu = cr)
    
    # Vergleiche
    analysis <- data1 |>
      inner_join(data2, by = "product_id") |>
      mutate(
        sq_change_pct = ((sq_neu - sq_alt) / sq_alt) * 100,
        cr_change_pct = ((cr_neu - cr_alt) / cr_alt) * 100
      ) |>
      select(
        product_id,
        sq_alt, sq_neu, sq_change_pct,
        cr_alt, cr_neu, cr_change_pct
      ) |>
      mutate(
        across(c(sq_alt, sq_neu, sq_change_pct, cr_alt, cr_neu, cr_change_pct),
               ~round(., 2))
      )
    
    colnames(analysis) <- c(
      "Produkt",
      "SQ Alt", "SQ Neu", "SQ Diff %",
      "CR Alt", "CR Neu", "CR Diff %"
    )
    
    analysis
  }, striped = TRUE)
  
  # ========== OUTPUT: FANCY GRAPH ==========
  output$plot_changes <- renderPlot({
    if (is.null(rv$compare_data1) || is.null(rv$compare_data2)) {
      return(NULL)
    }
    
    # Extrahiere Daten
    data1 <- rv$compare_data1 |>
      select(product_id, sq, cr) |>
      rename(sq_alt = sq, cr_alt = cr)
    
    data2 <- rv$compare_data2 |>
      select(product_id, sq, cr) |>
      rename(sq_neu = sq, cr_neu = cr)
    
    # Berechne Änderungen
    plot_data <- data1 |>
      inner_join(data2, by = "product_id") |>
      mutate(
        sq_change = ((sq_neu - sq_alt) / sq_alt) * 100,
        cr_change = ((cr_neu - cr_alt) / cr_alt) * 100
      ) |>
      pivot_longer(
        cols = c(sq_change, cr_change),
        names_to = "metric",
        values_to = "change_pct"
      ) |>
      mutate(
        metric = ifelse(metric == "sq_change", "Schadenquote (SQ)", "Combined Ratio (CR)"),
        color = ifelse(change_pct > 0, "Verschlechtert", "Verbessert")
      )
    
    # Fancy Plot
    ggplot(plot_data, aes(x = reorder(product_id, change_pct), y = change_pct, fill = color)) +
      geom_col() +
      geom_hline(yintercept = 0, color = "black", linewidth = 0.8) +
      facet_wrap(~metric, scales = "free_x") +
      scale_fill_manual(
        values = c("Verbessert" = "#2ecc71", "Verschlechtert" = "#e74c3c"),
        name = "Trend"
      ) +
      labs(
        title = "Änderungen zwischen Berechnungen",
        subtitle = "Positive Werte = Verschlechterung, Negative = Verbesserung",
        x = "Produkt",
        y = "Änderung (%)"
      ) +
      theme_minimal() +
      theme(
        plot.title = element_text(size = 16, face = "bold"),
        plot.subtitle = element_text(size = 12, color = "gray60"),
        axis.text.x = element_text(angle = 45, hjust = 1),
        panel.grid.major.y = element_line(color = "gray90"),
        legend.position = "bottom"
      )
  })
}

shinyApp(ui, server)
