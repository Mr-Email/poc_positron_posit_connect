# PROJECT.md - Budget & Hochrechnung Automation PoC

## Projektziel
**Automatisierte Budget-Pipeline mit intelligenter Validierung und Versionsverwaltung**

Vereinfachung von Hochrechnungs- und Budget-Prozessen durch:
- ✅ Validierte Datenverarbeitung (pointblank)
- ✅ Reproduzierbare Berechnungen (Formelwerk implementiert)
- ✅ Intelligente targets-Pipeline mit selektivem Caching
- ✅ Interaktives Shiny-Dashboard mit Versions-Vergleich & Reports

---

## Datenmodell

### Produkte (Join-Key)
**Ambulant**: `Amb_T`, `Amb_S`, `Amb_C`  
**Stationär**: `Hosp_P`, `Hosp_HP`

### Input-Dateien (mit Versionierung)
Alle Inputdateien nutzen Namenskonvention: `Input_<Name>_v<NN>.csv`

| Datei | Spalten | Beschreibung |
|-------|---------|-------------|
| `Input_Hochrechnung_v*.csv` | `product_id`, `bestand`, `bvp`, `nvl` | Ist-Bestand, Betrag pro Versicherte & Schadenwert |
| `Input_Rabatt_v*.csv` | `product_id`, `fam_rab`, `mj_rab` | Familienrabatt & Mehrjährig-Rabatt (%) |
| `Input_Betriebskosten_v*.csv` | `product_id`, `sm`, `bk` | Saison-Multiplikator & Betriebskosten |
| `Input_SAP_v*.csv` | `product_id`, `advo`, `pd`, `sap` | Ist-Daten (Advocacy, Pd, SAP-Betrag) |

### Formelwerk
```
nvp = bvp - (fam_rab + mj_rab)           # Netto-Versicherungsprämie
SQ = nvl / nvp                            # Schadenquote (Ziel: 60-80%)
vp = nvp - advo - pd                      # Verdiente Prämie
va = nvl + sap + sm                       # Versicherungs-Aufwand
CR = (va + bk) / vp                       # Combined Ratio (Ziel: 85-105%)
```

---

## Workflow & Versioning

### Standard-Flow mit targets-Pipeline

1. **Input Generation** (manuell)
   - Neue CSV-Dateien werden in `data/raw/` abgelegt
   - Versionierungskonvention: `Input_<Name>_v<NN>.csv`
   - Beispiel: `Input_Rabatt_v001.csv`, `Input_Rabatt_v002.csv`

2. **Automatische Pipeline-Trigger** (targets)
   ```
   tar_make()  # Erkennt Dateiänderungen, berechnet nur notwendiges neu
   ```
   
3. **Intelligentes Caching**
   - targets vergleicht Timestamps der Input-Dateien mit letztem Report
   - **Nur geänderte Inputs** triggern Neuberechnung
   - Unveränderte Inputs werden aus Cache wiederverwendet
   - Beispiel: Wenn nur `Input_Rabatt_v002.csv` neu ist, aber Hochrechnung, Betriebskosten und SAP gleichbleiben → nur Rabatt wird neu geladen

4. **Validierung & Berechnung**
   - Alle geladenen Inputs durchlaufen pointblanc-Validierung
   - Bei Fehler: Pipeline stoppt mit aussagekräftiger Fehlermeldung
   - Bei OK: Formelwerk berechnet KPIs (nvp, SQ, vp, va, CR)

5. **Output Generation**
   - Quarto-Report wird generiert: `output/report_<timestamp>.html`
   - Rohdaten exportiert: `output/results_<timestamp>.csv`
   - Metadaten gespeichert: `output/.metadata.json` (Input-Versionen, Timestamps)

---

## Architektur & Tech-Stack

