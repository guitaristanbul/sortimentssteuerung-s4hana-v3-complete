# 🧩 Sortimentssteuerung – SAP S/4HANA Fiori Report + Background Job

> Automatische und manuelle Sortimentsmodulsteuerung auf Basis von Kundenauftragsdrehung der letzten 12 Wochen.  
> S/4HANA · RAP · Fiori Elements · Application Jobs

---

## 📋 Inhalt

- [Überblick](#überblick)
- [Architektur](#architektur)
- [Projektstruktur](#projektstruktur)
- [Customizing Tabellen](#customizing-tabellen)
- [Kural Motoru / Regellogik](#kural-motoru--regellogik)
- [Background Job](#background-job)
- [Fiori Elements UI](#fiori-elements-ui)
- [Implementierungsschritte](#implementierungsschritte)

---

## Überblick

Dieser Report zeigt je Artikel die **Kundenauftragspositionen der letzten 12 Wochen** in drei Zeitfenstern und berechnet daraus ein **Soll-Sortimentsmodul (Empfehlung)**.

**Auftragsarten:** ZGT1 · ZGTA · ZGTE  
**Kundenfamilien:** Apo · Hapo  
**Module:** M1 · M3 · M5 · MB · MN

---

## Architektur

```
┌──────────────────────────────────────────────────────────────────┐
│                   Fiori Elements List Report                      │
│   KPI Header · Filter Bar · Schwellwert-Ampel · Aktionsbuttons   │
└──────────────────────────┬───────────────────────────────────────┘
                           │ OData V4
┌──────────────────────────▼───────────────────────────────────────┐
│          ZC_SortimentssteuerungReport  (Consumption View)        │
│          + Metadata Extension  +  BDEF  + Virtual Elements       │
└──────────────────────────┬───────────────────────────────────────┘
                           │
          ┌────────────────┴───────────────────┐
          ▼                                    ▼
┌─────────────────────┐            ┌──────────────────────────────┐
│ ZC_MatOrderWeeklyAgg│            │  Customizing Tabellen         │
│ (Aggregation 3 Wo.) │            │                               │
└──────────┬──────────┘            │  ZSORT_SENSITIV_MAP           │
           │                       │  WVZ + Box → Sensitivität     │
┌──────────▼──────────┐            │  (S1 / S2 / S3 / S4)         │
│ ZI_MatOrderHistory  │            │                               │
│ I_SalesOrder +      │            │  ZSORT_THRESHOLD              │
│ I_SalesOrderItem    │            │  Sensitivität + Modul →       │
└─────────────────────┘            │  Schwellwert (Menge/Monat)    │
                                   └──────────────┬───────────────┘
                                                  │
┌─────────────────────────────────────────────────▼───────────────┐
│                  ZCL_SORTMODUL_RULE_ENGINE                        │
│                                                                   │
│  Stufe 1: ModuleLocked?     → Keine Änderung                     │
│  Stufe 2: Spezialfall?      → MN (Dummy/gesperrt/Datacare/Th.73) │
│                             → MB (IFA/Sammel-PZN/LiefKat.5)      │
│  Stufe 3: Schwellwert-Check → Menge < Threshold → M5→M3→M1       │
└──────────────────────────────────────────────────────────────────┘
                           │
         ┌─────────────────┴──────────────────┐
         ▼                                    ▼
┌─────────────────┐                ┌────────────────────────────┐
│  Fiori UI       │                │  Application Job Framework  │
│  (sofortige     │                │  Mo+Do 02:00  → FULL        │
│   Aktionstaste) │                │  täglich 03:00 → NEW_ONLY   │
└─────────────────┘                └────────────────────────────┘
```

---

## Projektstruktur

```
📦 sortimentssteuerung-s4hana
 ┣ 📂 src
 ┃ ┣ 📂 cds
 ┃ ┃ ┣ ZI_MatOrderHistory.cds               Layer 1: Basic View
 ┃ ┃ ┣ ZC_MatOrderWeeklyAgg.cds             Layer 2: Composite (Aggregation)
 ┃ ┃ ┣ ZC_SortimentssteuerungReport.cds     Layer 3: Consumption (OData)
 ┃ ┃ ┣ ZC_SortimentssteuerungReport_MEXT.cds   UI Annotations
 ┃ ┃ ┗ ZC_SortimentssteuerungReport_BDEF.bdef  RAP Behavior Definition
 ┃ ┣ 📂 abap
 ┃ ┃ ┣ 📂 behavior
 ┃ ┃ ┃ ┗ ZBP_SortimentssteuerungRep.abap    RAP Implementation (alle Aktionen)
 ┃ ┃ ┣ 📂 job
 ┃ ┃ ┃ ┗ ZCL_SORTMODUL_JOB_CATALOG.abap     Application Job Catalog + Templates
 ┃ ┃ ┣ 📂 virtual_elements
 ┃ ┃ ┃ ┗ ZCL_SORTMODUL_RULE_ENGINE.abap     Kural Motoru (Stufe 1–3)
 ┃ ┃ ┗ 📂 customizing
 ┃ ┃   ┣ ZSORT_SENSITIV_MAP.abap            Tablo 1: WVZ+Box → Sensitivität
 ┃ ┃   ┗ ZSORT_THRESHOLD.abap               Tablo 2: Sensitivität+Modul → Schwellwert
 ┣ 📂 docs
 ┃ ┗ 📂 preview
 ┃   ┗ fiori_preview.html                   Interaktive UI-Vorschau
 ┣ 📄 .gitignore
 ┣ 📄 CHANGELOG.md
 ┗ 📄 README.md                             ← Diese Datei
```

---

## Customizing Tabellen

### Tablo 1: `ZSORT_SENSITIV_MAP` — WVZ + Box → Sensitivitätskategorie

| WVZ | Box | Sensitivität | Erklärung |
|-----|-----|-------------|-----------|
| PHARM_RX | A | **S1** | Hochsensitiv – viel Drehung nötig |
| PHARM_RX | C | **S2** | |
| CARD | C | **S3** | |
| ALLER | E | **S4** | Niedrigsensitiv – wenig Drehung reicht |

> Pflege über SM30 → View `V_ZSORT_SENSITIV` oder Fiori "Custom Business Configurations"

---

### Tablo 2: `ZSORT_THRESHOLD` — Sensitivitätskategorie + Modul → Schwellwert

| Sensitivität | Modul | Schwellwert/Monat | Abstufung nach |
|---|---|---|---|
| S1 | M5 | 50 Pos. | M3 |
| S1 | M3 | 15 Pos. | M1 |
| S2 | M5 | 30 Pos. | M3 |
| S2 | M3 | 10 Pos. | M1 |
| S3 | M5 | 15 Pos. | M3 |
| S3 | M3 |  5 Pos. | M1 |
| S4 | M5 |  5 Pos. | M3 |
| S4 | M3 |  2 Pos. | M1 |

**Beispiel:**
```
Artikel: WVZ=PHARM_RX, Box=A → Sensitivität S1  (Tablo 1)
Aktuelles Modul: M5, Menge Wo1-4: 40 Pos.
Schwellwert S1/M5 = 50 Pos.
40 < 50 → Abstufung M5 → M3  ✓
```

> Pflege über SM30 → View `V_ZSORT_THRESHOLD`

---

## Kural Motoru / Regellogik

```
Stufe 1  ModuleLocked = 'X'?
         └─ JA  → Keine Änderung (Sperre respektieren)

Stufe 2  Spezialfall?
         ├─ MN: Lieferant Dummy / gesperrt
         ├─ MN: Datacare storniert (S) oder Null (0)
         ├─ MN: Therapiegruppe 73 (Pflanzenschutz)
         ├─ MB: IFA-Arzneimittel
         ├─ MB: Preisansatz / Sammel-PZN
         ├─ MB: Lieferantenkategorie 5
         └─ Neuer Artikel → MN (Dummy/gesperrt) / MB (sonst)

Stufe 3  Schwellwert-Check:
         WVZ + Box ──► ZSORT_SENSITIV_MAP ──► Sensitivität
         Sensitivität + Modul ──► ZSORT_THRESHOLD ──► Schwellwert
         Menge Wo1-4 < Schwellwert?
         └─ JA  → M5→M3  oder  M3→M1
         └─ NEIN → Modul unverändert
```

---

## Background Job

| Template | Modus | Zeitplan | Zweck |
|---|---|---|---|
| `ZSORTIMENTSMODUL_WOCHENTLICH` | FULL | Mo + Do, 02:00 | Alle Artikel prüfen |
| `ZSORTIMENTSMODUL_TAEGLICH` | NEW_ONLY | täglich, 03:00 | Nur Datacare-Neuzugänge |

**Einrichten:**
```
1. ZCL_SORTMODUL_JOB_CATALOG compilieren
2. setup_job_catalog( ) einmalig ausführen
3. Fiori App "Application Jobs" (F0816) → Templates aktivieren
```

**Überwachen:** SLG1 → Object: `ZSORTIMENTSSTEUERUNG`

---

## Fiori Elements UI

**Typ:** List Report + KPI Header | **OData:** V4

### KPI Header
| Karte | Farbe | Inhalt |
|---|---|---|
| Abweichungen Soll≠Ist | 🔴 Rot | Artikel mit abweichendem Soll-Modul |
| Gesperrte Module | 🟠 Orange | Fixierte Artikel |
| Ohne Modul | 🔴 Rot | Artikel ohne Sortimentsmodul |
| Übereinstimmend | 🟢 Grün | Soll = Ist |

### Aktionsbuttons (Slide 7)
- ✅ Merkmal übernehmen (variabel)
- 🔒 Merkmal übernehmen (gesperrt)
- 🔓 Sperre entfernen

### Schnellfilter
- **Nur Abweichungen** — zeigt nur Soll≠Ist Artikel
- **Nur Schwellwert-Unterschreitung** — zeigt nur abstufungsbedürftige Artikel

→ Interaktive Vorschau: [`docs/preview/fiori_preview.html`](docs/preview/fiori_preview.html)

---

## Implementierungsschritte

```
1. SE11: DDIC Tabellen anlegen
   └─ ZSORT_SENSITIV_MAP, ZSORT_THRESHOLD, ZSORTMODUL_T
   └─ Aktionsparameter: ZA_TakeModuleParam, ZA_DetermineModuleParam

2. ADT: CDS Views aktivieren (Reihenfolge!)
   └─ ZI_MatOrderHistory → ZC_MatOrderWeeklyAgg → ZC_SortimentssteuerungReport
   └─ Metadata Extension + BDEF

3. ADT: ABAP Classes
   └─ ZCL_SORTMODUL_CUSTO_TABLE1 (aus ZSORT_SENSITIV_MAP.abap)
   └─ ZCL_SORTMODUL_CUSTO_TABLE2 (aus ZSORT_THRESHOLD.abap)
   └─ ZCL_SORTMODUL_RULE_ENGINE
   └─ ZBP_SortimentssteuerungRep
   └─ ZCL_SORTMODUL_JOB_CATALOG

4. SM30: Customizing Tabellen befüllen
   └─ V_ZSORT_SENSITIV  → WVZ + Box Kombinationen
   └─ V_ZSORT_THRESHOLD → Schwellwerte je Sensitivität + Modul

5. Service Definition + Service Binding (OData V4)

6. Application Job Catalog: setup_job_catalog( ) ausführen

7. Fiori Launchpad: Tile + Application Jobs aktivieren
```

---

## Z-Felder (an eigenes System anpassen)

| Feldname | Bedeutung |
|---|---|
| `ZZ1_PZN_PRD` | Pharmazentralnummer |
| `ZZ1_SORTMODUL_PRD` | Sortimentsmodul (Ist) |
| `ZZ1_MODULFIX_PRD` | Modul-Fixierung |
| `ZZ1_BOX_PRD` | Box-Ausprägung |
| `ZZ1_EKZUSATZ_PRD` | EK-Zusatzinfo |
| `ZZ1_DATACARE_STATUS_PRD` | Datacare-Status |
| `ZZ1_THERAPIEGRUPPE_PRD` | Therapiegruppe |
| `ZZ1_IFA_PRD` | IFA-Arzneimittel Flag |
| `ZZ1_SAMMEL_PZN_PRD` | Sammel-PZN Flag |
