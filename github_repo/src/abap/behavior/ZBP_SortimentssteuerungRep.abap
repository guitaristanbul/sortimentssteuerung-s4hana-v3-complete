***********************************************************************
* ABAP Class : ZBP_SortimentssteuerungRep
* Zweck      : RAP Behavior Implementation
*              Implementiert alle Aktionen aus dem BDEF
*
* Methoden:
*   TakeModuleVariable  → UI: Empfehlung variabel übernehmen
*   TakeModuleLocked    → UI: Empfehlung gesperrt übernehmen
*   RemoveLock          → UI: Sperre entfernen
*   DetermineModule     → JOB: Automatische Modulberechnung
*                         (background-enabled, Application Job)
***********************************************************************
CLASS zbp_sortimentssteuerungRep DEFINITION
  PUBLIC ABSTRACT FINAL
  FOR BEHAVIOR OF ZC_SortimentssteuerungReport.

  PRIVATE SECTION.

    " Hilfsmethode: Daten für Regelmotor aus DB lesen
    CLASS-METHODS read_rule_input
      IMPORTING
        it_keys            TYPE TABLE OF KEY
      RETURNING
        VALUE(rt_input)    TYPE ZCL_SORTMODUL_RULE_ENGINE=>tt_article_input.

    " Hilfsmethode: Modul-Update in Persistenzschicht schreiben
    CLASS-METHODS write_module_update
      IMPORTING
        is_result          TYPE ZCL_SORTMODUL_RULE_ENGINE=>ty_module_result
        iv_lock            TYPE abap_bool DEFAULT abap_false
      CHANGING
        cv_reported        TYPE reported.

    " Hilfsmethode: Application Log Eintrag schreiben
    CLASS-METHODS write_log
      IMPORTING
        iv_matnr           TYPE matnr
        iv_old_module      TYPE char2
        iv_new_module      TYPE char2
        iv_reason          TYPE string
        iv_jobrun          TYPE abap_bool DEFAULT abap_false.

ENDCLASS.


