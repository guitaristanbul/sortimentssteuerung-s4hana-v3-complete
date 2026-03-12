/*********************************************************************
 * CDS View Entity : ZC_MatOrderWeeklyAgg
 * Layer           : Composite View
 * Typ             : View Entity (kein sqlViewName!)
 *
 * Zweck: 12-Wochen Aggregation in 3 Zeitfenster
 *   Wo 1-4  (WeeksAgo 0-3)  → jüngste 4 Wochen
 *   Wo 5-8  (WeeksAgo 4-7)  → mittlere 4 Wochen
 *   Wo 9-12 (WeeksAgo 8-11) → älteste 4 Wochen
 *
 * Berechnete Felder je Zeitfenster:
 *   - Anzahl Kundenauftragspositionen (COUNT)
 *   - Wunschmenge (SUM RequestedQuantity)
 *   - Anzahl verschiedene Kunden (COUNT DISTINCT SoldToParty)
 *   - Nettowert / Monatswert (SUM NetValue)
 *********************************************************************/
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Mat. Bestellhistorie - 12-Wo-Aggregat'

define view entity ZC_MatOrderWeeklyAgg
  as select from ZI_MatOrderHistory
{
  key MaterialNumber,
      MaterialName,
      Currency,

      -- ── AUFTRAGSPOSITIONEN ────────────────────────────────────────
      count( case when WeeksAgo between 0  and 3  then 1 end )
                                        as OrderPos_W1_4,
      count( case when WeeksAgo between 4  and 7  then 1 end )
                                        as OrderPos_W5_8,
      count( case when WeeksAgo between 8  and 11 then 1 end )
                                        as OrderPos_W9_12,

      -- ── WUNSCHMENGE ───────────────────────────────────────────────
      @Semantics.quantity.unitOfMeasure: 'OrderQuantityUnit'
      sum( case when WeeksAgo between 0  and 3
                then OrderQuantity else cast( 0 as abap.dec(13,3) ) end )
                                        as OrderQty_W1_4,

      @Semantics.quantity.unitOfMeasure: 'OrderQuantityUnit'
      sum( case when WeeksAgo between 4  and 7
                then OrderQuantity else cast( 0 as abap.dec(13,3) ) end )
                                        as OrderQty_W5_8,

      @Semantics.quantity.unitOfMeasure: 'OrderQuantityUnit'
      sum( case when WeeksAgo between 8  and 11
                then OrderQuantity else cast( 0 as abap.dec(13,3) ) end )
                                        as OrderQty_W9_12,

      -- ── KUNDENANZAHL ──────────────────────────────────────────────
      count( distinct case when WeeksAgo between 0  and 3
                           then SoldToParty end )
                                        as CustomerCnt_W1_4,
      count( distinct case when WeeksAgo between 4  and 7
                           then SoldToParty end )
                                        as CustomerCnt_W5_8,
      count( distinct case when WeeksAgo between 8  and 11
                           then SoldToParty end )
                                        as CustomerCnt_W9_12,

      -- ── MONATSWERT ────────────────────────────────────────────────
      @Semantics.amount.currencyCode: 'Currency'
      sum( case when WeeksAgo between 0  and 3
                then NetValue else cast( 0 as abap.curr(15,2) ) end )
                                        as MonthValue_W1_4,

      @Semantics.amount.currencyCode: 'Currency'
      sum( case when WeeksAgo between 4  and 7
                then NetValue else cast( 0 as abap.curr(15,2) ) end )
                                        as MonthValue_W5_8,

      @Semantics.amount.currencyCode: 'Currency'
      sum( case when WeeksAgo between 8  and 11
                then NetValue else cast( 0 as abap.curr(15,2) ) end )
                                        as MonthValue_W9_12
}
group by
  MaterialNumber,
  MaterialName,
  Currency
