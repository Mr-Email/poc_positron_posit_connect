# PROJECT.md - Budget & Hochrechnung Automation PoC

## Projektziel
Pitch am Montag für Lösungsvorschlag zur Vereinfachung von Hochrechnungs- und Budget-Prozessen.
- **Problem**: Manueller Excel-Austausch, ineffizient, nicht nachvollziehbar
- **Lösung**: Automatisierte Pipeline (Shiny + targets) mit validierter Datenverarbeitung
- **MVP**: Funktionsfähige targets-Pipeline + Quarto-Report + (optional) Shiny-App

---

## Datenmodell

### Produkte (Join-Key für alle Inputs)
**Ambulant**: `Amb_T`, `Amb_S`, `Amb_C`  
**Stationär**: `Hosp_P`, `Hosp_HP`

### Input-Dateien (v1 = Standard)

| Datei | Spalten | Beschreibung |
|-------|---------|-------------|
| `Input_Hochrechnung.csv` | `product_id`, `bestand`, `bvp`, `nvl` | Ist-Bestand, Betrag pro Versicherte & Schadenwert |
| `Input_Rabatt.csv` | `product_id`, `fam_rab`, `mj_rab` | Familienrabatt & Mehrjährig-Rabatt (%) |
| `Input_Betriebskosten.csv` | `product_id`, `sm`, `bk` | Saison-Multiplikator & Betriebskosten |
| `Input_SAP.csv` | `product_id`, `advo`, `pd`, `sap` | Ist-Daten (Advocacy, Pd, SAP-Betrag) |

### Formelwerk

```
nvp = bvp - (fam_rab + mj_rab)           # Netto-Versicherungsprämie
SQ = nvl / nvp                            # Schadenquote (Ziel: 60-80%)
vp = nvp - advo - pd                      # Verdiente Prämie
va = nvl + sap + sm                       # Versicherungs-Aufwand
CR = (va + bk) / vp                       # Combined Ratio (Ziel: 85-105%)
```

---

## Workflow & Use-Case

### Standard-Flow
1. **v1 (Input)**: Stakeholder lädt 4 CSV-Dateien hoch
2. **Validierung**: pointblanc prüft Datenqualität
   - Wenn **Fehler**: Abbruch mit aussagekräftigen Fehlermeldungen
   - Wenn **OK**: Weiter zu Berechnung
3. **Berechnung**: targets-Pipeline berechnet nvp, SQ, vp, va, CR
4. **Output**: Quarto-Report mit:
   - Zusammenfassung (Tabelle mit allen KPIs pro Produkt)
   - Analysen (CR-Verteilung, SQ-Analyse, SAP-Vergleich)
   - Download-Link zu Rohdaten

### v2-Szenario (Demo)
- Stakeholder behebt Validierungsfehler → v2
- targets-Pipeline läuft erneut
- **Caching**: Unveränderte Inputs werden wiederverwendet

---

## Architektur & Tech-Stack

### PoC (aktuell, GitHub)
- **Versionskontrolle**: GitHub
- **Datenvalidation**: pointblanc (Custom Rules)
- **Workflow-Orchestrierung**: `targets` (DAG + Caching)
- **Output-Format**: Quarto (.qmd → HTML/PDF Report)
- **Testing**: testthat für Rechenfunktionen

### Finale Umsetzung (falls akzeptiert)
- Git: Azure DevOps
- Compute: Posit Workbench
- Deployment: Posit Connect (Automatische Report-Generierung)

---

## Meilensteine (4h Zeitbudget)

### Phase 1: Setup & Datenstruktur (30min) ✅
- [x] Ordnerstruktur erstellt
- [x] Dummy-Daten generiert (v1 + v2)
- [x] Formelwerk definiert

**Status**: Ready for Phase 2

---

### Phase 2a: Core-Funktionen (45min)
- [ ] `R/01_load_data.R` – CSV-Laden mit Error-Handling
- [ ] `R/02_validate_data.R` – pointblanc Validierungsregeln
- [ ] `R/03_calculate.R` – Formelwerk-Implementierung
- [ ] Unit Tests (testthat) für Berechnungen

**Output**: Validierte & berechnete Daten ready für Shiny + targets

---

### Phase 2b: Shiny-Upload-Interface (45min)
- [ ] `shiny_app/app.R` – File-Upload-Interface
  - Upload für 4 CSVs (Input_Hochrechnung, Input_Rabatt, Input_Betriebskosten, Input_SAP)
  - Live-Validierung beim Upload (grün/rot Feedback)
  - Fehler-Details anzeigen (welche Spalte/Zeile problematisch)
  - "Berechnung starten" Button (nur wenn alle valid)
- [ ] Validierungs-Feedback UI (pointblanc Errors anzeigen)
- [ ] Integration mit targets-Pipeline

**Output**: Shiny-App triggert targets bei gültigen Daten

---

### Phase 3: targets-Pipeline & Quarto-Report (60min)
- [ ] `_targets.R` (vereinfacht, Daten von Shiny)
  - `tar_target()` für Load → Validate → Calculate
  - Output als CSV + temporäre Daten für Report
- [ ] `report.qmd` – Quarto-Report Template
  - Zusammenfassung-Tabelle (alle KPIs pro Produkt)
  - Analysen:
    - CR-Analyse (Ampel: grün/gelb/rot je nach CR)
    - SQ-Analyse (Zielbereich 60-80%)
    - SAP-Delta-Analyse
    - Top/Bottom Performer
  - Download-Links für Rohdaten
- [ ] targets-Report-Generierung in Shiny integrieren

**Output**: HTML-Report nach erfolgreichem Durchlauf

---

### Phase 4: Polish & Demo (40min)
- [ ] targets-DAG Screenshot für Pitch
- [ ] README schreiben (Use-Case + Bedienung)
- [ ] Mock-Fehlerfall testen (v2 mit Validierungsfehlern)
- [ ] Code-Kommentare
- [ ] Cleanup & Final Test

---

## Validierungsregeln (pointblanc)

Folgende **Validierungen** müssen greifen:

### Data Quality
- ✅ Pflicht-Spalten vorhanden (je nach File)
- ✅ Datentypen korrekt: `product_id` = char, numerische Spalten = dbl
- ✅ Keine NAs in Pflicht-Spalten
- ✅ Keine Duplikate bei product_id

### Business Rules
- ✅ `bestand > 0`
- ✅ `bvp > 0`
- ✅ `fam_rab + mj_rab < 100` (Rabatte nicht > 100%)
- ✅ `sm` zwischen 0.5 und 1.5 (sinnvoller Bereich)
- ✅ `bk >= 0`
- ✅ Alle 5 Produkte (Amb_T, Amb_S, Amb_C, Hosp_P, Hosp_HP) vorhanden

### Error Messages
- Klar strukturiert
- Nennt konkret welche Spalte/Zeile/Produkt fehlerhaft ist
- Suggeriert Behebung (z.B. "Rabatte können nicht > 100% sein")

---

## Status
🟡 **Phase 1 abgeschlossen** → Phase 2: targets Pipeline + Funktionen

---

## Notizen für Debugging/Pitch
- targets-DAG Screenshot vor Pitch testen!
- Mock-Fehlerfall vorbereiten (csv mit absichtlichen Fehlern)
- Report sollte auch bei kleinen Datenmengen aussagekräftig sein
- pointblanc Rules müssen aussagekräftige Errors werfen
- README für Stakeholder schreiben (nicht nur Entwickler)