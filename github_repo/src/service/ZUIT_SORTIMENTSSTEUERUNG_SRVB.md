/*********************************************************************
 * Service Binding : ZUIT_SORTIMENTSSTEUERUNG
 * Binding Type    : OData V4 - UI
 *
 * Diese Datei ist dokumentarisch – Service Bindings werden in ADT
 * über die GUI angelegt, nicht als Textdatei.
 *
 * SCHRITT-FÜR-SCHRITT in ADT (Eclipse):
 *
 * 1. Service Definition öffnen: ZUI_SortimentssteuerungReport
 * 2. Rechtsklick → New → Other → Service Binding
 *    Name        : ZUIT_SORTIMENTSSTEUERUNG
 *    Description : Sortimentssteuerung OData V4 UI Service
 *    Binding Type: OData V4 - UI
 * 3. Service Binding aktivieren (Activate Button)
 * 4. "Publish Local Service Endpoint" klicken
 * 5. Generierte URL notieren (siehe unten)
 *
 * GENERIERTE ENDPOINTS:
 *
 * Service Document:
 *   GET /sap/opu/odata4/sap/zuit_sortimentssteuerung/srvd_a2x/
 *       sap/zui_sortimentssteuerungsreport/0001/
 *
 * Metadata:
 *   GET .../0001/$metadata
 *
 * Entity Set lesen:
 *   GET .../0001/SortimentssteuerungSet
 *   GET .../0001/SortimentssteuerungSet?$filter=IsDeviation eq 'X'
 *   GET .../0001/SortimentssteuerungSet?$top=25&$skip=0
 *
 * Einzelner Artikel:
 *   GET .../0001/SortimentssteuerungSet(MaterialNumber='000000001234',PZN='01234567')
 *
 * Aktionen (POST):
 *   POST .../0001/SortimentssteuerungSet(MaterialNumber='...',PZN='...')/
 *        ZC_SortimentssteuerungReport.TakeModuleVariable
 *   POST .../0001/SortimentssteuerungSet(MaterialNumber='...',PZN='...')/
 *        ZC_SortimentssteuerungReport.TakeModuleLocked
 *   POST .../0001/SortimentssteuerungSet(MaterialNumber='...',PZN='...')/
 *        ZC_SortimentssteuerungReport.RemoveLock
 *
 * Background Job Action (alle Artikel):
 *   POST .../0001/SortimentssteuerungSet/
 *        ZC_SortimentssteuerungReport.DetermineModule
 *
 * FIORI LAUNCHPAD KONFIGÜRASYON:
 *   Semantic Object : SortimentssteuerungReport
 *   Action          : display
 *   App Type        : Fiori Elements List Report
 *   OData Service   : ZUIT_SORTIMENTSSTEUERUNG
 *   Entity Set      : SortimentssteuerungSet
 *
 *********************************************************************/
