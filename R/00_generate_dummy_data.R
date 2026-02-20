# Generiere Dummy-Daten für Budget & Hochrechnung PoC
# Rückwärts-Berechnung: CR & SQ Ziele → Input-Parameter
# 2 Versionen (v1, v2) für Caching-Demo in targets

library(dplyr)
library(readr)

products <- c("Amb_T", "Amb_S", "Amb_C", "Hosp_P", "Hosp_HP")

# ============================================================================
# LEITPLANKEN (Business Rules)
# ============================================================================

BESTAND_MIN <- 50000
BESTAND_MAX <- 300000
BVP_MIN <- 150
BVP_MAX <- 300
FAM_RAB_RANGE <- c(5, 10)
MJ_RAB_RANGE <- c(1, 5)
RAB_TOTAL_MAX <- 100
SM_MIN <- 0.5
SM_MAX <- 1.5
BK_MIN <- 5
ADVO_RANGE <- c(0, 5)
PD_RANGE <- c(0, 5)
SAP_RANGE <- c(0, 5)

# ============================================================================
# BESTIMME NÄCHSTE VERSIONSNUMMER
# ============================================================================

dir.create("data/raw", recursive = TRUE, showWarnings = FALSE)

get_next_version <- function(pattern) {
  files <- list.files("data/raw", pattern = pattern)
  if (length(files) == 0) return(1)
  versions <- as.numeric(gsub(".*v(\\d{3})\\.csv", "\\1", files))
  max(versions) + 1
}

v_hochrechnung <- get_next_version("^Input_Hochrechnung_v\\d{3}\\.csv$")
v_rabatt <- get_next_version("^Input_Rabatt_v\\d{3}\\.csv$")
v_betriebskosten <- get_next_version("^Input_Betriebskosten_v\\d{3}\\.csv$")
v_sap <- get_next_version("^Input_SAP_v\\d{3}\\.csv$")

# ============================================================================
# GENERIERE NEUE VERSIONEN
# ============================================================================

set.seed(v_hochrechnung)
hochrechnung <- tibble(
  product_id = products,
  bestand = runif(5, 50000, 300000) |> round(0),
  bvp = runif(5, 150, 300) |> round(0),
  nvl = runif(5, 50, 200) |> round(2)
)
write_csv(hochrechnung, glue::glue("data/raw/Input_Hochrechnung_v{sprintf('%03d', v_hochrechnung)}.csv"))

set.seed(v_rabatt)
rabatt <- tibble(
  product_id = products,
  fam_rab = runif(5, 5, 10) |> round(1),
  mj_rab = runif(5, 1, 5) |> round(1)
) |>
  mutate(
    total_rab = fam_rab + mj_rab,
    fam_rab = if_else(total_rab > 95, 5, fam_rab)
  ) |>
  select(-total_rab)
write_csv(rabatt, glue::glue("data/raw/Input_Rabatt_v{sprintf('%03d', v_rabatt)}.csv"))

set.seed(v_betriebskosten)
betriebskosten <- tibble(
  product_id = products,
  sm = runif(5, 0.5, 1.5) |> round(2),
  bk = runif(5, 5, 30) |> round(1)
)
write_csv(betriebskosten, glue::glue("data/raw/Input_Betriebskosten_v{sprintf('%03d', v_betriebskosten)}.csv"))

set.seed(v_sap)
sap <- tibble(
  product_id = products,
  advo = runif(5, 0, 5) |> round(1),
  pd = runif(5, 0, 5) |> round(1),
  sap = runif(5, 0, 5) |> round(1)
)
write_csv(sap, glue::glue("data/raw/Input_SAP_v{sprintf('%03d', v_sap)}.csv"))

cat(glue::glue("✅ Neue Versionen generiert:\n"))
cat(glue::glue("   Hochrechnung: v{sprintf('%03d', v_hochrechnung)}\n"))
cat(glue::glue("   Rabatt: v{sprintf('%03d', v_rabatt)}\n"))
cat(glue::glue("   Betriebskosten: v{sprintf('%03d', v_betriebskosten)}\n"))
cat(glue::glue("   SAP: v{sprintf('%03d', v_sap)}\n"))
