library(shiny)
library(dplyr)
library(bslib)
library(glue)
library(readr)
library(ggplot2)
library(tidyr)
library(pointblank)

source("R/00_config.R")
source("R/01_load_data.R")
source("R/03_calculate.R")

# ============================================================================
# THEME AUSWAHL - Hier ändern!
# ============================================================================

SELECTED_THEME <- "flatly"

ui <- page_navbar(
  title = "Budget & Hochrechnung",
  theme = bs_theme(preset = SELECTED_THEME),
  
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
  ),
  
  # TAB 3: Report
  nav_panel(
    "Report",
    layout_sidebar(
      sidebar = sidebar(
        h4("Report-Einstellungen"),
        selectInput("report_basis", "Basis-Version:", choices = character(0), width = "100%"),
        br(),
        selectInput("report_current", "Aktuelle Version:", choices = character(0), width = "100%"),
        br(),
        actionButton("btn_report_html", "📄 HTML Report anzeigen",
                     class = "btn-primary w-100 mb-2"),
        downloadButton("download_report_html", "📥 Report herunterladen (HTML)",
                       class = "btn-secondary w-100 mb-3"),
        hr(),
        h5("Status"),
        textOutput("report_status")
      ),
      
      card(
        card_header("Report Anzeige"),
        uiOutput("report_html_ui")
      )
    )
  ),
  
  # TAB 4: Datenvalidierung
  nav_panel(
    "Datenvalidierung",
    layout_sidebar(
      sidebar = sidebar(
        h4("Validierung"),
        actionButton("btn_validate_now", "✅ Validiere jetzt",
                     class = "btn-primary w-100 mb-2"),
        actionButton("btn_refresh_reports", "🔄 Reports aktualisieren",
                     class = "btn-secondary w-100 mb-3"),
        hr(),
        h5("Validierungs-Status"),
        textOutput("validation_status_text"),
        hr(),
        h5("Geladene Dateien"),
        textOutput("validation_files_loaded"),
        hr(),
        h5("Verfügbare Reports"),
        selectInput("report_select", "Report wählen:",
                    choices = character(0), width = "100%")
      ),
      
      navset_tab(
        nav_panel(
          "Hochrechnung",
          card(
            card_header("Hochrechnung Validierungs-Report"),
            htmlOutput("validation_report_hochrechnung_ui")
          )
        ),
        nav_panel(
          "Rabatt",
          card(
            card_header("Rabatt Validierungs-Report"),
            htmlOutput("validation_report_rabatt_ui")
          )
        ),
        nav_panel(
          "Betriebskosten",
          card(
            card_header("Betriebskosten Validierungs-Report"),
            htmlOutput("validation_report_betriebskosten_ui")
          )
        ),
        nav_panel(
          "SAP",
          card(
            card_header("SAP Validierungs-Report"),
            htmlOutput("validation_report_sap_ui")
          )
        )
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
    output_files = NULL,
    report_html = NULL,
    validation_agents = NULL,
    validation_success = NULL,
    validation_reports = NULL
  )
  
  # Injiziere CSS für Theme-Force-Update
  session$sendCustomMessage("force_theme_reload", SELECTED_THEME)
  
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
      updateSelectInput(session, "report_basis", choices = file_names)
      updateSelectInput(session, "report_current", choices = file_names)
    }
  }
  
  # ========== UPDATE VALIDATION REPORTS LIST ==========
  update_validation_reports <- function() {
    cat("[VALIDATION] Aktualisiere Reports-Liste\n")
    
    report_files <- list.files("output", 
                               pattern = "^validation_report_.*\\.html$", 
                               full.names = TRUE)
    
    if (length(report_files) > 0) {
      # Sortiere nach Änderungsdatum (neueste zuerst)
      file_info <- file.info(report_files)
      report_files <- report_files[order(file_info$mtime, decreasing = TRUE)]
      rv$validation_reports <- report_files
      
      # Update Dropdown
      report_names <- basename(report_files)
      updateSelectInput(session, "report_select", choices = report_names)
    } else {
      rv$validation_reports <- NULL
    }
  }
  
  # ========== UPDATE LOG FILES LIST ==========
  update_log_files <- function() {
    log_files <- list.files("output", pattern = "^pipeline_.*\\.log$", full.names = TRUE)
    
    if (length(log_files) > 0) {
      # Sortiere nach Änderungsdatum (neueste zuerst)
      file_info <- file.info(log_files)
      log_files <- log_files[order(file_info$mtime, decreasing = TRUE)]
      rv$log_files <- log_files
      
      # Update Dropdown
      log_names <- basename(log_files)
      updateSelectInput(session, "log_file_select", choices = log_names)
    } else {
      rv$log_files <- NULL
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
    update_validation_reports()  # Auch Reports laden
    update_log_files()  # Auch Logs laden
    
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
  
  # ========== BUTTON 1: HTML REPORT ANZEIGEN ==========
  observeEvent(input$btn_report_html, {
    if (is.null(input$report_basis) || is.null(input$report_current)) {
      showNotification("Bitte beide Versionen wählen", type = "warning")
      return()
    }
    
    rv$status <- "⏳ Generiere HTML Report..."
    
    tryCatch({
      # Finde Dateien
      basis_file <- rv$output_files[basename(rv$output_files) == input$report_basis][1]
      current_file <- rv$output_files[basename(rv$output_files) == input$report_current][1]
      
      # Generiere HTML
      html_file <- glue::glue("report_{format(Sys.time(), '%Y%m%d_%H%M%S')}.html")
      
      quarto::quarto_render(
        "report.qmd",
        output_file = html_file,
        execute_dir = ".",
        execute_params = list(
          basis_file = basis_file,
          current_file = current_file
        )
      )
      
      # Lade HTML in rv
      rv$report_html <- readr::read_file(html_file)
      session$userData$html_file <- html_file
      rv$status <- "✅ HTML Report generiert"
      
      showNotification("✅ Report angezeigt!", type = "message", duration = 2)
      
    }, error = function(e) {
      rv$status <- paste("❌ Fehler:", e$message)
      showNotification(paste("Fehler:", e$message), type = "error")
    })
  })
  
  # ========== DOWNLOAD: HTML HANDLER ==========
  output$download_report_html <- downloadHandler(
    filename = function() {
      glue::glue("report_{format(Sys.time(), '%Y%m%d_%H%M%S')}.html")
    },
    content = function(file) {
      html_file <- session$userData$html_file
      
      if (is.null(html_file) || !file.exists(html_file)) {
        stop("Report nicht gefunden. Bitte erst 'HTML Report anzeigen' Button klicken.")
      }
      
      file.copy(html_file, file)
    }
  )
  
  # ========== BUTTON: REFRESH REPORTS ==========
  observeEvent(input$btn_refresh_reports, {
    cat("[VALIDATION] Benutzer aktualisiert Reports\n")
    update_validation_reports()
    showNotification("✅ Reports aktualisiert!", type = "message", duration = 2)
  })
  
  # ========== BUTTON: REFRESH LOGS ==========
  observeEvent(input$btn_refresh_logs, {
    cat("[LOG] Benutzer aktualisiert Logs\n")
    update_log_files()
    showNotification("✅ Logs aktualisiert!", type = "message", duration = 2)
  })
  
  # ========== SOURCE VALIDIERUNGSFUNKTION ==========
  source("R/02_validate_data.R")
  
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
  
  # ========== OUTPUT: REPORT HTML ==========
  output$report_html_ui <- renderUI({
    if (is.null(rv$report_html)) {
      return(div(class = "alert alert-info", "Klick 'HTML Report anzeigen' um Report zu generieren"))
    }
    
    HTML(rv$report_html)
  })
  
  # ========== OUTPUT: LOG INHALT ==========
  output$log_content_ui <- renderText({
    if (is.null(input$log_file_select) || is.null(rv$log_files)) {
      return("Keine Log-Dateien vorhanden.\n\nLog-Dateien werden nach Pipeline-Ausführung generiert.")
    }
    
    # Finde vollen Pfad
    log_file <- rv$log_files[basename(rv$log_files) == input$log_file_select][1]
    
    if (!file.exists(log_file)) {
      return("Log-Datei nicht gefunden")
    }
    
    # Lese Log-Inhalt
    log_content <- readr::read_file(log_file)
    log_content
  })
  
  # ========== OUTPUT: VALIDATION REPORT HOCHRECHNUNG ==========
  output$validation_report_hochrechnung_ui <- renderUI({
    if (is.null(rv$validation_agents$hochrechnung)) {
      return(div(class = "alert alert-info", 
                 "Klick 'Validiere jetzt' um Report zu generieren"))
    }
    
    tryCatch({
      # get_agent_report() gibt gt-Objekt zurück
      report_gt <- pointblank::get_agent_report(rv$validation_agents$hochrechnung)
      # Konvertiere zu HTML
      report_html <- gt::as_raw_html(report_gt)
      HTML(report_html)
    }, error = function(e) {
      div(class = "alert alert-warning", glue::glue("Fehler beim Report: {e$message}"))
    })
  })
  
  # ========== OUTPUT: RABATT REPORT ==========
  output$validation_report_rabatt_ui <- renderUI({
    if (is.null(rv$validation_agents$rabatt)) {
      return(div(class = "alert alert-info", 
                 "Klick 'Validiere jetzt' um Report zu generieren"))
    }
    
    tryCatch({
      report_gt <- pointblank::get_agent_report(rv$validation_agents$rabatt)
      report_html <- gt::as_raw_html(report_gt)
      HTML(report_html)
    }, error = function(e) {
      div(class = "alert alert-warning", glue::glue("Fehler beim Report: {e$message}"))
    })
  })
  
  # ========== OUTPUT: BETRIEBSKOSTEN REPORT ==========
  output$validation_report_betriebskosten_ui <- renderUI({
    if (is.null(rv$validation_agents$betriebskosten)) {
      return(div(class = "alert alert-info", 
                 "Klick 'Validiere jetzt' um Report zu generieren"))
    }
    
    tryCatch({
      report_gt <- pointblank::get_agent_report(rv$validation_agents$betriebskosten)
      report_html <- gt::as_raw_html(report_gt)
      HTML(report_html)
    }, error = function(e) {
      div(class = "alert alert-warning", glue::glue("Fehler beim Report: {e$message}"))
    })
  })
  
  # ========== OUTPUT: SAP REPORT ==========
  output$validation_report_sap_ui <- renderUI({
    if (is.null(rv$validation_agents$sap)) {
      return(div(class = "alert alert-info", 
                 "Klick 'Validiere jetzt' um Report zu generieren"))
    }
    
    tryCatch({
      report_gt <- pointblank::get_agent_report(rv$validation_agents$sap)
      report_html <- gt::as_raw_html(report_gt)
      HTML(report_html)
    }, error = function(e) {
      div(class = "alert alert-warning", glue::glue("Fehler beim Report: {e$message}"))
    })
  })
  
  # ========== OUTPUT: VALIDATION STATUS ==========
  output$validation_status_text <- renderText({
    if (is.null(rv$validation_success)) {
      "⏳ Noch nicht validiert"
    } else if (rv$validation_success) {
      "✅ Validierung bestanden"
    } else {
      "❌ Validierungsfehler"
    }
  })
  
  # ========== OUTPUT: VALIDATION FILES LOADED ==========
  output$validation_files_loaded <- renderText({
    if (is.null(rv$validation_agents)) {
      return("Noch nicht validiert")
    }
    
    glue::glue(
      "Hochrechnung: {rv$loaded_hochrechnung_file}\n
       Rabatt: {rv$loaded_rabatt_file}\n
       Betriebskosten: {rv$loaded_betriebskosten_file}\n
       SAP: {rv$loaded_sap_file}"
    )
  })
  
  # ========== BUTTON: VALIDIERE JETZT ==========
  observeEvent(input$btn_validate_now, {
    cat("[VALIDATION] Benutzer startet Validierung\n")
    rv$status <- "⏳ Validiere Daten..."
    
    tryCatch({
      # Lade die RICHTIGEN Input-Dateien (nicht die Output-Dateien!)
      hochrechnung_file <- tail(list.files("data/raw", pattern = "^Input_Hochrechnung_v\\d+\\.csv$", full.names = TRUE), 1)
      rabatt_file <- tail(list.files("data/raw", pattern = "^Input_Rabatt_v\\d+\\.csv$", full.names = TRUE), 1)
      betriebskosten_file <- tail(list.files("data/raw", pattern = "^Input_Betriebskosten_v\\d+\\.csv$", full.names = TRUE), 1)
      sap_file <- tail(list.files("data/raw", pattern = "^Input_SAP_v\\d+\\.csv$", full.names = TRUE), 1)
      
      # Speichere Dateinamen für Anzeige
      rv$loaded_hochrechnung_file <- basename(hochrechnung_file)
      rv$loaded_rabatt_file <- basename(rabatt_file)
      rv$loaded_betriebskosten_file <- basename(betriebskosten_file)
      rv$loaded_sap_file <- basename(sap_file)
      
      cat("[VALIDATION] Input-Dateien geladen:\n")
      cat(glue::glue("  - {rv$loaded_hochrechnung_file}\n"))
      cat(glue::glue("  - {rv$loaded_rabatt_file}\n"))
      cat(glue::glue("  - {rv$loaded_betriebskosten_file}\n"))
      cat(glue::glue("  - {rv$loaded_sap_file}\n"))
      
      # Lade Daten
      hochrechnung <- read.csv(hochrechnung_file)
      rabatt <- read.csv(rabatt_file)
      betriebskosten <- read.csv(betriebskosten_file)
      sap <- read.csv(sap_file)
      
      # Validiere mit RICHTIGEN Dateien
      val_result <- validate_all_inputs(list(
        hochrechnung = hochrechnung,
        rabatt = rabatt,
        betriebskosten = betriebskosten,
        sap = sap
      ))
      
      rv$validation_agents <- val_result$agents
      rv$validation_success <- val_result$success
      
      # Exportiere Reports für ALLE Dateien
      if (!is.null(val_result$agents)) {
        for (agent_name in names(val_result$agents)) {
          tryCatch({
            report_file <- glue::glue("output/validation_report_{agent_name}_{format(Sys.time(), '%Y%m%d_%H%M%S')}.html")
            
            pointblank::export_report(
              val_result$agents[[agent_name]],
              filename = report_file
            )
            
            cat(glue::glue("[VALIDATION] Report exportiert: {basename(report_file)}\n"))
          }, error = function(e) {
            cat(glue::glue("[VALIDATION] Fehler beim Export für {agent_name}: {e$message}\n"))
          })
        }
      }
      
      # Aktualisiere Report-Liste
      update_validation_reports()
      
      if (val_result$success) {
        rv$status <- "✅ Validierung bestanden"
        showNotification("✅ Alle Daten validiert!", type = "message")
      } else {
        rv$status <- "❌ Validierungsfehler gefunden"
        showNotification("❌ Fehler in den Daten", type = "error")
      }
    }, error = function(e) {
      rv$status <- paste("❌ Fehler:", e$message)
      showNotification(paste("Fehler:", e$message), type = "error")
      cat(glue::glue("[VALIDATION ERROR] {e$message}\n"))
    })
  })
}

shinyApp(ui, server)