### PoC (GitHub)
```
poc_positron_posit_connect/
├── R/
│   ├── 00_config.R              # Konstanten & Konfiguration
│   ├── 01_load_data.R           # CSV-Laden mit Error-Handling ✅
│   ├── 02_validate_data.R       # pointblanc-Regeln ✅
│   ├── 03_calculate.R           # Formelwerk ✅
│   └── 04_reporting.R           # (Optional) Report-Hilfsfunktionen
├── _targets.R                   # 🔄 targets-Pipeline (TODO)
├── report.qmd                   # Quarto-Report (TODO)
├── app.R                        # (Optional) Shiny-Dashboard
├── data/raw/                    # Input-CSVs mit Versionierung
├── output/                      # Generierte Reports & Daten
└── test/                        # 🔒 ISOLIERT: Unit & Integration Tests
                                 # (Nicht Teil der Pipeline-Änderungen)
```

### Tech-Stack
- **Datenvalidation**: pointblanc (Custom Business Rules)
- **Workflow-Orchestrierung**: `targets` (DAG + intelligentes Caching)
- **Output-Format**: Quarto (.qmd → HTML Report)
- **Testing**: testthat
- **Versionskontrolle**: Git (mit semantischen Commit Messages)

---

## 🔄 targets-Pipeline Challenge

### Kernaufgabe: Intelligentes Caching mit Partial Updates

**Problem**: 
Die Pipeline hat 4 Input-Dateien mit  unterschiedlichen Versionen. Nicht alle müssen gleichzeitig aktualisiert werden.
Beispiel:
- `Input_Hochrechnung_v001.csv` (aktuell)
- `Input_Rabatt_v002.csv` (neu!) ← Geändert
- `Input_Betriebskosten_v001.csv` (aktuell)
- `Input_SAP_v001.csv` (aktuell)

**Challenge**: 
Nur `Input_Rabatt_v002.csv` sollte neu geladen werden. Die anderen 3 Inputs können aus dem targets-Cache wiederverwendet werden.

### Lösung: Datei-basierte Targets mit Timestamps

**Architektur**:
```r
# _targets.R Struktur

tar_target(hochrechnung_path, {
  # Finde neueste v* Version in data/raw/
  get_latest_input_path("Input_Hochrechnung")
})

tar_target(hochrechnung, {
  # Lädt nur neu, wenn hochrechnung_path sich geändert hat
  load_csv(hochrechnung_path)
})

tar_target(rabatt_path, get_latest_input_path("Input_Rabatt"))
tar_target(rabatt, load_csv(rabatt_path))

# ... ähnlich für betriebskosten und sap

tar_target(inputs_combined, {
  # Kombiniert alle Input-Daten (wird nur neu berechnet wenn mind. ein Input neu ist)
  list(
    hochrechnung = hochrechnung,
    rabatt = rabatt,
    betriebskosten = betriebskosten,
    sap = sap
  )
})

tar_target(validated_inputs, {
  # Validierung greift nur auf geänderte Inputs
  result <- validate_all_inputs(inputs_combined)
  if (!result$success) stop(result$errors)
  inputs_combined
})

tar_target(results, {
  # Berechnung - nur wenn Validierung OK
  calculate_budget(validated_inputs)
})

tar_target(report, {
  # Quarto-Report mit Timestamp
  quarto::quarto_render("report.qmd", ...)
})
```

### Implementierungsdetails

**1. Helper-Funktion: `get_latest_input_path()`**
```r
# In R/00_config.R
get_latest_input_path <- function(input_name) {
  # Beispiel input_name = "Input_Rabatt"
  # Sucht: data/raw/Input_Rabatt_v*.csv
  # Gibt zurück: Pfad zur Version mit höchster vNN
  
  pattern <- glue::glue("^{input_name}_v\\d+\\.csv$")
  files <- list.files("data/raw", pattern = pattern, full.names = TRUE)
  
  if (length(files) == 0) stop(glue::glue("Keine {input_name} Dateien gefunden"))
  
  # Extrahiere Versionsnummer und sortiere
  versions <- str_extract(files, "\\d+") |> as.numeric()
  files[which.max(versions)]
}
```

