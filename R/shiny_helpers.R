# ============================================================================
# Helper-Funktionen für Shiny App
# ============================================================================

# Lade die neuesten Berechnungsergebnisse aus targets-Output
load_latest_results <- function() {
  tryCatch({
    # Versuche, Ergebnisse aus targets zu laden
    results <- targets::tar_read(berechnung)
    return(results)
  }, error = function(e) {
    # Fallback: Lade CSV aus output-Verzeichnis
    files <- list.files("output", pattern = "^berechnung_.*\\.csv$", full.names = TRUE)
    if (length(files) == 0) return(NULL)
    
    latest_file <- sort(files, decreasing = TRUE)[1]
    readr::read_csv(latest_file, show_col_types = FALSE)
  })
}

# Gebe alle verfügbaren Input-Dateien mit Versionen zurück
get_available_input_files <- function() {
  files_list <- list()
  
  for (input_name in c("Input_Hochrechnung", "Input_Rabatt", "Input_Betriebskosten", "Input_SAP")) {
    pattern <- glue::glue("^{input_name}_v\\d+\\.csv$")
    files <- list.files("data/raw", pattern = pattern, full.names = TRUE)
    
    if (length(files) > 0) {
      # Finde die neueste Version
      versions <- stringr::str_extract(files, "\\d+") |> as.numeric()
      latest_idx <- which.max(versions)
      latest_file <- files[latest_idx]
      latest_version <- sprintf("%03d", versions[latest_idx])
      
      files_list[[input_name]] <- latest_file
      attr(files_list[[input_name]], "version") <- latest_version
    }
  }
  
  files_list
}

# Hole die neueste Versionsnummer für einen Input
get_latest_version <- function(input_name) {
  pattern <- glue::glue("^{input_name}_v\\d+\\.csv$")
  files <- list.files("data/raw", pattern = pattern)
  
  if (length(files) == 0) {
    return("000")
  }
  
  versions <- stringr::str_extract(files, "\\d+") |> as.numeric()
  sprintf("%03d", max(versions))
}

# Gebe eine Tabelle mit allen Input-Versionen zurück
get_input_versions <- function() {
  versions_df <- data.frame(
    Input = character(),
    Version = character(),
    File = character(),
    stringsAsFactors = FALSE
  )
  
  for (input_name in c("Input_Hochrechnung", "Input_Rabatt", "Input_Betriebskosten", "Input_SAP")) {
    version <- get_latest_version(input_name)
    file_name <- glue::glue("{input_name}_v{version}.csv")
    
    versions_df <- rbind(versions_df, data.frame(
      Input = input_name,
      Version = version,
      File = file_name
    ))
  }
  
  versions_df
}

# Sichere das aktuelle targets-Metadaten-Objekt
tar_meta <- function(store = "_targets") {
  tryCatch({
    meta_path <- file.path(store, "meta", "meta")
    if (!file.exists(meta_path)) {
      return(data.frame())
    }
    
    # Vereinfachte Darstellung von targets-Metadaten
    targets::tar_meta(store = store)
  }, error = function(e) {
    data.frame()
  })
}

# ============================================================================
# VERSIONS-VERGLEICH & AUDIT-TRAIL
# ============================================================================

# Lade eine spezifische alte Input-Version
load_input_version <- function(input_name, version) {
  # input_name: "Input_Hochrechnung", "Input_Rabatt", etc.
  # version: "001", "002", etc.
  
  file_name <- glue::glue("{input_name}_v{version}.csv")
  file_path <- file.path("data/raw", file_name)
  
  if (!file.exists(file_path)) {
    stop(glue::glue("Datei nicht gefunden: {file_name}"))
  }
  
  readr::read_csv(file_path, show_col_types = FALSE)
}

# Gebe alle verfügbaren Versionen für einen Input zurück
get_all_versions <- function(input_name) {
  # Beispiel: get_all_versions("Input_Rabatt")
  # Gibt zurück: c("001", "002", "003")
  
  pattern <- glue::glue("^{input_name}_v\\d+\\.csv$")
  files <- list.files("data/raw", pattern = pattern)
  
  if (length(files) == 0) {
    return(character(0))
  }
  
  versions <- stringr::str_extract(files, "\\d+") |>
    sort()
  
  versions
}

# Vergleiche zwei Versionen eines Inputs (alt vs. neu)
compare_input_versions <- function(input_name, old_version, new_version) {
  # Lade beide Versionen
  old_data <- load_input_version(input_name, old_version)
  new_data <- load_input_version(input_name, new_version)
  
  # Vereinige nach product_id
  comparison <- dplyr::full_join(
    old_data |> dplyr::rename_with(~paste0(., "_old"), -product_id),
    new_data |> dplyr::rename_with(~paste0(., "_new"), -product_id),
    by = "product_id"
  )
  
  # Berechne Differenzen für numerische Spalten
  numeric_cols <- colnames(comparison) |>
    stringr::str_subset("_old$") |>
    stringr::str_remove("_old$")
  
  for (col in numeric_cols) {
    old_col <- glue::glue("{col}_old")
    new_col <- glue::glue("{col}_new")
    diff_col <- glue::glue("{col}_diff")
    pct_col <- glue::glue("{col}_pct_change")
    
    if (old_col %in% colnames(comparison) && new_col %in% colnames(comparison)) {
      comparison <- comparison |>
        dplyr::mutate(
          !!diff_col := !!rlang::sym(new_col) - !!rlang::sym(old_col),
          !!pct_col := ifelse(
            !!rlang::sym(old_col) == 0,
            NA_real_,
            (!!rlang::sym(diff_col) / abs(!!rlang::sym(old_col))) * 100
          )
        )
    }
  }
  
  comparison
}

