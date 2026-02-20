library(shiny)
library(dplyr)
library(DT)

# ============================================================================
# LOAD R FUNCTIONS - Path-Handling für Shiny
# ============================================================================

# Bestimme Projekt-Root korrekt
project_root <- Sys.getenv("PROJECT_ROOT")
if (project_root == "") {
  # Fallback: Nutze Umgebungsvariable oder gehe 1 Level up von shiny_app/
  tryCatch({
    # Wenn von Positron/RStudio aus gestartet
    project_root <- dirname(dirname(getwd()))
  }, error = function(e) {
    # Fallback auf HOME
    project_root <- "."
  })
}

# Lade alle R-Funktionen
source(file.path(project_root, "R/00_config.R"), local = TRUE)
source(file.path(project_root, "R/01_load_data.R"), local = TRUE)
source(file.path(project_root, "R/02_validate_data.R"), local = TRUE)
source(file.path(project_root, "R/03_calculate.R"), local = TRUE)

# ============================================================================
# SHINY UI
# ============================================================================

ui <- navbarPage(
  title = "Budget & Hochrechnung PoC",
  theme = bslib::bs_theme(version = 5, bootswatch = "flatly"),
  
  # TAB 1: UPLOAD & VALIDIERUNG
  tabPanel(
    title = "📤 Upload & Validierung",
    icon = icon("upload"),
    
    div(class = "container mt-5",
      h2("Input-Dateien hochladen"),
      p("Laden Sie die 4 erforderlichen CSV-Dateien hoch. Die Validierung erfolgt automatisch."),
      hr(),
      
      # Upload-Bereich
      div(class = "row",
        div(class = "col-md-6 mb-4",
          div(class = "card",
            div(class = "card-body",
              h5(class = "card-title", "📊 Input_Hochrechnung.csv"),
              p(class = "text-muted", "Spalten: product_id, bestand, bvp, nvl"),
              fileInput("file_hochrechnung", label = NULL, accept = ".csv",
                       buttonLabel = "Datei wählen")
            )
          )
        ),
        div(class = "col-md-6 mb-4",
          div(class = "card",
            div(class = "card-body",
              h5(class = "card-title", "💰 Input_Rabatt.csv"),
              p(class = "text-muted", "Spalten: product_id, fam_rab, mj_rab"),
              fileInput("file_rabatt", label = NULL, accept = ".csv",
                       buttonLabel = "Datei wählen")
            )
          )
        ),
        div(class = "col-md-6 mb-4",
          div(class = "card",
            div(class = "card-body",
              h5(class = "card-title", "🏭 Input_Betriebskosten.csv"),
              p(class = "text-muted", "Spalten: product_id, sm, bk"),
              fileInput("file_betriebskosten", label = NULL, accept = ".csv",
                       buttonLabel = "Datei wählen")
            )
          )
        ),
        div(class = "col-md-6 mb-4",
          div(class = "card",
            div(class = "card-body",
              h5(class = "card-title", "💾 Input_SAP.csv"),
              p(class = "text-muted", "Spalten: product_id, advo, pd, sap"),
              fileInput("file_sap", label = NULL, accept = ".csv",
                       buttonLabel = "Datei wählen")
            )
          )
        )
      ),
      
      hr(),
      h4("Validierungs-Ergebnis"),
      verbatimTextOutput("validation_output"),
      hr(),
      
      div(class = "d-grid gap-2",
        actionButton("btn_calculate", label = "🚀 Berechnung starten",
                    class = "btn-primary btn-lg", disabled = TRUE),
        style = "margin-bottom: 20px;"
      ),
      p("Die Berechnung wird gestartet, sobald alle Dateien validiert sind.",
        class = "text-muted")
    )
  ),
  
  # TAB 2: ERGEBNISSE
  tabPanel(
    title = "📋 Ergebnisse",
    icon = icon("chart-bar"),
    
    div(class = "container mt-5",
      h2("Berechnungs-Ergebnisse"),
      uiOutput("results_info"),
      
      div(id = "results_panel", style = "display: none;",
        h4("Zusammenfassung"),
        DTOutput("results_table"),
        hr(),
        
        h4("Downloads"),
        div(class = "row",
          div(class = "col-md-4",
            downloadButton("download_csv", "📥 CSV herunterladen",
                         class = "btn-success w-100")
          ),
          div(class = "col-md-4",
            downloadButton("download_report", "📄 Report (HTML)",
                         class = "btn-info w-100")
          ),
          div(class = "col-md-4",
            downloadButton("download_powerpoint", "🎯 PowerPoint",
                         class = "btn-warning w-100")
          )
        ),
        style = "margin-bottom: 20px;",
        hr(),
        
        h4("KPI-Analyse"),
        div(class = "row",
          div(class = "col-md-6",
            div(class = "card",
              div(class = "card-body",
                h6("Schadenquote (SQ) - Ziel: 60-80%"),
                tableOutput("sq_summary")
              )
            )
          ),
          div(class = "col-md-6",
            div(class = "card",
              div(class = "card-body",
                h6("Combined Ratio (CR) - Ziel: 85-105%"),
                tableOutput("cr_summary")
              )
            )
          )
        )
      )
    )
  )
)

