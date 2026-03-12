/*********************************************************************
 * Metadata Extension : ZC_SortimentssteuerungReport
 * Version            : 2.0  – List Report mit KPI Header
 *
 * NEU in v2:
 *   @UI.selectionPresentationVariant → KPI Header (4 Karten)
 *   @UI.presentationVariant          → Standard-Sortierung + Gruppierung
 *   @UI.selectionVariant             → "Nur Abweichungen" Schnellfilter
 *   Zeilencriticality via IsDeviation Virtual Element
 *********************************************************************/
@Metadata.layer: #CORE

-- ══════════════════════════════════════════════════════════════════
-- KPI HEADER DEFINITION
-- 4 Kennzahlen erscheinen als Karten über der Tabelle:
--   1. Abweichungen gesamt   (Soll ≠ Ist)
--   2. Gesperrte Module      (ModuleLocked = X)
--   3. Kein Modul            (CurrentModule leer)
--   4. Handlungsbedarf       (Abweichend + nicht gesperrt)
--
-- Technisch: @UI.selectionPresentationVariant verbindet
--   PresentationVariant (Anzeige) + SelectionVariant (Filter)
-- ══════════════════════════════════════════════════════════════════

@UI.selectionPresentationVariant: [
  {
    id:   'DefaultSPV',
    text: 'Standard',
    selectionVariantQualifier:   'DefaultSV',
    presentationVariantQualifier:'DefaultPV'
]

@UI.presentationVariant: [
  {
    qualifier:      'DefaultPV',
    text:           'Standardansicht',
    sortOrder:      [{ by: 'IsDeviation', direction: #DESC },    -- Abweichungen zuerst
                     { by: 'OrderPos_W1_4', direction: #DESC }], -- dann nach Drehung
    visualizations: [{ type: #AS_LINEITEM }]
]

-- Standard SelectionVariant: alle Datensätze, keine Vorfilterung
@UI.selectionVariant: [
  {
    qualifier: 'DefaultSV',
    text:      'Alle Artikel'
  },
  -- Schnellfilter: NUR Abweichungen
  {
    qualifier:       'OnlyDeviations',
    text:            'Nur Abweichungen (Soll≠Ist)',
    filterExpression: {
      propertyName:   'IsDeviation',
      ranges:         [{ sign: #I, option: #EQ, low: 'X' }]
  },
  -- Schnellfilter: Gesperrte Artikel
  {
    qualifier:       'OnlyLocked',
    text:            'Nur gesperrte Module',
    filterExpression: {
      propertyName:   'ModuleLocked',
      ranges:         [{ sign: #I, option: #EQ, low: 'X' }]
]

annotate view ZC_SortimentssteuerungReport with

-- ══════════════════════════════════════════════════════════════════
-- KPI KARTEN
-- Jede @UI.dataPoint Annotation erzeugt eine Karte im Header.
-- Die Werte kommen aus der Aggregation des aktuellen Suchergebnisses.
-- ══════════════════════════════════════════════════════════════════

@UI.chart: [
  {
    qualifier:         'KPIAbweichungen',
    chartType:         #DONUT,
    title:             'Abweichungen Soll≠Ist',
    measures:          ['IsDeviation'],
    measureAttributes: [{ measure: 'IsDeviation', role: #AXIS_1 }]
]

{
  -- ── KPI 1: Abweichungen gesamt ────────────────────────────────────
  @UI.dataPoint: {
    qualifier:    'KPI_Abweichungen',
    title:        'Abweichungen (Soll≠Ist)',
    description:  'Artikel mit abweichendem Soll-Modul',
    criticality:  #CRITICAL,
    visualization:#NUMBER,
    targetValue:  0
  IsDeviation;

  -- ── KPI 2: Gesperrte Module ───────────────────────────────────────
  @UI.dataPoint: {
    qualifier:    'KPI_Gesperrt',
    title:        'Gesperrte Module',
    description:  'Artikel mit fixiertem Modul',
    criticality:  #NEGATIVE,
    visualization:#NUMBER
  ModuleLocked;

  -- ── KPI 3: Ist-Modul (für Anzahl ohne Modul) ─────────────────────
  @UI.dataPoint: {
    qualifier:    'KPI_OhneModul',
    title:        'Ohne Modul',
    description:  'Artikel ohne Sortimentsmodul',
    criticality:  #NEGATIVE,
    visualization:#NUMBER
  CurrentModule;

  -- ── KPI 4: Handlungsbedarf ────────────────────────────────────────
  -- Abweichend UND nicht gesperrt = sofortiger Handlungsbedarf
  @UI.dataPoint: {
    qualifier:    'KPI_Handlungsbedarf',
    title:        'Handlungsbedarf',
    description:  'Abweichend + nicht gesperrt',
    criticality:  #CRITICAL,
    visualization:#NUMBER
  RecommendationCriticality;

  -- ══════════════════════════════════════════════════════════════════
  -- FILTER BAR
  -- ══════════════════════════════════════════════════════════════════

  @UI.selectionField: [{ position: 10 }]  PZN;
  @UI.selectionField: [{ position: 20 }]  MaterialNumber;
  @UI.selectionField: [{ position: 30 }]  CurrentModule;
  @UI.selectionField: [{ position: 40 }]  RecommendedModule_12W;
  @UI.selectionField: [{ position: 50 }]  WVZ;
  @UI.selectionField: [{ position: 55 }]  EKZusatzinfo;

  -- "Nur Abweichungen" Toggle – erscheint als Checkbox im Filter Bar
  @UI.selectionField: [{ position: 60, label: 'Nur Abweichungen' }]
  IsDeviation;

  -- ══════════════════════════════════════════════════════════════════
  -- TABELLENSPALTEN
  -- Reihenfolge: Stammdaten → Zeitreihe → Soll-Modul
  -- Zeilencriticality: RecommendationCriticality (Rot/Grün je Zeile)
  -- ══════════════════════════════════════════════════════════════════

  -- Stammdaten
  @UI.lineItem: [{ position: 10,  importance: #HIGH,   label: 'PZN'                }]  PZN;
  @UI.lineItem: [{ position: 20,  importance: #HIGH,   label: 'Materialnummer'     }]  MaterialNumber;
  @UI.lineItem: [{ position: 30,  importance: #HIGH,   label: 'Bezeichnung'        }]  ProductDescription;
  @UI.lineItem: [{ position: 40,  importance: #MEDIUM, label: 'Hersteller'         }]  ManufacturerPartNumber;
  @UI.lineItem: [{ position: 50,  importance: #MEDIUM, label: 'Lieferant Nr.'      }]  SupplierNumber;
  @UI.lineItem: [{ position: 55,  importance: #MEDIUM, label: 'Lieferant Name'     }]  SupplierName;
  @UI.lineItem: [{ position: 60,  importance: #MEDIUM, label: 'Liefermöglichkeit'  }]  AvailabilityCheck;
  @UI.lineItem: [{ position: 65,  importance: #LOW,    label: 'Kontingent EK'      }]  KontingentkennzeichenEK;
  @UI.lineItem: [{ position: 70,  importance: #MEDIUM, label: 'WVZ'                }]  WVZ;
  @UI.lineItem: [{ position: 72,  importance: #LOW,    label: 'WVZ Bez.'           }]  WVZDescription;
  @UI.lineItem: [{ position: 74,  importance: #LOW,    label: 'Box'                }]  BoxCategory;
  @UI.lineItem: [{ position: 76,  importance: #LOW,    label: 'Bezugsgruppe'       }]  Bezugsgruppe;
  @UI.lineItem: [{ position: 80,  importance: #LOW,    label: 'Saisonkz.'          }]  SeasonCategory;
  @UI.lineItem: [{ position: 85,  importance: #LOW,    label: 'EK-Zusatzinfo'      }]  EKZusatzinfo;
  @UI.lineItem: [{ position: 90,  importance: #LOW,    label: 'FAP'                }]  FAP;
  @UI.lineItem: [{ position: 92,  importance: #LOW,    label: 'AEP'                }]  AEP;

  -- Ist-Modul mit Ampel (Orange = gesperrt)
  @UI.lineItem: [{
    position:    100,
    importance:  #HIGH,
    label:       'Ist-Modul',
    criticality: 'ModuleLockedCriticality',
    criticalityRepresentation: #WITH_ICON
  }]  CurrentModule;

  @UI.lineItem: [{ position: 105, importance: #MEDIUM, label: 'Modul gesperrt'     }]  ModuleLocked;
  @UI.lineItem: [{ position: 110, importance: #LOW,    label: 'Letzte Änderung'    }]  ModuleLastChangedDate;
  @UI.lineItem: [{ position: 115, importance: #LOW,    label: 'EBV-Datum'          }]  EBVDate;

  -- Auftragspositionen
  @UI.lineItem: [{ position: 200, importance: #HIGH,   label: 'Pos. Wo 9-12'       }]  OrderPos_W9_12;
  @UI.lineItem: [{ position: 210, importance: #HIGH,   label: 'Pos. Wo 5-8'        }]  OrderPos_W5_8;
  @UI.lineItem: [{ position: 220, importance: #HIGH,   label: 'Pos. Wo 1-4'        }]  OrderPos_W1_4;

  -- Wunschmenge
  @UI.lineItem: [{ position: 300, importance: #MEDIUM, label: 'Menge Wo 9-12'      }]  OrderQty_W9_12;
  @UI.lineItem: [{ position: 310, importance: #MEDIUM, label: 'Menge Wo 5-8'       }]  OrderQty_W5_8;
  @UI.lineItem: [{ position: 320, importance: #MEDIUM, label: 'Menge Wo 1-4'       }]  OrderQty_W1_4;

  -- Kundenanzahl
  @UI.lineItem: [{ position: 400, importance: #MEDIUM, label: 'Kunden Wo 9-12'     }]  CustomerCnt_W9_12;
  @UI.lineItem: [{ position: 410, importance: #MEDIUM, label: 'Kunden Wo 5-8'      }]  CustomerCnt_W5_8;
  @UI.lineItem: [{ position: 420, importance: #MEDIUM, label: 'Kunden Wo 1-4'      }]  CustomerCnt_W1_4;

  -- Monatswert
  @UI.lineItem: [{ position: 500, importance: #MEDIUM, label: 'Monatswert 12Wo'    }]  MonthValue_W9_12;
  @UI.lineItem: [{ position: 510, importance: #MEDIUM, label: 'Monatswert 8Wo'     }]  MonthValue_W5_8;
  @UI.lineItem: [{ position: 520, importance: #MEDIUM, label: 'Monatswert 4Wo'     }]  MonthValue_W1_4;

  -- Soll-Modul mit Ampel (Rot = Abweichung, Grün = OK)
  @UI.lineItem: [{
    position:    600,
    importance:  #HIGH,
    label:       'Soll-Modul 12Wo',
    criticality: 'RecommendationCriticality',
    criticalityRepresentation: #WITH_ICON
  }]  RecommendedModule_12W;

  @UI.lineItem: [{ position: 610, importance: #HIGH,   label: 'Soll-Modul 8Wo'    }]  RecommendedModule_8W;
  @UI.lineItem: [{ position: 620, importance: #HIGH,   label: 'Soll-Modul 4Wo'    }]  RecommendedModule_4W;
}

  -- ── Customizing Tablo 1 + 2 Felder ───────────────────────────────
  @UI.lineItem: [{ position: 700, importance: #LOW,    label: 'Sensitivität'       }]  SensitivCategory;
  @UI.lineItem: [{ position: 710, importance: #LOW,    label: 'Schwellwert/Monat'  }]  ThresholdValue;
  @UI.lineItem: [{
    position: 720, importance: #MEDIUM, label: 'Schwellwert unterschritten',
    criticality: 'ThresholdCriticality', criticalityRepresentation: #WITH_ICON
  }]  BelowThreshold;
  @UI.selectionField: [{ position: 65, label: 'Nur Schwellwert-Unterschreitung' }]
  BelowThreshold;
