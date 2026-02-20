# ============================================================================
# GLOBALE KONFIGURATION
# ============================================================================

# Erwartete Produkte
VALID_PRODUCTS <- c("Amb_T", "Amb_S", "Amb_C", "Hosp_P", "Hosp_HP")

# Input-Datei Definitionen
INPUT_FILES <- list(
  hochrechnung = list(
    name = "Input_Hochrechnung",
    columns = c("product_id", "bestand", "bvp", "nvl"),
    types = c(
      product_id = "c",  # character
      bestand = "d",     # double
      bvp = "d",
      nvl = "d"
    ),
    description = "Ist-Bestand, Betrag pro Versicherte & Schadenwert"
  ),
  
  rabatt = list(
    name = "Input_Rabatt",
    columns = c("product_id", "fam_rab", "mj_rab"),
    types = c(
      product_id = "c",
      fam_rab = "d",
      mj_rab = "d"
    ),
    description = "Familienrabatt & Mehrjährig-Rabatt (%)"
  ),
  
  betriebskosten = list(
    name = "Input_Betriebskosten",
    columns = c("product_id", "sm", "bk"),
    types = c(
      product_id = "c",
      sm = "d",
      bk = "d"
    ),
    description = "Saison-Multiplikator & Betriebskosten"
  ),
  
  sap = list(
    name = "Input_SAP",
    columns = c("product_id", "advo", "pd", "sap"),
    types = c(
      product_id = "c",
      advo = "d",
      pd = "d",
      sap = "d"
    ),
    description = "Ist-Daten (Advocacy, Pd, SAP-Betrag)"
  )
)

# Business Rules für Validierung
BUSINESS_RULES <- list(
  hochrechnung = list(
    bestand = list(rule = "> 0", description = "Bestand muss > 0 sein"),
    bvp = list(rule = "> 0", description = "BVP muss > 0 sein"),
    nvl = list(rule = "> 0", description = "NVL muss > 0 sein")
  ),
  
  rabatt = list(
    fam_rab = list(
      rule = ">= 0 & < 100",
      description = "Familienrabatt muss zwischen 0-100% sein"
    ),
    mj_rab = list(
      rule = ">= 0 & < 100",
      description = "Mehrjährig-Rabatt muss zwischen 0-100% sein"
    ),
    sum_rab = list(
      rule = "fam_rab + mj_rab < 100",
      description = "Summe Rabatten muss < 100% sein"
    )
  ),
  
  betriebskosten = list(
    sm = list(
      rule = ">= 0.5 & <= 1.5",
      description = "Saison-Multiplikator muss zwischen 0.5-1.5 sein"
    ),
    bk = list(
      rule = ">= 0",
      description = "Betriebskosten dürfen nicht negativ sein"
    )
  ),
  
  sap = list(
    advo = list(rule = ">= 0", description = "Advocacy darf nicht negativ sein"),
    pd = list(rule = ">= 0", description = "Pd darf nicht negativ sein"),
    sap = list(rule = ">= 0", description = "SAP-Betrag darf nicht negativ sein")
  )
)

# Zielbereich für KPIs
KPI_TARGETS <- list(
  sq = list(min = 0.60, max = 0.80, description = "Schadenquote 60-80%"),
  cr = list(min = 0.85, max = 1.05, description = "Combined Ratio 85-105%")
)

# Datenverzeichnis
DATA_DIR <- "data/raw"
OUTPUT_DIR <- "output"