# ============================================================================
# SHINY SERVER
# ============================================================================

server <- function(input, output, session) {
  
  inputs_data <- reactiveVal(NULL)
  validation_result <- reactiveVal(NULL)
  calculation_result <- reactiveVal(NULL)
  
  # UPLOAD & VALIDIERUNG
  observe({
    req(input$file_hochrechnung, input$file_rabatt,
        input$file_betriebskosten, input$file_sap)
    
    tryCatch({
      inputs <- load_all_inputs(
        input$file_hochrechnung$datapath,
        input$file_rabatt$datapath,
        input$file_betriebskosten$datapath,
        input$file_sap$datapath
      )
      
      inputs_data(inputs)
      val_result <- validate_all_inputs(inputs)
      validation_result(val_result)
      
      if (val_result$is_valid_all) {
        shinyjs::removeClass("btn_calculate", "disabled")
      } else {
        shinyjs::addClass("btn_calculate", "disabled")
      }
      
    }, error = function(e) {
      validation_result(list(is_valid_all = FALSE, results = list()))
      shinyjs::addClass("btn_calculate", "disabled")
      showNotification(paste("Fehler beim Laden:", conditionMessage(e)),
                      type = "error", duration = 10)
    })
  })
  
  output$validation_output <- renderText({
    req(validation_result())
    val_result <- validation_result()
    
    if (val_result$is_valid_all) {
      "✅ ALLE DATEIEN VALIDIERT - Berechnung kann gestartet werden!"
    } else {
      errors_text <- lapply(names(val_result$results), function(key) {
        result <- val_result$results[[key]]
        file_name <- INPUT_FILES[[key]]$name
        if (result$is_valid) {
          paste("✅", file_name, "- OK")
        } else {
          c(paste("❌", file_name, "- FEHLER:"),
            paste("   ", result$errors))
        }
      })
      paste(unlist(errors_text), collapse = "\n")
    }
  })
  
  # BERECHNUNG
  observeEvent(input$btn_calculate, {
    req(inputs_data())
    tryCatch({
      result <- calculate_budget(inputs_data())
      calculation_result(result)
      updateNavbarPage(session, "tab", selected = "📋 Ergebnisse")
      showNotification("✅ Berechnung erfolgreich!", type = "message", duration = 5)
    }, error = function(e) {
      showNotification(paste("Fehler:", conditionMessage(e)),
                      type = "error", duration = 10)
    })
  })
  
  # RESULTS TAB
  output$results_info <- renderUI({
    if (is.null(calculation_result())) {
      div(class = "alert alert-info",
        "Laden Sie Input-Dateien hoch und starten Sie die Berechnung.")
    } else {
      shinyjs::show("results_panel")
    }
  })
  
  output$results_table <- renderDT({
    req(calculation_result())
    summary_data <- prepare_summary(calculation_result())
    datatable(summary_data,
             options = list(pageLength = 5, scrollX = TRUE, dom = 'Bfrtip'),
             extensions = 'Buttons')
  })
  
  output$sq_summary <- renderTable({
    req(calculation_result())
    prepare_summary(calculation_result()) |>
      select(product_id, sq) |>
      mutate(status = case_when(
        sq < 0.60 ~ "⚠️ Zu niedrig",
        sq > 0.80 ~ "⚠️ Zu hoch",
        TRUE ~ "✅ OK"
      ))
  })
  
  output$cr_summary <- renderTable({
    req(calculation_result())
    prepare_summary(calculation_result()) |>
      select(product_id, cr) |>
      mutate(status = case_when(
        cr < 0.85 ~ "✅ Gut",
        cr > 1.05 ~ "⚠️ Zu hoch",
        TRUE ~ "✅ OK"
      ))
  })
  
  # DOWNLOADS
  output$download_csv <- downloadHandler(
    filename = function() paste0("budget_", Sys.Date(), ".csv"),
    content = function(file) {
      req(calculation_result())
      readr::write_csv(prepare_summary(calculation_result()), file)
    }
  )
  
  output$download_report <- downloadHandler(
    filename = function() paste0("report_", Sys.Date(), ".html"),
    content = function(file) {
      req(calculation_result())
      html <- paste("<html><head><meta charset='UTF-8'><title>Report</title>",
        "</head><body style='font-family:Arial;margin:20px;'>",
        "<h1>Budget Report</h1>",
        "<p>Generiert:", format(Sys.time(), "%d.%m.%Y %H:%M"), "</p>",
        "<h2>Zusammenfassung</h2>",
        paste(capture.output(print(prepare_summary(calculation_result()))), 
              collapse = "<br>"),
        "</body></html>", sep = "")
      writeLines(html, file)
    }
  )
  
  output$download_powerpoint <- downloadHandler(
    filename = function() paste0("presentation_", Sys.Date(), ".pptx"),
    content = function(file) {
      showNotification("PowerPoint-Export kommt in Phase 4", type = "warning")
    }
  )
}

# ============================================================================
# STARTE APP
# ============================================================================

shinyApp(ui = ui, server = server)
