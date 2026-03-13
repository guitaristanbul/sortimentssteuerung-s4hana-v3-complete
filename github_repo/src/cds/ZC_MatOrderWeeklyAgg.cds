/*********************************************************************
* CDS View Entity : ZC_MatOrderWeeklyAgg
* Layer           : Composite View
* Type            : CDS View Entity (define view entity; no SQL view name / no sqlViewName)
*
* Purpose: 12-week aggregation into 3 time windows
*   W1-4  (WeeksAgo 0-3)    → most recent 4 weeks
*   W5-8  (WeeksAgo 4-7)    → middle 4 weeks
*   W9-12 (WeeksAgo 8-150)  → oldest period (weeks 9+)
*
* Calculated fields per time window:
*   - Number of sales document items (COUNT)
*   - Requested quantity (SUM OrderQuantity)
*   - Number of distinct customers (COUNT DISTINCT SoldToParty)
*   - Net value / monthly value (SUM NetValue)
*********************************************************************/
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Mat. Order History - 12W Aggregate'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZC_MatOrderWeeklyAgg
  as select from ZI_MatOrderHistory
{
  key MaterialNumber,
      MaterialName,
      Currency,

      -- ── SALES DOCUMENT ITEMS ──────────────────────────────────────
      count( distinct case when WeeksAgo between 0 and 3   then SalesDocumentItem end ) as OrderPos_W1_4,
      count( distinct case when WeeksAgo between 4 and 7   then SalesDocumentItem end ) as OrderPos_W5_8,
      count( distinct case when WeeksAgo between 8 and 150 then SalesDocumentItem end ) as OrderPos_W9_12,

      cast( OrderQuantityUnit as meins )                                                as OrderQuantityUnit,

      -- ── REQUESTED QUANTITY ────────────────────────────────────────
      @Semantics.quantity.unitOfMeasure: 'OrderQuantityUnit'
      cast(
        sum( case when WeeksAgo between 0 and 3
                  then OrderQuantity else cast( 0 as abap.dec(13,3) ) end )
        as abap.quan(13,3)
      )                                                                                 as OrderQty_W1_4,

      @Semantics.quantity.unitOfMeasure: 'OrderQuantityUnit'
      cast(
        sum( case when WeeksAgo between 4 and 7
                  then OrderQuantity else cast( 0 as abap.dec(13,3) ) end )
        as abap.quan(13,3)
      )                                                                                 as OrderQty_W5_8,

      @Semantics.quantity.unitOfMeasure: 'OrderQuantityUnit'
      cast(
        sum( case when WeeksAgo between 8 and 150
                  then OrderQuantity else cast( 0 as abap.dec(13,3) ) end )
        as abap.quan(13,3)
      )                                                                                 as OrderQty_W9_12,

      -- ── CUSTOMER COUNT ────────────────────────────────────────────
      count( distinct case when WeeksAgo between 0 and 3
                           then SoldToParty end )                                       as CustomerCnt_W1_4,
      count( distinct case when WeeksAgo between 4 and 7
                           then SoldToParty end )                                       as CustomerCnt_W5_8,
      count( distinct case when WeeksAgo between 8 and 150
                           then SoldToParty end )                                       as CustomerCnt_W9_12,

      -- ── MONTHLY VALUE ─────────────────────────────────────────────
      @Semantics.amount.currencyCode: 'Currency'
      sum( case when WeeksAgo between 0 and 3
                then NetValue else cast( 0 as abap.curr(15,2) ) end )                   as MonthValue_W1_4,

      @Semantics.amount.currencyCode: 'Currency'
      sum( case when WeeksAgo between 4 and 7
                then NetValue else cast( 0 as abap.curr(15,2) ) end )                   as MonthValue_W5_8,

      @Semantics.amount.currencyCode: 'Currency'
      sum( case when WeeksAgo between 8 and 150
                then NetValue else cast( 0 as abap.curr(15,2) ) end )                   as MonthValue_W9_12
}
group by
  MaterialNumber,
  MaterialName,
  Currency,
  OrderQuantityUnit;