# Berechne KPIs für beide Versionen und vergleiche
compare_kpi_versions <- function(input_name, old_version, new_version) {
  # Lade beide Versionen
  old_data <- load_input_version(input_name, old_version)
  new_data <- load_input_version(input_name, new_version)
  
  # Lade alle anderen Inputs (neueste Versionen)
  all_inputs_old <- load_all_inputs(
    hochrechnung_path = if (input_name == "Input_Hochrechnung") 
                          file.path("data/raw", glue::glue("Input_Hochrechnung_v{old_version}.csv")) 
                        else get_latest_input_path("Input_Hochrechnung"),
    rabatt_path = if (input_name == "Input_Rabatt") 
                    file.path("data/raw", glue::glue("Input_Rabatt_v{old_version}.csv")) 
                  else get_latest_input_path("Input_Rabatt"),
    betriebskosten_path = if (input_name == "Input_Betriebskosten") 
                            file.path("data/raw", glue::glue("Input_Betriebskosten_v{old_version}.csv")) 
                          else get_latest_input_path("Input_Betriebskosten"),
    sap_path = if (input_name == "Input_SAP") 
                 file.path("data/raw", glue::glue("Input_SAP_v{new_version}.csv")) 
               else get_latest_input_path("Input_SAP")
  )
  
  # Ähnlich für neue Version
  all_inputs_new <- load_all_inputs(
    hochrechnung_path = if (input_name == "Input_Hochrechnung") 
                          file.path("data/raw", glue::glue("Input_Hochrechnung_v{new_version}.csv")) 
                        else get_latest_input_path("Input_Hochrechnung"),
    rabatt_path = if (input_name == "Input_Rabatt") 
                    file.path("data/raw", glue::glue("Input_Rabatt_v{new_version}.csv")) 
                  else get_latest_input_path("Input_Rabatt"),
    betriebskosten_path = if (input_name == "Input_Betriebskosten") 
                            file.path("data/raw", glue::glue("Input_Betriebskosten_v{new_version}.csv")) 
                          else get_latest_input_path("Input_Betriebskosten"),
    sap_path = if (input_name == "Input_SAP") 
                 file.path("data/raw", glue::glue("Input_SAP_v{new_version}.csv")) 
               else get_latest_input_path("Input_SAP")
  )
  
  # Berechne KPIs für beide
  kpi_old <- calculate_budget(all_inputs_old)
  kpi_new <- calculate_budget(all_inputs_new)
  
  # Vergleiche KPIs
  comparison <- dplyr::full_join(
    kpi_old |> dplyr::rename_with(~paste0(., "_old"), -product_id),
    kpi_new |> dplyr::rename_with(~paste0(., "_new"), -product_id),
    by = "product_id"
  ) |>
    dplyr::select(product_id, 
                  contains("SQ"), contains("CR"), 
                  contains("nvp"), contains("bvp"))
  
  comparison
}

# Generiere Audit-Trail: Alle Input-Versionen chronologisch
get_audit_trail <- function() {
  trail <- data.frame(
    Input_Name = character(),
    Version = character(),
    File_Name = character(),
    File_Size_KB = numeric(),
    Modified_Time = as.POSIXct(character()),
    stringsAsFactors = FALSE
  )
  
  input_types <- c("Input_Hochrechnung", "Input_Rabatt", "Input_Betriebskosten", "Input_SAP")
  
  for (input_name in input_types) {
    versions <- get_all_versions(input_name)
    
    for (version in versions) {
      file_name <- glue::glue("{input_name}_v{version}.csv")
      file_path <- file.path("data/raw", file_name)
      
      if (file.exists(file_path)) {
        info <- file.info(file_path)
        
        trail <- rbind(trail, data.frame(
          Input_Name = input_name,
          Version = version,
          File_Name = file_name,
          File_Size_KB = round(info$size / 1024, 2),
          Modified_Time = info$mtime
        ))
      }
    }
  }
  
  # Sortiere nach Zeit (neueste zuerst)
  trail <- trail |>
    dplyr::arrange(dplyr::desc(Modified_Time))
  
  trail
}

# Extrahiere Validierungsfehler/Warnungen und strukturiere sie für UI
format_validation_errors <- function(validation_result) {
  # Konvertiere Validierungsergebnis in lesbare Format
  
  if (validation_result$success) {
    return(list(
      success = TRUE,
      errors = NULL,
      warnings = NULL,
      summary = "✅ Alle Validierungen erfolgreich"
    ))
  }
  
  # Parse Fehler
  errors <- validation_result$errors |>
    stringr::str_split("\n") |>
    unlist() |>
    purrr::discard(~. == "")
  
  warnings <- validation_result$warnings |>
    stringr::str_split("\n") |>
    unlist() |>
    purrr::discard(~. == "")
  
  list(
    success = FALSE,
    errors = errors,
    warnings = warnings,
    summary = glue::glue(
      "❌ {length(errors)} Fehler, ⚠️ {length(warnings)} Warnungen"
    )
  )
}
