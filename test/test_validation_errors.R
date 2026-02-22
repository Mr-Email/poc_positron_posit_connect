source("R/02_validate_data.R")
source("R/00_config.R")

cat("\n🧪 TEST: Validierung mit Fehler-Szenarien\n\n")

# ========== SZENARIO 1: NEGATIVE BESTANDSWERTE ==========
cat("Szenario 1: Negative Bestandswerte\n")

hochrechnung_neg <- data.frame(
  product_id = c("Amb_T", "Amb_S", "Amb_C", "Hosp_P", "Hosp_HP"),
  bestand = c(-50000, 100000, 120000, 80000, 90000),  # ← NEGATIV!
  bvp = c(200, 210, 220, 250, 260),
  nvl = c(50000, 55000, 60000, 65000, 70000)
)

rabatt <- data.frame(
  product_id = c("Amb_T", "Amb_S", "Amb_C", "Hosp_P", "Hosp_HP"),
  fam_rab = c(5, 5, 5, 7, 7),
  mj_rab = c(2, 2, 2, 3, 3)
)

betriebskosten <- data.frame(
  product_id = c("Amb_T", "Amb_S", "Amb_C", "Hosp_P", "Hosp_HP"),
  sm = c(1.0, 0.95, 1.05, 1.1, 0.9),
  bk = c(10, 12, 11, 15, 14)
)

sap <- data.frame(
  product_id = c("Amb_T", "Amb_S", "Amb_C", "Hosp_P", "Hosp_HP"),
  advo = c(20, 22, 21, 25, 24),
  pd = c(10, 12, 11, 15, 14),
  sap = c(100, 110, 105, 120, 115)
)

val <- validate_all_inputs(list(
  hochrechnung = hochrechnung_neg,
  rabatt = rabatt,
  betriebskosten = betriebskosten,
  sap = sap
))

cat(glue::glue("Ergebnis: {ifelse(val$success, '✅ BESTANDEN', '❌ FEHLER')}\n"))
if (!val$success) {
  for (err in val$errors) {
    cat(glue::glue("  - {err}\n"))
  }
}

# ========== SZENARIO 2: RABATT > 100% ==========
cat("\nSzenario 2: Rabatt > 100%\n")

rabatt_over <- data.frame(
  product_id = c("Amb_T", "Amb_S", "Amb_C", "Hosp_P", "Hosp_HP"),
  fam_rab = c(60, 5, 5, 7, 7),  # ← 60% > 100% kombiniert!
  mj_rab = c(50, 2, 2, 3, 3)    # ← 50% = 110% total!
)

val <- validate_all_inputs(list(
  hochrechnung = hochrechnung_neg,
  rabatt = rabatt_over,
  betriebskosten = betriebskosten,
  sap = sap
))

cat(glue::glue("Ergebnis: {ifelse(val$success, '✅ BESTANDEN', '❌ FEHLER')}\n"))
if (!val$success) {
  for (err in val$errors) {
    cat(glue::glue("  - {err}\n"))
  }
}

# ========== SZENARIO 3: NEGATIVE BVP ==========
cat("\nSzenario 3: Negative BVP\n")

hochrechnung_bvp <- hochrechnung_neg
hochrechnung_bvp$bvp[2] <- -100  # ← NEGATIV!

val <- validate_all_inputs(list(
  hochrechnung = hochrechnung_bvp,
  rabatt = rabatt,
  betriebskosten = betriebskosten,
  sap = sap
))

cat(glue::glue("Ergebnis: {ifelse(val$success, '✅ BESTANDEN', '❌ FEHLER')}\n"))
if (!val$success) {
  for (err in val$errors) {
    cat(glue::glue("  - {err}\n"))
  }
}

cat("\n✅ Test-Szenarien abgeschlossen\n\n")
