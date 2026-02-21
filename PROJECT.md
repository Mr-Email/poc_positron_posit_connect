# PROJECT.md - Budget & Hochrechnung Automation PoC

## Projektziel
**Automatisierte Budget-Pipeline mit intelligenter Validierung und Versionsverwaltung**

Vereinfachung von Hochrechnungs- und Budget-Prozessen durch:
- ✅ Validierte Datenverarbeitung (pointblanc)
- ✅ Reproduzierbare Berechnungen (Formelwerk implementiert)
- 🔄 **NEW**: Intelligente targets-Pipeline mit selektivem Caching
- 🎨 **NEW**: Interaktives Shiny-Dashboard mit Versions-Vergleich

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

### ✅ Phase 2: targets-Pipeline (IN ARBEIT)
- [x] `_targets.R` – DAG-Definition implementiert
  - [x] `get_latest_input_path()` implementiert
  - [x] File-basierte Targets für alle 4 Inputs
  - [x] `inputs_combined` Target
  - [x] `validated_inputs` Target mit Warning-Handling
  - [x] `berechnung` Target
  - [x] `output_file` Target
- [x] Integration mit bestehenden R-Funktionen getestet
- [ ] Partial-Update Szenario: Validierung ausstehend
- [ ] targets-DAG Fehlerbehandlung optimieren
- [ ] Alle Test-Szenarien erfolgreich durchlaufen

**Status**: 🔄 **IN ARBEIT – Tests teils erfolgreich, Optimierungen notwendig**

**Test-Ergebnisse**:
```
# Aktuelle Test-Ergebnisse (Partial Update)

1. ✅ tar_make() mit v1 aller Inputs → Alle Targets berechnet
2. ✅ Input_Rabatt_v002.csv hinzufügen
3. ✅ tar_make() → Nur rabatt* Targets invalidiert, andere gecacht
4. ⚠️ Validierung bei Partial Update: Warnung statt Fehler
5. ❌ Berechnung bei fehlendem SAP_v002: Mismatch in Datenstruktur
```

**Nächste Schritte**:
- Validierungslogik für Partial Updates verfeinern
- SAP-Daten Handling bei unterschiedlichen Versionen testen
- Fehlerbehandlung in Combined Inputs robuster machen

---

### 🎨 Phase 3: Shiny Dashboard (AKTUELL)
- [x] `app.R` – Main Shiny Application
- [x] `R/shiny_helpers.R` – Helper-Funktionen
- [x] Dashboard Tab: KPI-Übersicht & Visualisierungen
- [x] Upload Tab: Neue Inputdateien hochladen
- [x] Pipeline Control: tar_make() Trigger
- [ ] **Versions-Vergleich Tab**: Alt vs. Neu Vergleiche
- [ ] **Audit-Trail Tab**: Änderungs-Historie anzeigen
- [ ] **Validierungs-Details Tab**: pointblanc-Fehler visualisieren
- [ ] Export: Vergleichsberichte (PDF/HTML)

**Features zur Implementierung**:

1. **Versions-Historie**
   - Zeige alle verfügbaren Input-Versionen in Dropdown
   - Verlade alte CSV-Versionen aus `data/raw/`
   - Berechne KPIs für beide Versionen (alt & neu)
   - Side-by-Side Vergleich mit Differenzen farblich markiert

2. **Unterschieds-Visualisierung**
   - Tabelle mit alten & neuen Werten
   - Spalten-weise Differenzen (Betrag & Prozent)
   - Highlight der wichtigsten Änderungen (SQ, CR)
   - Tooltip mit Erklärung der Änderungen

3. **Audit-Trail**
   - Chronologische Liste aller Input-Versionen
   - Timestamps & Dateigrößen
   - Wer hat die Datei hochgeladen (optional, wenn User-Track vorhanden)
   - Download-Links zu alten Outputs

4. **Validierungs-Details** (mit pointblanc)
   - Zeige alle Validierungsprüfungen an
   - ✅ Bestandene Regeln grün
   - ❌ Fehlgeschlagene Regeln rot mit Begründung
   - ⚠️ Warnungen gelb
   - Details pro Product-ID bei Fehler

**Notiz zu pointblanc**: 
- pointblanc wird **NICHT** für Visualisierung verwendet
- pointblanc ist für **Daten-Validierung** (Regelprüfung)
- Visualisierung nutzt: ggplot2, plotly, reactable (für Tabellen)
- Validierungsergebnisse werden dann visualisiert (als Text/Farben/Icons)

---

### 🎯 Phase 4: Polish & Demo (AUSSTEHEND)
- [ ] README schreiben (für Stakeholder)
- [ ] Mock-Fehlerfall testen (z.B. Rabatt > 100%)
- [ ] targets-DAG Screenshot für Pitch
- [ ] Final Test: Full Workflow v1 → v2
- [ ] Shiny-Performance bei großen Datenmengen testen
- [ ] Error-Handling für fehlende alte Versionen

---

## Validierungsregeln (pointblanc)

### Data Quality
- ✅ Pflicht-Spalten vorhanden
- ✅ Datentypen korrekt
- ✅ Keine NAs in Pflicht-Spalten
- ✅ Keine Duplikate bei product_id
- ✅ Alle 5 Produkte vorhanden

### Business Rules
- ✅ `bestand > 0`
- ✅ `bvp > 0`
- ✅ `fam_rab + mj_rab < 100` (Rabatte < 100%)
- ✅ `sm` zwischen 0.5 und 1.5
- ✅ `bk >= 0`

---

## Testing-Strategie

### ⚠️ Test-Ordner: Read-Only für Pipeline

**Wichtig**: Der `test/`-Ordner wird von Pipeline-Änderungen NICHT beeinflusst:
- ✅ Tests laufen unabhängig von `_targets.R`
- ✅ Input-Versionierung triggert KEINE Test-Updates
- ✅ `tar_make()` verändert niemals Dateien in `test/`
- ✅ Test-Fehler stoppen Pipeline NICHT (separate CI/CD)

**Konsequenz**: Wenn Tests aktualisiert werden müssen → Manuell im `test/`-Ordner bearbeiten, nicht automatisiert.

### Unit Tests (testthat)
- `test/test_01_load_data.R` – CSV-Laden
- `test/test_02_validate_data.R` – Validierungsregeln
- `test/test_03_calculate.R` – Formelwerk
- `test/test_workflow.R` – Load → Validate → Calculate

### Integration Tests
- `test/test_pipeline_1.R` – targets-Caching & Partial Updates
- Laufen separat: `source("test/test_pipeline_1.R")`
- Nicht Teil von `tar_make()`

---

## Status

🔄 **Phase 1 ✅ → Phase 2 IN ARBEIT**: targets-Pipeline mit intelligentem Caching wird optimiert

---

## Glossar

- **Versionierung**: `Input_<Name>_v<NN>.csv` (z.B. v001, v002, v003)
- **Caching**: targets speichert Rechenergebnisse; nur geänderte Inputs triggern Neuberechnung
- **Partial Update**: Nur ein oder mehrere (nicht alle) Inputdateien sind neu
- **DAG**: Directed Acyclic Graph (targets zeigt Abhängigkeiten)
- **pointblanc**: R-Package für Datenvalidation mit Custom Rules