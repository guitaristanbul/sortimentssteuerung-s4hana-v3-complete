/*********************************************************************
* CDS View Entity : ZC_SortimentssteuerungReport
* Layer           : Consumption View (OData / Fiori Elements)
* Type            : CDS View Entity
* Version         : 3.1 – Customizing JOINs integrated directly
*
* JOINs:
*   ZC_MatOrderWeeklyAgg    → Aggregated 12-week order data
*   I_Product               → Material master (Z fields: module, PZN, box...)
*   I_ProductDescription    → Material description
*   I_ProductGroupText_2    → WVZ description
*   I_PurgInfoRecord        → Main supplier
*   I_Supplier              → Supplier name
*   ZSORT_SENSITIV_MAP      → Table 1: WVZ + box → SensitivCategory
*   ZSORT_THRESHOLD         → Table 2: SensitivCategory + CurrentModule → threshold value
*
* Directly calculated fields (no virtual elements):
*   SensitivCategory       → from ZSORT_SENSITIV_MAP
*   ThresholdValue         → from ZSORT_THRESHOLD
*   BelowThreshold         → 'X' if OrderQty_W1_4 < ThresholdValue
*   ThresholdCriticality   → 1 = Red / 3 = Green
*
* Virtual elements (module recommendation – remains in ABAP Rule Engine):
*   IsDeviation
*   RecommendationCriticality
*   ModuleLockedCriticality
*   RecommendedModule_12W / 8W / 4W
*
* NOTE on Table 2 JOIN:
*   The JOIN on ZSORT_THRESHOLD uses CurrentModule (actual/current module).
*   The step-down logic (M5 → M3 → M1) is still executed in
*   ZCL_SORTMODUL_RULE_ENGINE — CDS cannot calculate that.
*********************************************************************/


@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sortimentssteuerung Report'
@Metadata.ignorePropagatedAnnotations: true

@UI.headerInfo: {
  typeName:       'Artikel',
  typeNamePlural: 'Artikel',
  title:          { value: 'ProductDescription' },
  description:    { value: 'PZN' }
}

define view entity ZC_SortimentssteuerungReport
  as select from    ZC_MatOrderWeeklyAgg as Agg

  -- Materialstamm
    inner join      I_Product            as Prod     on Prod.Product = Agg.MaterialNumber

  -- Bezeichnung (sprachabhängig)
    left outer join I_ProductDescription as ProdDesc on  ProdDesc.Product  = Agg.MaterialNumber
                                                     and ProdDesc.Language = $session.system_language

  -- WVZ-Text (sprachabhängig)
    left outer join I_ProductGroupText_2 as WVZText  on  WVZText.ProductGroup = Prod.ProductGroup
                                                     and WVZText.Language     = $session.system_language

  //  -- Hauptlieferant (Einkaufsinfosatz)
  //    left outer join I_PurgInfoRecord     as PurInfo  on  PurInfo.Material           = Agg.MaterialNumber
  //                                                     and PurInfo.InfoRecordCategory = '0'

  //  -- Lieferantenname
  //    left outer join I_Supplier           as Supp     on Supp.Supplier = PurInfo.Supplier

  -- ── CUSTOMIZING TABLO 1 ────────────────────────────────────────
  -- WVZ + Box → Sensitivitätskategorie (S1/S2/S3/S4)
    left outer join zmm_srtmdschwrt1     as SensMap  on  SensMap.zz_atwvz  = Prod.ZZCommodityIndex
                                                     and SensMap.zz_atekod = Prod.ZZReimbursementCode

  -- ── CUSTOMIZING TABLO 2 ────────────────────────────────────────
  -- Sensitivität + Ist-Modul → Schwellwert (Mindestmenge/Monat)
  -- JOIN auf CurrentModule: zeigt Schwellwert des aktuellen Moduls
    left outer join zmm_srtmdschwrt2     as Thresh   on  Thresh.zz_sortcat = SensMap.zz_sortcat
                                                     and Thresh.zz_sortmod = Prod.ZZSortMod

