/*********************************************************************
 * CDS View Entity : ZI_MatOrderHistory
 * Layer           : Interface / Basic View
 * Typ             : View Entity (kein sqlViewName!)
 *
 * Standard CDS:
 *   I_SalesOrderItem  → Auftragspositionen (VBAP)
 *   I_SalesOrder      → Auftragskopf       (VBAK)
 *
 * Filtreler:
 *   Auftragsarten  : ZGT1, ZGTA, ZGTE
 *   Kundenfamilien : APO, HAPO  (CustomerGroup = KDGRP)
 *   Zeitraum       : Letzte 84 Tage (12 Wochen)
 *   Keine stornierten Positionen
 *********************************************************************/
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Mat. Bestellhistorie - Rohdaten'

define view entity ZI_MatOrderHistory
  as select from I_SalesOrderItem as Item
    inner join   I_SalesOrder     as Header
      on Header.SalesOrder = Item.SalesOrder
{
  key Item.SalesOrder                   as SalesOrder,
  key Item.SalesOrderItem               as SalesOrderItem,

      -- Malzeme
      Item.Material                     as MaterialNumber,
      Item.SalesOrderItemText           as MaterialName,

      -- Sipariş miktarı (Wunschmenge)
      Item.RequestedQuantity            as OrderQuantity,
      Item.RequestedQuantityUnit        as OrderQuantityUnit,

      -- Net değer (für Monatswert)
      @Semantics.amount.currencyCode: 'Currency'
      Item.NetAmount                    as NetValue,
      Item.TransactionCurrency          as Currency,

      -- Header alanları
      Header.SalesOrderType             as OrderType,
      Header.SoldToParty                as SoldToParty,
      Header.CustomerGroup              as CustomerGroup,

      @Semantics.systemDate.createdAt: true
      Header.CreationDate               as OrderDate,

      -- Kaç hafta önce? (0 = bu hafta, 11 = 12. hafta)
      cast(
        ( $session.system_date - Header.CreationDate ) / 7
        as abap.int4
      )                                 as WeeksAgo
}
where
      Header.SalesOrderType          in ( 'ZGT1', 'ZGTA', 'ZGTE' )
  and Header.CustomerGroup           in ( 'APO', 'HAPO' )
  and Header.CreationDate            >= $session.system_date - 84
  and Item.SalesDocumentRjcnReason    = ''
