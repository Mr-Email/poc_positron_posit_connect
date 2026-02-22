# ============================================================================
# DUMMY DATA CONFIG: Parameter für Test-Datengenerierung
# ============================================================================
# Wird NICHT von _targets.R geladen!
# Wird nur von R/00_generate_dummy_data.R geladen!

# ============================================================================
# Parameterbereich für Dummy-Datengenerierung
# ============================================================================

# Hochrechnung
BESTAND_MIN <- 50000
BESTAND_MAX <- 500000

# Betrag pro Versicherte
BVP_MIN <- 150
BVP_MAX <- 300

# Rabatten
MJ_RAB_RANGE <- c(1, 5)     # Mehrjährig-Rabatt %
FAM_RAB_RANGE <- c(5, 10)   # Familienrabatt %
RAB_TOTAL_MAX <- 100        # Max. Gesamtrabatt

# Betriebskosten Parameter
SM_MIN <- 0.5
SM_MAX <- 1.5
BK_MIN <- 5

# SAP Daten
ADVO_RANGE <- c(0, 5)
PD_RANGE <- c(0, 5)
SAP_RANGE <- c(0, 5)