{
      -- ══════════════════════════════════════════════════════════════════
      -- SCHLÜSSELFELDER
      -- ══════════════════════════════════════════════════════════════════

      @UI.lineItem:       [{ position: 10, importance: #HIGH, label: 'PZN' }]
      @UI.selectionField: [{ position: 10 }]
      @Search.defaultSearchElement: true
  key Prod.ZZPZNAT                as PZN,

      @UI.lineItem:       [{ position: 20, importance: #HIGH, label: 'Materialnummer' }]
      @UI.selectionField: [{ position: 20 }]
  key Agg.MaterialNumber          as MaterialNumber,

      -- ══════════════════════════════════════════════════════════════════
      -- STAMMDATEN
      -- ══════════════════════════════════════════════════════════════════

      @UI.lineItem: [{ position: 30, importance: #HIGH, label: 'Bezeichnung' }]
      ProdDesc.ProductDescription as ProductDescription,

      @UI.lineItem: [{ position: 40, importance: #MEDIUM, label: 'Hersteller' }]
      Prod.ZZProducerCode         as ProducerCode,

      @UI.lineItem: [{ position: 50, importance: #MEDIUM, label: 'Lieferant' }]
      Prod.ZZSupplierCode         as SupplierCode,

      //      @UI.lineItem: [{ position: 55, importance: #MEDIUM, label: 'Lieferant Name' }]
      //      Supp.SupplierFullName       as SupplierName,

      @UI.lineItem: [{ position: 60, importance: #MEDIUM, label: 'Liefermöglichkeit' }]
      Prod.ZZSupplyOption         as SupplyOption,

      //      @UI.lineItem: [{ position: 65, importance: #LOW, label: 'Kontingent EK' }]
      //      Prod.ZZ1_KONTINGENT_PRD     as KontingentkennzeichenEK,

      @EndUserText.label: 'WVZ'
      @UI.lineItem:       [{ position: 70, importance: #MEDIUM, label: 'WVZ' }]
      @UI.selectionField: [{ position: 50 }]
      Prod.ZZCommodityIndex       as CommodityIndex,

      //      @UI.lineItem: [{ position: 72, importance: #LOW, label: 'WVZ Bezeichnung' }]
      //      WVZText.ProductGroupName    as WVZDescription,

      @UI.lineItem:       [{ position: 74, importance: #LOW, label: 'Box' }]
      @UI.selectionField: [{ position: 52 }]
      @EndUserText.label: 'Box'
      Prod.ZZReimbursementCode    as ReimbursementCode,

      @UI.lineItem: [{ position: 76, importance: #LOW, label: 'Bezugsgruppe' }]
      Prod.ZZAcquisitionGroup     as AcquisitionGroup,

      @UI.lineItem: [{ position: 80, importance: #LOW, label: 'Saisonkennzeichen' }]
      Prod.ZZSaisontype           as Saisontype,

      @UI.lineItem:       [{ position: 85, importance: #LOW, label: 'EK-Zusatzinfo' }]
      @UI.selectionField: [{ position: 55 }]
      Prod.ZZPurchAdditionalInfo  as PurchAdditionalInfo,

      @UI.lineItem: [{ position: 90, importance: #LOW, label: 'FAP' }]
      @Semantics.amount.currencyCode: 'Currency'
      Prod.ZZFAP                  as FAP,

      @UI.lineItem: [{ position: 92, importance: #LOW, label: 'AEP' }]
      @Semantics.amount.currencyCode: 'Currency'
      Prod.ZZAEP                  as AEP,

      -- Ist-Modul
      @UI.lineItem: [{
        position:    100,
        importance:  #HIGH,
        label:       'Ist-Modul',
        criticality: 'ModuleLockedCriticality'
      }]
      @UI.selectionField: [{ position: 30 }]
      Prod.ZZSortMod              as SortMod,

      //      @UI.lineItem: [{ position: 105, importance: #MEDIUM, label: 'Modul gesperrt' }]
      //      Prod.ZZ1_MODULFIX_PRD       as ModuleLocked,
      //
      //      @UI.lineItem: [{ position: 110, importance: #LOW, label: 'Letzte Moduländerg.' }]
      //      Prod.ZZ1_SORTMODUL_DATE_PRD as ModuleLastChangedDate,

      @UI.lineItem: [{ position: 115, importance: #LOW, label: 'EBV-Von' }]
      Prod.ZZebvvon               as ebvvon,

      @UI.lineItem: [{ position: 120, importance: #LOW, label: 'EBV-Bis' }]
      Prod.ZZebvbis               as ebvbis,


      -- ══════════════════════════════════════════════════════════════════
      -- 12-WOCHEN ZEITREIHE
      -- ══════════════════════════════════════════════════════════════════
      
      Agg.OrderQuantityUnit as OrderQuantityUnit,

      @UI.lineItem: [{ position: 200, importance: #HIGH, label: 'Pos. Wo 9-12' }]
      Agg.OrderPos_W9_12          as OrderPos_W9_12,
      @UI.lineItem: [{ position: 210, importance: #HIGH, label: 'Pos. Wo 5-8' }]
      Agg.OrderPos_W5_8           as OrderPos_W5_8,
      @UI.lineItem: [{ position: 220, importance: #HIGH, label: 'Pos. Wo 1-4' }]
      Agg.OrderPos_W1_4           as OrderPos_W1_4,

      @UI.lineItem: [{ position: 300, importance: #MEDIUM, label: 'Menge Wo 9-12' }]
      @Semantics.quantity.unitOfMeasure: 'OrderQuantityUnit'
      Agg.OrderQty_W9_12          as OrderQty_W9_12,
      @UI.lineItem: [{ position: 310, importance: #MEDIUM, label: 'Menge Wo 5-8' }]
      @Semantics.quantity.unitOfMeasure: 'OrderQuantityUnit'
      Agg.OrderQty_W5_8           as OrderQty_W5_8,
      @UI.lineItem: [{ position: 320, importance: #MEDIUM, label: 'Menge Wo 1-4' }]
      @Semantics.quantity.unitOfMeasure: 'OrderQuantityUnit'
      Agg.OrderQty_W1_4           as OrderQty_W1_4,

      @UI.lineItem: [{ position: 400, importance: #MEDIUM, label: 'Kunden Wo 9-12' }]
      Agg.CustomerCnt_W9_12       as CustomerCnt_W9_12,
      @UI.lineItem: [{ position: 410, importance: #MEDIUM, label: 'Kunden Wo 5-8' }]
      Agg.CustomerCnt_W5_8        as CustomerCnt_W5_8,
      @UI.lineItem: [{ position: 420, importance: #MEDIUM, label: 'Kunden Wo 1-4' }]
      Agg.CustomerCnt_W1_4        as CustomerCnt_W1_4,

      @UI.lineItem: [{ position: 500, importance: #MEDIUM, label: 'Monatswert 12Wo' }]
      @Semantics.amount.currencyCode: 'Currency'
      Agg.MonthValue_W9_12        as MonthValue_W9_12,
      @UI.lineItem: [{ position: 510, importance: #MEDIUM, label: 'Monatswert 8Wo' }]
      @Semantics.amount.currencyCode: 'Currency'
      Agg.MonthValue_W5_8         as MonthValue_W5_8,
      @UI.lineItem: [{ position: 520, importance: #MEDIUM, label: 'Monatswert 4Wo' }]
      @Semantics.amount.currencyCode: 'Currency'
      Agg.MonthValue_W1_4         as MonthValue_W1_4,

      -- ══════════════════════════════════════════════════════════════════
      -- SOLL-MODUL (Virtual Elements – Berechnung im Rule Engine)
      -- ══════════════════════════════════════════════════════════════════

      @UI.lineItem: [{
        position:    600,
        importance:  #HIGH,
        label:       'Soll-Modul 12Wo',
        criticality: 'RecommendationCriticality',
        criticalityRepresentation: #WITH_ICON
      }]
      @UI.selectionField: [{ position: 40 }]
      @ObjectModel.virtualElement: true
      @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_SORT_VIRTUAL_ELEMENTS'
      cast( ' ' as abap.char(2) ) as RecommendedModule_12W,

      @UI.lineItem: [{ position: 610, importance: #HIGH, label: 'Soll-Modul 8Wo' }]
      @ObjectModel.virtualElement: true
      @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_SORT_VIRTUAL_ELEMENTS'
      cast( ' ' as abap.char(2) ) as RecommendedModule_8W,

      @UI.lineItem: [{ position: 620, importance: #HIGH, label: 'Soll-Modul 4Wo' }]
      @ObjectModel.virtualElement: true
      @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_SORT_VIRTUAL_ELEMENTS'
      cast( ' ' as abap.char(2) ) as RecommendedModule_4W,

      -- Abweichungsflag + Ampeln
      @EndUserText.label: 'Nur Abweichungen'
      @UI.selectionField: [{ position: 60 }]
      @ObjectModel.virtualElement: true
      @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_SORT_VIRTUAL_ELEMENTS'
      cast( ' ' as abap.char(1) ) as IsDeviation,

      @ObjectModel.virtualElement: true
      @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_SORT_VIRTUAL_ELEMENTS'
      cast( 0 as abap.int1 )      as RecommendationCriticality,

      @ObjectModel.virtualElement: true
      @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_SORT_VIRTUAL_ELEMENTS'
      cast( 0 as abap.int1 )      as ModuleLockedCriticality,

      -- ══════════════════════════════════════════════════════════════════
      -- CUSTOMIZING TABLO 1: ZSORT_SENSITIV_MAP
      -- WVZ + Box → Sensitivitätskategorie (JOIN, kein Virtual Element)
      -- ══════════════════════════════════════════════════════════════════

      @EndUserText.label: 'Sensitivitätskategorie'
      @UI.lineItem:       [{ position: 700, importance: #MEDIUM, label: 'Sensitivität' }]
      @UI.selectionField: [{ position: 62 }]
      SensMap.zz_sortcat          as SensitivCategory,

      -- ══════════════════════════════════════════════════════════════════
      -- CUSTOMIZING TABLO 2: ZSORT_THRESHOLD
      -- Sensitivität + CurrentModule → Schwellwert (JOIN, kein Virtual Element)
      -- ══════════════════════════════════════════════════════════════════

      @UI.lineItem: [{ position: 710, importance: #MEDIUM, label: 'Schwellwert/Monat' }]
      @EndUserText.label: 'Schwellwert Auftragsmenge/Monat'
      Thresh.mon_ord_qty          as ThresholdValue,

      //      -- Abstufungsziel (z.B. M5→M3): nur informativ, Logik im Rule Engine
      //      @UI.lineItem: [{ position: 715, importance: #LOW, label: 'Abstufung nach' }]
      //      @EndUserText.label: 'Ziel-Modul bei Abstufung'
      //      Thresh.downgrade_to         as DowngradeTo,

      -- ── BelowThreshold: direkt in CDS berechnet ──────────────────────
      -- 'X' wenn Ist-Menge (Wo 1-4) < Schwellwert → Abstufung empfohlen
      @UI.lineItem: [{
        position:    720,
        importance:  #HIGH,
        label:       'Schwellwert unterschritten',
        criticality: 'ThresholdCriticality',
        criticalityRepresentation: #WITH_ICON
      }]
      @UI.selectionField: [{ position: 65 }]
      case
        when Thresh.mon_ord_qty is not initial
         and Agg.OrderQty_W1_4 < Thresh.mon_ord_qty
        then 'X'
        else ' '
      end                         as BelowThreshold,

      -- Ampel für BelowThreshold: 1=Rot (unterschritten), 3=Grün (OK), 0=kein Schwellwert
      @EndUserText.label: 'Schwellwert Ampel'
      case
        when Thresh.mon_ord_qty is initial
        then cast( 0 as abap.int1 )   -- kein Eintrag → keine Ampel
        when Agg.OrderQty_W1_4 < Thresh.mon_ord_qty
        then cast( 1 as abap.int1 )   -- Rot: unterschritten
        else cast( 3 as abap.int1 )   -- Grün: OK
      end                         as ThresholdCriticality,

      -- ══════════════════════════════════════════════════════════════════
      -- WÄHRUNG
      -- ══════════════════════════════════════════════════════════════════
      Agg.Currency                as Currency
}
