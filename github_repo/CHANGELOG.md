# Changelog

## [3.0.0] - 2026-03-12
### Eklendi
- `ZSORT_SENSITIV_MAP` — Tablo 1: WVZ + Box → Sensitivitätskategorie (S1–S4)
- `ZSORT_THRESHOLD` — Tablo 2: Sensitivität + Modul → Schwellwert (Menge/Monat)
- Kural Motoru Stufe 3: Schwellwert-Check → Modul-Abstufung M5→M3→M1
- Virtual Elements: `SensitivCategory`, `ThresholdValue`, `BelowThreshold`
- Schnellfilter "Nur Schwellwert-Unterschreitung" im Filter Bar

## [2.0.0] - 2026-03-12
### Eklendi
- Background Job: `ZCL_SORTMODUL_JOB_CATALOG` (Application Job Framework)
- Job Templates: Mo+Do 02:00 (FULL) · täglich 03:00 (NEW_ONLY)
- RAP `DetermineModule` Action (background-enabled)
- `ZBP_SortimentssteuerungRep` — vollständige RAP Implementation
- `ZCL_SORTMODUL_RULE_ENGINE` — zentraler Kural Motoru (PPT Slide 2)

## [1.0.0] - 2026-03-12
### Eklendi
- CDS View Architektur (3 Katman): ZI_MatOrderHistory → ZC_MatOrderWeeklyAgg → ZC_SortimentssteuerungReport
- Metadata Extension: KPI Header, Filter Bar, Spaltenannotationen
- BDEF: TakeModuleVariable, TakeModuleLocked, RemoveLock
- Virtual Elements: IsDeviation, RecommendationCriticality, ModuleLockedCriticality
- Fiori Elements List Report Vorschau (interaktiv)
