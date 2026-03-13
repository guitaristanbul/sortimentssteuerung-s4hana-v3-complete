/*********************************************************************
* CDS View Entity : ZI_MatOrderHistory
* Layer           : Interface / Basic View
* Type            : View Entity (no sqlViewName!)
*
* Standard CDS:
*   I_SalesOrderItem  → Sales order items (VBAP)
*   I_SalesOrder      → Sales order header (VBAK)
*
* Filters:
*   Order types     : ZGT1, ZGTA, ZGTE
*   Customer families: APO, HAPO  (CustomerGroup = KDGRP)
*   Period          : Last 84 days (12 weeks)
*   No cancelled items
 *********************************************************************/

@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Mat. Bestellhistorie - Rohdaten'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_MatOrderHistory
  as select from I_SalesDocumentItem  as DocItem
    inner join   I_SalesDocumentBasic as DocBasic on DocBasic.SalesDocument = DocItem.SalesDocument
{
  key DocItem.SalesDocument         as SalesDocument,
  key DocItem.SalesDocumentItem     as SalesDocumentItem,

      -- Material
      DocItem.Material              as MaterialNumber,
      DocItem.SalesDocumentItemText as MaterialName,

      @Semantics.quantity.unitOfMeasure: 'OrderQuantityUnit'
      DocItem.OrderQuantity         as OrderQuantity,
      DocItem.OrderQuantityUnit     as OrderQuantityUnit,

      -- Net value (for monthly value)
      @Semantics.amount.currencyCode: 'Currency'
      DocItem.NetAmount             as NetValue,
      DocItem.TransactionCurrency   as Currency,

      // -- Header fields
      DocItem.SalesDocumentType     as OrderType,
      DocItem.SoldToParty           as SoldToParty,

      @Semantics.systemDate.createdAt: true
      DocBasic.CreationDate         as OrderDate,

      -- How many weeks ago? (0 = this week, 11 = 12th week)
      cast(
        ( dats_days_between( DocBasic.CreationDate, $session.system_date ) ) / 7
        as abap.int4
      )                             as WeeksAgo
}
where
  (
       DocItem.SalesDocumentType = 'ZGT1'
    or DocItem.SalesDocumentType = 'ZGTA'
    or DocItem.SalesDocumentType = 'ZGTE'
  )

  and(
       DocBasic.ZZCustomerFamily = 'APO'
    or DocBasic.ZZCustomerFamily = 'HAP'
  )
//  and  DocItem.CreationDate            >= dats_add_days( $session.system_date, -84, 'FAIL' )
//  and  DocItem.SalesDocumentRjcnReason =  ''
