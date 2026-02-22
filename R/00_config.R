# ============================================================================
# CONFIG: Konstanten und Globale Einstellungen
# ============================================================================

# ============================================================================
# Verzeichnisse
# ============================================================================

DATA_DIR <- "data/raw"
OUTPUT_DIR <- "output"

# ============================================================================
# Produkte
# ============================================================================

VALID_PRODUCTS <- c("Amb_T", "Amb_S", "Amb_C", "Hosp_P", "Hosp_HP")

# ============================================================================
# Input-Dateien und deren Spaltendefinition
# ============================================================================

INPUT_FILES <- list(
  hochrechnung = list(
    name = "Input_Hochrechnung",
    columns = c("product_id", "bestand", "bvp", "nvl"),
    types = "cddd",
    description = "Ist-Bestand, Betrag pro Versicherte & Schadenwert"
  ),
  rabatt = list(
    name = "Input_Rabatt",
    columns = c("product_id", "fam_rab", "mj_rab"),
    types = "cdd",
    description = "Familienrabatt & Mehrjährig-Rabatt (%)"
  ),
  betriebskosten = list(
    name = "Input_Betriebskosten",
    columns = c("product_id", "sm", "bk"),
    types = "cdd",
    description = "Saison-Multiplikator & Betriebskosten"
  ),
  sap = list(
    name = "Input_SAP",
    columns = c("product_id", "advo", "pd", "sap"),
    types = "cddd",
    description = "Ist-Daten (Advocacy, Pd, SAP-Betrag)"
  )
)

# ============================================================================
# Geschäftsregeln für Validierung
# ============================================================================

BUSINESS_RULES <- list(
  hochrechnung = list(
    bestand = list(
      rule = "> 0",
      description = "Bestand muss > 0 sein"
    ),
    bvp = list(
      rule = "> 0",
      description = "BVP muss > 0 sein"
    ),
    nvl = list(
      rule = "> 0",
      description = "NVL (Schadenwert) muss > 0 sein"
    )
  ),
  rabatt = list(
    total = list(
      rule = "fam_rab + mj_rab < 100",
      description = "Rabatte können nicht > 100% sein"
    )
  ),
  betriebskosten = list(
    sm = list(
      rule = "0.5 <= sm <= 1.5",
      description = "Saison-Multiplikator muss zwischen 0.5 und 1.5 sein"
    ),
    bk = list(
      rule = ">= 0",
      description = "Betriebskosten dürfen nicht negativ sein"
    )
  )
)

# ============================================================================
# KPI-Zielwerte (optional, für Reports)
# ============================================================================

KPI_TARGETS <- list(
  sq = list(
    min = 0.6,
    max = 0.8,
    description = "Schadenquote 60-80%"
  ),
  cr = list(
    min = 0.85,
    max = 1.05,
    description = "Combined Ratio 85-105%"
  )
)

# ============================================================================
# FUNCTIONS - Nicht als globale Variablen definieren!
# ============================================================================

get_config <- function() {
  # Config für Dummy-Datengenerierung
  list(
    bestand_min = 50000,
    bestand_max = 500000,
    bvp_min = 150,
    bvp_max = 300,
    mj_rab_range = c(1, 5),
    fam_rab_range = c(5, 10),
    rab_total_max = 100,
    sm_min = 0.5,
    sm_max = 1.5,
    bk_min = 5,
    advo_range = c(0, 5),
    pd_range = c(0, 5),
    sap_range = c(0, 5)
  )
}

get_latest_version <- function(input_name) {
  pattern <- glue::glue("^{input_name}_v(\\d+)\\.csv$")
  files <- list.files(DATA_DIR, pattern = pattern)
  if (length(files) == 0) return(NA)
  versions <- stringr::str_extract(files, "\\d+") |> as.numeric()
  max(versions, na.rm = TRUE)
}

get_next_version <- function(pattern) {
  latest <- get_latest_version(pattern)
  if (is.na(latest)) 1 else latest + 1
}