**2. Dependency-Tracking**
- `tar_target(hochrechnung_path, ...)` → targets überwacht Dateisystem
- Wenn `data/raw/Input_Hochrechnung_v002.csv` hinzukommt → `hochrechnung_path` invalidiert
- `tar_target(hochrechnung, ...)` wird neu berechnet
- `tar_target(rabatt, ...)` bleibt cached (Datei unverändert)

**3. Fehlerbehandlung in der Pipeline**
```r
tar_target(validated_inputs, {
  result <- validate_all_inputs(inputs_combined)
  if (!result$success) {
    # targets stoppt Pipeline mit Fehler
    stop(glue::glue(
      "Validierung fehlgeschlagen:\n{paste(result$errors, collapse = '\n')}"
    ))
  }
  inputs_combined
})
```

---

## Meilensteine

### ✅ Phase 1: Core-Funktionen (FERTIG)
- [x] `R/00_config.R` – Konstanten & Validierungsregeln
- [x] `R/01_load_data.R` – CSV-Laden mit Error-Handling
- [x] `R/02_validate_data.R` – pointblanc-Validierung
- [x] `R/03_calculate.R` – Formelwerk-Implementierung
- [x] Dummy-Daten (v1 & v2) generiert

**Status**: ✅ Alle Funktionen sind produktionsreif

---

### ✅ Phase 2: targets-Pipeline (ABGESCHLOSSEN)
- [x] `_targets.R` – DAG-Definition mit versioniertem Output
  - [x] `get_latest_input_path()` implementiert & getestet
  - [x] `get_next_output_version()` für `bu_v*.csv` Versionierung
  - [x] File-basierte Targets für alle 4 Inputs
  - [x] `inputs_combined` Target
  - [x] `validated_inputs` Target mit Error-Handling
  - [x] `berechnung` Target
  - [x] `output_file` Target (versioniert: `bu_v001.csv`, `bu_v002.csv`, ...)
- [x] Integration mit bestehenden R-Funktionen getestet ✅
- [x] Validierungsfunktion erweitert um **manuelle Business-Rule Checks**
- [x] Alle Test-Szenarien erfolgreich durchlaufen ✅

**Status**: ✅ **ABGESCHLOSSEN – Alle Tests bestanden (5/5)**

**Test-Ergebnisse** (aktuell):
```
Step 1: Load data              ✅ 4 Dateien geladen
Step 2: Valid data             ✅ Alle Checks bestanden
Step 3: Negative values        ✅ Korrekt erkannt
Step 4: Rabatt > 100%          ✅ Korrekt erkannt
Step 5: Export report          ✅ validation_report_XXXXXX.html

📊 RESULTS: 5/5 Tests bestanden ✅
```

**Wichtige Änderungen**:
- Validierungsfunktion nutzt jetzt **kombinierte Strategie**:
  - Manuelle Checks für kritische Business Rules (Negativwerte, Rabatt > 100%)
  - pointblank für Struktur- und Typ-Validierung
  - Aussagekräftige Error-Messages mit betroffenen Zeilen
- Output-Versionierung: `bu_v001.csv`, `bu_v002.csv`, etc. (statt Timestamps)
- Pipeline-Logging in `output/pipeline_XXXXXX.log`

---

### 🎨 Phase 3: Shiny Dashboard (AKTIV)
- [x] `app.R` – Main Shiny Application mit 4 Tabs
  - [x] Dashboard Tab: Aktuelle Berechnung anzeigen
  - [x] Änderungen Tab: Zwei Versionen vergleichen mit fancy ggplot2 Grafik
  - [x] Datenvalidierung Tab: pointblank Reports anzeigen
  - [x] Report Tab: Basis-Vergleich mit HTML-Anzeige & Download
- [x] Theme-Auswahl: Flatly Design (kosmetisch)
- [x] Log-Datei Anzeige: Pipeline-Logs im UI
- [x] Validierungs-Reports: pointblank HTML-Export in Shiny
- [x] Report-Generierung: HTML anzeigen, optional als Download