CLASS zbp_sortimentssteuerungRep IMPLEMENTATION.

  "*--------------------------------------------------------------------*
  "* ACTION: TakeModuleVariable
  "* UI-Aktion: Soll-Modul variabel übernehmen (editierbar)
  "*--------------------------------------------------------------------*
  METHOD TakeModuleVariable.
    LOOP AT keys INTO DATA(lv_key).

      " 1. Aktuellen Datensatz lesen
      READ ENTITIES OF ZC_SortimentssteuerungReport
        ENTITY SortimentsReport
        FIELDS ( MaterialNumber CurrentModule RecommendedModule_12W ModuleLocked )
        WITH VALUE #( ( %key = lv_key ) )
        RESULT DATA(lt_data).

      CHECK lt_data IS NOT INITIAL.
      DATA(ls_data) = lt_data[ 1 ].

      " 2. Gesperrte Artikel überspringen
      IF ls_data-ModuleLocked = abap_true.
        APPEND VALUE #(
          %key = lv_key
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-warning
            text     = |Artikel { ls_data-PZN } ist gesperrt – keine Änderung| )
        ) TO reported-SortimentsReport.
        CONTINUE.
      ENDIF.

      " 3. Soll-Modul übernehmen, Sperre NICHT setzen
      MODIFY ENTITIES OF ZC_SortimentssteuerungReport
        ENTITY SortimentsReport
        UPDATE FIELDS ( CurrentModule ModuleLocked ModuleLastChangedDate )
        WITH VALUE #( (
          %key                  = lv_key
          CurrentModule         = ls_data-RecommendedModule_12W
          ModuleLocked          = abap_false
          ModuleLastChangedDate = cl_abap_context_info=>get_system_date( )
        ) ).

      " 4. Log
      write_log(
        iv_matnr      = ls_data-MaterialNumber
        iv_old_module = ls_data-CurrentModule
        iv_new_module = ls_data-RecommendedModule_12W
        iv_reason     = 'UI: Merkmal übernehmen (variabel)' ).

      " 5. Ergebnis zurückgeben
      APPEND VALUE #( %key = lv_key ) TO result.

    ENDLOOP.
  ENDMETHOD.


  "*--------------------------------------------------------------------*
  "* ACTION: TakeModuleLocked
  "* UI-Aktion: Soll-Modul gesperrt übernehmen (fixiert)
  "*--------------------------------------------------------------------*
  METHOD TakeModuleLocked.
    LOOP AT keys INTO DATA(lv_key).

      READ ENTITIES OF ZC_SortimentssteuerungReport
        ENTITY SortimentsReport
        FIELDS ( MaterialNumber CurrentModule RecommendedModule_12W ModuleLocked )
        WITH VALUE #( ( %key = lv_key ) )
        RESULT DATA(lt_data).

      CHECK lt_data IS NOT INITIAL.
      DATA(ls_data) = lt_data[ 1 ].

      " Soll-Modul übernehmen, Sperre setzen
      MODIFY ENTITIES OF ZC_SortimentssteuerungReport
        ENTITY SortimentsReport
        UPDATE FIELDS ( CurrentModule ModuleLocked ModuleLastChangedDate )
        WITH VALUE #( (
          %key                  = lv_key
          CurrentModule         = ls_data-RecommendedModule_12W
          ModuleLocked          = abap_true
          ModuleLastChangedDate = cl_abap_context_info=>get_system_date( )
        ) ).

      write_log(
        iv_matnr      = ls_data-MaterialNumber
        iv_old_module = ls_data-CurrentModule
        iv_new_module = ls_data-RecommendedModule_12W
        iv_reason     = 'UI: Merkmal übernehmen (gesperrt)' ).

      APPEND VALUE #( %key = lv_key ) TO result.

    ENDLOOP.
  ENDMETHOD.


  "*--------------------------------------------------------------------*
  "* ACTION: RemoveLock
  "* UI-Aktion: Sperre entfernen
  "*--------------------------------------------------------------------*
  METHOD RemoveLock.
    LOOP AT keys INTO DATA(lv_key).

      READ ENTITIES OF ZC_SortimentssteuerungReport
        ENTITY SortimentsReport
        FIELDS ( MaterialNumber CurrentModule ModuleLocked )
        WITH VALUE #( ( %key = lv_key ) )
        RESULT DATA(lt_data).

      CHECK lt_data IS NOT INITIAL.
      DATA(ls_data) = lt_data[ 1 ].

      IF ls_data-ModuleLocked = abap_false.
        " Kein gesperrtes Modul – nichts tun
        CONTINUE.
      ENDIF.

      " Sperre entfernen
      MODIFY ENTITIES OF ZC_SortimentssteuerungReport
        ENTITY SortimentsReport
        UPDATE FIELDS ( ModuleLocked ModuleLastChangedDate )
        WITH VALUE #( (
          %key                  = lv_key
          ModuleLocked          = abap_false
          ModuleLastChangedDate = cl_abap_context_info=>get_system_date( )
        ) ).

      write_log(
        iv_matnr      = ls_data-MaterialNumber
        iv_old_module = ls_data-CurrentModule
        iv_new_module = ls_data-CurrentModule
        iv_reason     = 'UI: Sperre entfernt' ).

      APPEND VALUE #( %key = lv_key ) TO result.

    ENDLOOP.
  ENDMETHOD.


  "*--------------------------------------------------------------------*
  "* ACTION: DetermineModule  ← BACKGROUND JOB ACTION
  "*
  "* Diese Methode wird vom Application Job Framework aufgerufen.
  "* Sie verarbeitet ALLE nicht gesperrten Artikel und wendet die
  "* Regellogik aus ZCL_SORTMODUL_RULE_ENGINE an.
  "*
  "* Ablauf:
  "*   1. Alle relevanten Artikel lesen (nicht gesperrt)
  "*   2. Je Artikel: read_rule_input → Rule Engine → Ergebnis
  "*   3. Nur geänderte Module schreiben (change_required = X)
  "*   4. Application Log (SLG1) schreiben
  "*   5. Zusammenfassung als Job-Log ausgeben
  "*--------------------------------------------------------------------*
  METHOD DetermineModule.

    " ── 1. Parameter auslesen ─────────────────────────────────────
    " ZA_DetermineModuleParam enthält z.B.:
    "   RUN_MODE : 'FULL' / 'NEW_ONLY' (nur neue Artikel)
    "   WERK     : optional Werk-Filter
    DATA(ls_param) = parameter.  " ZA_DetermineModuleParam

    " ── 2. Alle nicht-gesperrten Artikel lesen ────────────────────
    SELECT matnr, zz1_sortmodul_prd AS current_module,
                  zz1_modulfix_prd  AS module_locked
      FROM ZSORTMODUL_T
      WHERE zz1_modulfix_prd = ''    " nur nicht gesperrte
      INTO TABLE @DATA(lt_candidates).

    IF lt_candidates IS INITIAL.
      " Kein Handlungsbedarf – Job-Log
      MESSAGE |Keine Artikel zur Verarbeitung gefunden| TYPE 'I'.
      RETURN.
    ENDIF.

    " ── 3. Eingaben für Regelmotor aufbereiten ────────────────────
    DATA(lt_input) = read_rule_input(
      CORRESPONDING #( lt_candidates ) ).

    " Bei RUN_MODE = 'NEW_ONLY' nur neue Artikel verarbeiten
    IF ls_param-run_mode = 'NEW_ONLY'.
      DELETE lt_input WHERE is_new_article = abap_false.
    ENDIF.

    " ── 4. Regelmotor ausführen ───────────────────────────────────
    DATA(lt_results) = ZCL_SORTMODUL_RULE_ENGINE=>determine_modules(
      it_articles = lt_input ).

    " ── 5. Nur geänderte Module schreiben ─────────────────────────
    DATA: lv_count_changed  TYPE i VALUE 0,
          lv_count_total    TYPE i VALUE 0,
          lv_count_skipped  TYPE i VALUE 0.

    LOOP AT lt_results INTO DATA(ls_result).
      lv_count_total += 1.

      IF ls_result-change_required = abap_false.
        lv_count_skipped += 1.
        CONTINUE.
      ENDIF.

      " Persistenzschicht aktualisieren
      UPDATE ZSORTMODUL_T
        SET zz1_sortmodul_prd      = @ls_result-recommended_module,
            zz1_sortmodul_date_prd = @( cl_abap_context_info=>get_system_date( ) )
        WHERE matnr = @ls_result-matnr.

      lv_count_changed += 1.

      " Application Log je Änderung
      DATA(ls_old) = lt_candidates[ matnr = ls_result-matnr ]
                     OPTIONAL.
      write_log(
        iv_matnr      = ls_result-matnr
        iv_old_module = ls_old-current_module
        iv_new_module = ls_result-recommended_module
        iv_reason     = ls_result-reason
        iv_jobrun     = abap_true ).

    ENDLOOP.

    " ── 6. Job-Zusammenfassung ausgeben ──────────────────────────
    MESSAGE |Job abgeschlossen: { lv_count_total } Artikel geprüft, | &
            |{ lv_count_changed } Module geändert, | &
            |{ lv_count_skipped } unverändert| TYPE 'I'.

  ENDMETHOD.


  "*--------------------------------------------------------------------*
  "* HILFSMETHODE: Artikel-Daten für Regelmotor aufbereiten
  "* Liest alle benötigten Felder aus Materialstamm und Lieferant
  "*--------------------------------------------------------------------*
  METHOD read_rule_input.
    LOOP AT it_keys INTO DATA(ls_key).

      DATA(ls_inp) = VALUE ZCL_SORTMODUL_RULE_ENGINE=>ty_article_input(
        matnr          = ls_key-matnr
        current_module = ls_key-current_module
        module_locked  = ls_key-module_locked ).

      " PZN aus I_Product (ZZ1-Feld)
      SELECT SINGLE ZZ1_PZN_PRD INTO @ls_inp-pzn
        FROM I_Product WHERE Product = @ls_key-matnr.

      " Lieferant aus Einkaufsinfosatz
      SELECT SINGLE lifnr INTO @ls_inp-lifnr
        FROM eina WHERE matnr = @ls_key-matnr AND loekz = ''.

      IF ls_inp-lifnr IS INITIAL.
        " Kein Lieferantenstamm → Dummy-Flag
        ls_inp-lifnr_dummy = abap_true.
      ELSE.
        " Lieferant gesperrt?
        SELECT SINGLE loevm INTO @ls_inp-loevm
          FROM lfa1 WHERE lifnr = @ls_inp-lifnr.

        " Lieferantenkategorie (Z-Feld oder Klassifizierung)
        SELECT SINGLE ZZ1_LIFKATEGORIE INTO @ls_inp-lifnr_category
          FROM I_Supplier WHERE Supplier = @ls_inp-lifnr.
      ENDIF.

      " Datacare-Status (Z-Feld am Materialstamm)
      SELECT SINGLE ZZ1_DATACARE_STATUS_PRD INTO @ls_inp-datacare_status
        FROM I_Product WHERE Product = @ls_key-matnr.

      " Therapiegruppe (aus Klassifizierung oder Z-Feld)
      SELECT SINGLE ZZ1_THERAPIEGRUPPE_PRD INTO @ls_inp-therapiegruppe
        FROM I_Product WHERE Product = @ls_key-matnr.

      " IFA-Arzneimittel Flag
      SELECT SINGLE ZZ1_IFA_PRD INTO @ls_inp-is_ifa
        FROM I_Product WHERE Product = @ls_key-matnr.

      " Sammel-PZN (Preisansatz-Artikel)
      SELECT SINGLE ZZ1_SAMMEL_PZN_PRD INTO @ls_inp-is_sammel_pzn
        FROM I_Product WHERE Product = @ls_key-matnr.

      " Neuer Artikel (Zugangsdatum < 14 Tage)
      SELECT SINGLE ersda INTO @DATA(lv_ersda)
        FROM mara WHERE matnr = @ls_key-matnr.
      ls_inp-is_new_article = xsdbool(
        lv_ersda >= cl_abap_context_info=>get_system_date( ) - 14 ).

      INSERT ls_inp INTO TABLE rt_input.
    ENDLOOP.
  ENDMETHOD.


  "*--------------------------------------------------------------------*
  "* HILFSMETHODE: Application Log schreiben (SLG1)
  "*--------------------------------------------------------------------*
  METHOD write_log.
    DATA(lv_action) = COND string(
      WHEN iv_jobrun = abap_true THEN 'JOB'
      ELSE 'UI' ).

    " SLG1 Eintrag – Object: ZSORTIMENTSSTEUERUNG
    CALL FUNCTION 'BAL_LOG_MSG_ADD'
      EXPORTING
        i_log_handle = cl_bali_log=>create( )->get_handle( )
        i_s_msg      = VALUE bal_s_msg(
          msgty = 'I'
          msgid = 'ZSORTMODUL'
          msgno = '001'
          msgv1 = iv_matnr
          msgv2 = iv_old_module
          msgv3 = iv_new_module
          msgv4 = CONV #( iv_action ) ).
  ENDMETHOD.

ENDCLASS.
