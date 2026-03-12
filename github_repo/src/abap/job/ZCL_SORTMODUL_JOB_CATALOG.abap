***********************************************************************
* APPLICATION JOB CATALOG + TEMPLATE
* Zweck : Definiert den Hintergrund-Job für Modulberechnung
*         Wird in der Fiori App "Application Jobs" geplant
*
* SAP Transaktion / App:
*   AJBC  → Application Job Catalog Browser (Catalog Entry anlegen)
*   AJBD  → Application Job Browser (Jobs planen & überwachen)
*   Fiori → "Application Jobs" App (F0816)
*
* SCHRITT 1: Catalog Entry in AJBC anlegen
* SCHRITT 2: Job Template anlegen
* SCHRITT 3: Job in "Application Jobs" Fiori App planen
***********************************************************************

*=====================================================================*
* SCHRITT 1: ABAP Klasse für Application Job Catalog
* Diese Klasse registriert den Job im Application Job Framework
*=====================================================================*
CLASS zcl_sortmodul_job_catalog DEFINITION
  PUBLIC FINAL CREATE PUBLIC
  INHERITING FROM cl_apj_dt_base.           " Application Job DT Base

  PUBLIC SECTION.
    " Konstanten für Job-Parameter
    CONSTANTS:
      c_job_catalog_name TYPE cl_apj_rt_api=>ty_catalog_name
        VALUE 'ZSORTIMENTSMODUL_JOB',
      c_job_template_name TYPE cl_apj_rt_api=>ty_template_name
        VALUE 'ZSORTIMENTSMODUL_WOCHENTLICH'.

    " Job-Parameter Struktur
    TYPES:
      BEGIN OF ty_job_params,
        run_mode  TYPE char10,  " FULL / NEW_ONLY
        werk      TYPE werks_d, " optional: Werk-Filter
        log_level TYPE char1,   " E=nur Fehler / I=alle Änderungen
      END OF ty_job_params.

    " Pflichtmethode: Parameter-Schema definieren
    METHODS get_parameters
      REDEFINITION.

    " Pflichtmethode: Job ausführen
    METHODS execute
      REDEFINITION.

ENDCLASS.


CLASS zcl_sortmodul_job_catalog IMPLEMENTATION.

  "*--------------------------------------------------------------------*
  "* Parameter-Schema: Was kann der Planer eingeben?
  "*--------------------------------------------------------------------*
  METHOD get_parameters.
    rt_parameter_def = VALUE #(
      "  Parameter    Typ        Label                    Pflicht  Default
      ( name = 'RUN_MODE'  type = 'CHAR10'  label = 'Ausführungsmodus'
        mandatory = abap_true  default_value = 'FULL'
        value_help = VALUE #(
          ( value = 'FULL'     text = 'Alle Artikel prüfen' )
          ( value = 'NEW_ONLY' text = 'Nur neue Artikel (Datacare)' )
        )
      )
      ( name = 'WERK'      type = 'WERKS_D' label = 'Werk (optional)'
        mandatory = abap_false
      )
      ( name = 'LOG_LEVEL' type = 'CHAR1'   label = 'Log-Detail'
        mandatory = abap_false  default_value = 'I'
        value_help = VALUE #(
          ( value = 'E' text = 'Nur Fehler' )
          ( value = 'I' text = 'Alle Änderungen' )
        )
      )
    ).
  ENDMETHOD.


  "*--------------------------------------------------------------------*
  "* execute: Wird vom Application Job Framework aufgerufen
  "*--------------------------------------------------------------------*
  METHOD execute.
    " Parameter auslesen
    DATA(ls_params) = CORRESPONDING ty_job_params(
      get_parameter_values( ) ).

    " RAP DetermineModule Action direkt aufrufen
    " (Gleicher Code wie bei direktem RAP-Aufruf)
    MODIFY ENTITIES OF ZC_SortimentssteuerungReport
      ENTITY SortimentsReport
      EXECUTE DetermineModule
      FROM VALUE #( (
        %key      = VALUE #( )   " leer = alle Artikel
        %param    = VALUE ZA_DetermineModuleParam(
          run_mode = ls_params-run_mode
          werk     = ls_params-werk
        )
      ) )
      REPORTED DATA(lt_reported)
      FAILED   DATA(lt_failed).

    " Fehler-Handling
    IF lt_failed IS NOT INITIAL.
      DATA(lv_errors) = lines( lt_failed ).
      MESSAGE |Job fehlerhaft: { lv_errors } Fehler aufgetreten| TYPE 'E'.
    ENDIF.
  ENDMETHOD.

ENDCLASS.


*=====================================================================*
* SCHRITT 2: Job Template via ABAP anlegen (einmalig ausführen)
* Alternativ: Manuell in AJBC Transaktion
*=====================================================================*
CLASS zcl_sortmodul_job_setup DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    " Einmalig ausführen um Job Catalog Entry + Template anzulegen
    CLASS-METHODS setup_job_catalog
      RAISING cx_apj_dt.

ENDCLASS.


CLASS zcl_sortmodul_job_setup IMPLEMENTATION.

  METHOD setup_job_catalog.

    " ── Catalog Entry anlegen ─────────────────────────────────────
    cl_apj_dt_create_content=>create_catalog_entry(
      EXPORTING
        iv_catalog_name          = zcl_sortmodul_job_catalog=>c_job_catalog_name
        iv_class_name            = 'ZCL_SORTMODUL_JOB_CATALOG'
        iv_text                  = 'Sortimentssteuerung – Automatische Modulberechnung'
        iv_catalog_entry_type    = cl_apj_dt_create_content=>class_based
      EXCEPTIONS
        catalog_entry_not_exists = 1
        OTHERS                   = 2 ).

    " ── Job Template anlegen (2x wöchentlich: Mo + Do) ───────────
    cl_apj_dt_create_content=>create_job_template(
      EXPORTING
        iv_catalog_name   = zcl_sortmodul_job_catalog=>c_job_catalog_name
        iv_template_name  = zcl_sortmodul_job_catalog=>c_job_template_name
        iv_text           = 'Modulberechnung 2x wöchentlich (Mo+Do)'
        it_parameters     = VALUE #(
          ( name = 'RUN_MODE'  value = 'FULL' )
          ( name = 'LOG_LEVEL' value = 'I'    )
        )
        " Zeitplan: Montag + Donnerstag, 02:00 Uhr
        iv_start_immediately = abap_false
        is_schedule = VALUE #(
          periodic          = abap_true
          periodic_interval = VALUE #(
            weeks           = 1
            weekday_mon     = abap_true   " Montag
            weekday_thu     = abap_true   " Donnerstag
            time            = '020000'    " 02:00 Uhr
          )
        )
      EXCEPTIONS
        OTHERS = 1 ).

    " ── Tägliches Template für Datacare Neuzugänge ───────────────
    cl_apj_dt_create_content=>create_job_template(
      EXPORTING
        iv_catalog_name   = zcl_sortmodul_job_catalog=>c_job_catalog_name
        iv_template_name  = 'ZSORTIMENTSMODUL_TAEGLICH'
        iv_text           = 'Modulberechnung täglich (nur neue Artikel)'
        it_parameters     = VALUE #(
          ( name = 'RUN_MODE'  value = 'NEW_ONLY' )
          ( name = 'LOG_LEVEL' value = 'I'        )
        )
        is_schedule = VALUE #(
          periodic          = abap_true
          periodic_interval = VALUE #(
            days            = 1
            time            = '030000'   " 03:00 Uhr
          )
        )
      EXCEPTIONS
        OTHERS = 1 ).

  ENDMETHOD.

ENDCLASS.
