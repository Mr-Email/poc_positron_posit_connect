# PROJECT.md - Budget & Hochrechnung Automation PoC

## Projektziel
Pitch am Montag für Lösungsvorschlag zur Vereinfachung von Hochrechnungs- und Budget-Prozessen.
- **Problem**: Manueller Excel-Austausch, ineffizient, nicht nachvollziehbar
- **Lösung**: Automatisierte Pipeline (targets) mit validierter Datenverarbeitung
- **MVP**: Funktionsfähige targets-Pipeline + Quarto-Report + validierte Kernfunktionen

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
1. **Input (v1)**: 4 CSV-Dateien vorhanden
2. **Validierung**: pointblanc prüft Datenqualität
   - Wenn **Fehler**: Abbruch mit aussagekräftigen Fehlermeldungen
   - Wenn **OK**: Weiter zu Berechnung
3. **Berechnung**: targets-Pipeline berechnet nvp, SQ, vp, va, CR
4. **Output**: Quarto-Report mit:
   - Zusammenfassung (Tabelle mit allen KPIs pro Produkt)
   - Analysen (CR-Verteilung, SQ-Analyse, SAP-Vergleich)
   - Download-Link zu Rohdaten

### v2-Szenario (Demo)
- Fehlerhafte v1 wird behoben → v2 hochgeladen
- targets-Pipeline läuft erneut
- **Caching**: Unveränderte Inputs werden wiederverwendet

---

## Architektur & Tech-Stack

### PoC (aktuell, GitHub)
- **Versionskontrolle**: GitHub
- **Datenvalidation**: pointblanc (Custom Rules)
- **Workflow-Orchestrierung**: `targets` (DAG + Caching)
- **Output-Format**: Quarto (.qmd → HTML/PDF Report)
- **Testing**: testthat für Rechenfunktionen + Validierung

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

**Status**: ✅ Abgeschlossen

---

### Phase 2: Core-Funktionen & Tests (90min) ✅
- [x] `R/01_load_data.R` – CSV-Laden mit Error-Handling
- [x] `R/02_validate_data.R` – Validierungsregeln
- [x] `R/03_calculate.R` – Formelwerk-Implementierung
- [x] `_targets.R` – Data-Pipeline funktionsfähig
- [x] Validierung in targets integriert
- [x] Tests inline (in _targets.R)

**Status**: ✅ Abgeschlossen – Pipeline läuft erfolgreich!

---

### Phase 3: Quarto-Report & Shiny-Dashboard (60min) 🟡
- [x] `report.qmd` – Quarto-Report Template erstellt
- [ ] `app.R` – Shiny-Dashboard für Versions-Vergleich
- [ ] targets-Pipeline mit Report testen
- [ ] Shiny-App starten und testen

**Status**: 🟡 In Arbeit – Report-Template vorhanden, Shiny folgt

---

### Phase 4: Polish & Demo (40min) ⏳
- [ ] targets-DAG Screenshot für Pitch
- [ ] README schreiben
- [ ] Mock-Fehlerfall testen
- [ ] Final Test vor Pitch

**Status**: ⏳ Ausstehend

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

## Testing-Strategie

### Unit Tests (testthat) für Core-Funktionen
Dateien in `tests/testthat/`:

**test_01_load_data.R** – CSV-Laden testen:
- CSV wird korrekt geladen (Spalten, Zeilen)
- Datentypen werden korrekt interpretiert
- Error-Handling bei fehlenden Dateien

**test_02_validate_data.R** – pointblanc Regeln testen:
- Data Quality Checks (Spalten, NAs, Duplikate)
- Business Rule Checks (Rabatte, SM-Range, alle Produkte)
- Aussagekräftige Error-Messages

**test_03_calculate.R** – Formelwerk testen:
- `nvp` korrekt berechnet (nvp = bvp - (fam_rab + mj_rab))
- `SQ` korrekt berechnet (SQ = nvl / nvp)
- `vp` korrekt berechnet (vp = nvp - advo - pd)
- `va` korrekt berechnet (va = nvl + sap + sm)
- `CR` korrekt berechnet (CR = (va + bk) / vp)
- Edge Cases (Division by zero, negative values)

### Workflow Tests
`tests/testthat/test_workflow.R` – Load → Validate → Calculate:
- v1 (gültig) → Validierung OK → Berechnung erfolgreich
- v1 (Fehler) → Validierung schlägt fehl → Error-Message
- v2 (behoben) → Validierung OK → Berechnung erfolgreich

---

## Status
🟡 **Phase 1 abgeschlossen** → Phase 2: Core-Funktionen implementieren + testen

---

## Notizen für Debugging/Pitch
- targets-DAG Screenshot vor Pitch testen!
- Mock-Fehlerfall (CSV mit absichtlichen Fehlern) vorbereiten
- Report sollte auch bei kleinen Datenmengen aussagekräftig sein
- pointblanc Rules müssen aussagekräftige Errors werfen
- README für Stakeholder schreiben (nicht nur Entwickler)