**Features implementiert**:
1. **Dashboard** – Neueste Berechnung mit Tabellen
2. **Änderungen** – Side-by-Side Vergleich mit Grafiken
   - ggplot2 Balkendiagramm (grün/rot für Verbesserung/Verschlechterung)
   - Metriken: SQ & CR Änderungen in %
3. **Datenvalidierung**
   - Validiere-jetzt Button → Generiert pointblank Reports
   - Reports werden in HTML angezeigt
   - Log-Dateien-Browser
4. **Report**
   - Basis-Version auswählen
   - Aktuelle Version auswählen
   - HTML Report generieren & anzeigen
   - Optional: PDF Download (benötigt TinyTeX)

**Status**: ✅ **AKTIV – Core Features funktionieren, Polish läuft**

---

## Validierungsregeln (pointblank + manuell)

### Manuelle Business Rules (strikte Checks)
- ✅ `bestand >= 0` (Negative Werte werden erkannt & gemeldet)
- ✅ `bvp >= 0`
- ✅ `fam_rab + mj_rab <= 100%` (Rabatte > 100% werden erkannt)
- ✅ Error-Messages zeigen betroffene Zeilen-Nummern

### pointblank Data Quality
- ✅ Pflicht-Spalten vorhanden
- ✅ Datentypen korrekt
- ✅ Keine Duplikate bei product_id
- ✅ HTML-Reports für Visualisierung

---

## Testing-Strategie (AKTUELL)

### ✅ Unit Tests: test_validation.R (5/5 BESTANDEN)

```
Test 1: Load data ...................... ✅
Test 2: Valid data ..................... ✅
Test 3: Negative values detected ....... ✅
Test 4: Rabatt > 100% detected ......... ✅
Test 5: Export report ................. ✅

📊 OVERALL: 5/5 Tests erfolgreich
```

**Test-Details**:
- Test 1: CSV-Import für 4 Input-Dateien
- Test 2: Validierung mit korrekten Daten
- Test 3: **Negative Werte in Bestand → Fehler erkannt** ✅
- Test 4: **Rabatt > 100% → Fehler erkannt** ✅
- Test 5: pointblank Report Export als HTML

### Integration Tests
- `test/test_pipeline_1.R` – targets-Caching & Partial Updates
- Laufen separat: `source("test/test_validation.R")`
- Nicht Teil von `tar_make()`

---

## Status

🟢 **Phase 1 ✅ → Phase 2 ✅ → Phase 3 🔄**: 
- Validierung & Berechnung: **PRODUKTIONSREIF**
- Shiny Dashboard: **FUNKTIONSFÄHIG**
- Tests: **5/5 BESTANDEN**

---

## Glossar

- **Versionierung**: 
  - Inputs: `Input_<Name>_v<NN>.csv`
  - Outputs: `bu_v<NN>.csv`
- **Business Rules**: Manuelle Checks (negative Werte, Rabatte > 100%)
- **pointblank**: R-Package für Struktur-Validierung & Reporting
- **DAG**: Directed Acyclic Graph (targets zeigt Abhängigkeiten)

---

## Quick Start

### 1. Test-Validierung
```r
source("test/test_validation.R")
# Output: 📊 RESULTS: 5/5 Tests bestanden ✅
```

### 2. Pipeline starten
```r
targets::tar_make()
# Generiert: bu_v001.csv, bu_v002.csv, ...
```

### 3. Shiny Dashboard starten
```r
shiny::runApp("app.R")
# Öffnet: http://127.0.0.1:6113
```

### 4. Reports anzeigen
- Im Dashboard: "Datenvalidierung" Tab → "Validiere jetzt"
- Im Dashboard: "Report" Tab → Basis wählen → "HTML Report anzeigen"

---

✅ **PoC PRODUKTIONSREIF** – Alle Kern-Funktionen getestet & dokumentiert