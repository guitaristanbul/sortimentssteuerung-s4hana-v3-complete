***********************************************************************
* ABAP Class : ZCL_SORTMODUL_RULE_ENGINE
* Version    : 2.0  – Customizing Tabellen integriert
* Zweck      : Kural Motoru – Bestimmt das Sortimentsmodul je Artikel
*
* Regelreihenfolge:
*   Stufe 1 – Sperr-Check          : ModuleLocked → keine Änderung
*   Stufe 2 – Spezialfall-Prüfung  : MN / MB (PPT Slide 2)
*   Stufe 3 – Schwellwert-Prüfung  : WVZ+Box → Sensitivität → Threshold
*                                    Menge < Threshold → Modul abzustufen
*
* Abhängigkeiten:
*   ZCL_SORTMODUL_CUSTO_TABLE1 → WVZ + Box → Sensitivitätskategorie
*   ZCL_SORTMODUL_CUSTO_TABLE2 → Sensitivität + Modul → Schwellwert
***********************************************************************
CLASS zcl_sortmodul_rule_engine DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_article_input,
        matnr              TYPE matnr,
        pzn                TYPE char18,
        current_module     TYPE char2,
        module_locked      TYPE abap_bool,
        " Lieferant
        lifnr              TYPE lifnr,
        loevm              TYPE loevm,
        lifnr_dummy        TYPE abap_bool,
        lifnr_category     TYPE char2,
        " Datacare / Status
        datacare_status    TYPE char1,
        is_new_article     TYPE abap_bool,
        " Therapiegruppe
        therapiegruppe     TYPE char3,
        " IFA / Preisansatz
        is_ifa             TYPE abap_bool,
        is_sammel_pzn      TYPE abap_bool,
        " ── Felder für Schwellwert-Prüfung (Tablo 1+2) ───────────────
        wvz                TYPE prodgrp,   " Warengruppe (aus I_Product)
        box                TYPE char2,     " Box-Ausprägung (A/B/C/D/E)
        qty_w1_4           TYPE p LENGTH 7 DECIMALS 2,  " Menge Wo 1-4
      END OF ty_article_input.

    TYPES:
      BEGIN OF ty_module_result,
        matnr              TYPE matnr,
        recommended_module TYPE char2,
        sensitiv_category  TYPE char2,    " Ermittelte Sensitivität (S1-S4)
        threshold_value    TYPE p LENGTH 7 DECIMALS 2,
        actual_qty         TYPE p LENGTH 7 DECIMALS 2,
        downgraded         TYPE abap_bool," X = Schwellwert-Abstufung
        reason             TYPE string,
        change_required    TYPE abap_bool,
      END OF ty_module_result.

    TYPES:
      tt_article_input  TYPE STANDARD TABLE OF ty_article_input  WITH KEY matnr,
      tt_module_results TYPE STANDARD TABLE OF ty_module_result  WITH KEY matnr.

    CLASS-METHODS determine_modules
      IMPORTING it_articles       TYPE tt_article_input
      RETURNING VALUE(rt_results) TYPE tt_module_results.

    CLASS-METHODS determine_single
      IMPORTING is_article        TYPE ty_article_input
      RETURNING VALUE(rs_result)  TYPE ty_module_result.

  PRIVATE SECTION.

    CLASS-METHODS is_nichtsortiment
      IMPORTING is_art        TYPE ty_article_input
      RETURNING VALUE(rv_yes) TYPE abap_bool.

    CLASS-METHODS is_besorger
      IMPORTING is_art        TYPE ty_article_input
      RETURNING VALUE(rv_yes) TYPE abap_bool.

    CLASS-METHODS apply_threshold_check
      IMPORTING is_art         TYPE ty_article_input
                iv_base_module TYPE char2
      CHANGING  cs_result      TYPE ty_module_result.

    CLASS-METHODS build_mn_reason
      IMPORTING is_art      TYPE ty_article_input
      RETURNING VALUE(rv)   TYPE string.

    CLASS-METHODS build_mb_reason
      IMPORTING is_art      TYPE ty_article_input
      RETURNING VALUE(rv)   TYPE string.

ENDCLASS.


CLASS zcl_sortmodul_rule_engine IMPLEMENTATION.

  METHOD determine_modules.
    LOOP AT it_articles INTO DATA(ls_art).
      INSERT determine_single( ls_art ) INTO TABLE rt_results.
    ENDLOOP.
  ENDMETHOD.


  METHOD determine_single.
    rs_result-matnr      = is_article-matnr.
    rs_result-actual_qty = is_article-qty_w1_4.

    " ══════════════════════════════════════════════════════════════════
    " STUFE 1: Gesperrtes Modul → KEINE Änderung
    " ══════════════════════════════════════════════════════════════════
    IF is_article-module_locked = abap_true.
      rs_result-recommended_module = is_article-current_module.
      rs_result-reason             = |Modul gesperrt – keine Änderung|.
      rs_result-change_required    = abap_false.
      RETURN.
    ENDIF.

    " ══════════════════════════════════════════════════════════════════
    " STUFE 2: Spezialfall-Prüfung MN / MB (PPT Slide 2)
    " Diese haben Vorrang vor der Schwellwert-Logik
    " ══════════════════════════════════════════════════════════════════
    IF is_nichtsortiment( is_article ) = abap_true.
      rs_result-recommended_module = 'MN'.
      rs_result-reason             = build_mn_reason( is_article ).
      rs_result-change_required    = xsdbool( is_article-current_module <> 'MN' ).
      RETURN.
    ENDIF.

    IF is_besorger( is_article ) = abap_true.
      rs_result-recommended_module = 'MB'.
      rs_result-reason             = build_mb_reason( is_article ).
      rs_result-change_required    = xsdbool( is_article-current_module <> 'MB' ).
      RETURN.
    ENDIF.

    IF is_article-is_new_article = abap_true.
      DATA(lv_new_modul) = COND char2(
        WHEN is_article-lifnr_dummy = abap_true
          OR is_article-loevm IS NOT INITIAL
        THEN 'MN' ELSE 'MB' ).
      rs_result-recommended_module = lv_new_modul.
      rs_result-reason             = |Neuer Datacare-Artikel → { lv_new_modul }|.
      rs_result-change_required    = xsdbool( is_article-current_module <> lv_new_modul ).
      RETURN.
    ENDIF.

    " ══════════════════════════════════════════════════════════════════
    " STUFE 3: Schwellwert-Prüfung (Tablo 1 + Tablo 2)
    "
    " Tablo 1: WVZ + Box → Sensitivitätskategorie S1/S2/S3/S4
    " Tablo 2: Sensitivität + Modul → Mindest-Menge/Monat
    "          Ist-Menge Wo1-4 < Schwellwert → Modul abzustufen
    "          M5 → M3 → M1
    " ══════════════════════════════════════════════════════════════════
    apply_threshold_check(
      EXPORTING
        is_art         = is_article
        iv_base_module = is_article-current_module
      CHANGING
        cs_result      = rs_result ).

  ENDMETHOD.


  METHOD apply_threshold_check.

    " ── Schritt 1: Sensitivitätskategorie aus Tablo 1 lesen ──────────
    DATA(lv_sensitiv) = zcl_sortmodul_custo_table1=>get_sensitiv_category(
      iv_wvz = is_art-wvz
      iv_box = is_art-box ).

    cs_result-sensitiv_category = lv_sensitiv.

    IF lv_sensitiv IS INITIAL.
      cs_result-recommended_module = iv_base_module.
      cs_result-reason             = |Keine Sensitivität für WVZ={ is_art-wvz
                                      } Box={ is_art-box } – Modul unverändert|.
      cs_result-change_required    = abap_false.
      RETURN.
    ENDIF.

    " ── Schritt 2: Schwellwert aus Tablo 2 + Abstufung ───────────────
    DATA(ls_check) = zcl_sortmodul_custo_table2=>get_recommended_module(
      iv_current_module  = iv_base_module
      iv_sensitiv        = lv_sensitiv
      iv_actual_qty_w1_4 = is_art-qty_w1_4 ).

    cs_result-recommended_module = ls_check-recommended_module.
    cs_result-threshold_value    = ls_check-threshold_value.
    cs_result-actual_qty         = ls_check-actual_qty.
    cs_result-downgraded         = ls_check-downgraded.
    cs_result-reason             = ls_check-reason.
    cs_result-change_required    = xsdbool(
      iv_base_module <> ls_check-recommended_module ).

  ENDMETHOD.


  METHOD is_nichtsortiment.
    rv_yes = abap_false.
    IF is_art-lifnr_dummy = abap_true.                rv_yes = abap_true. RETURN. ENDIF.
    IF is_art-loevm IS NOT INITIAL.                   rv_yes = abap_true. RETURN. ENDIF.
    IF is_art-datacare_status = 'S'
    OR is_art-datacare_status = '0'.                  rv_yes = abap_true. RETURN. ENDIF.
    IF is_art-therapiegruppe = '073'.                 rv_yes = abap_true. RETURN. ENDIF.
  ENDMETHOD.


  METHOD is_besorger.
    rv_yes = abap_false.
    IF is_art-is_ifa        = abap_true.              rv_yes = abap_true. RETURN. ENDIF.
    IF is_art-is_sammel_pzn = abap_true.              rv_yes = abap_true. RETURN. ENDIF.
    IF is_art-lifnr_category = '5'.                   rv_yes = abap_true. RETURN. ENDIF.
  ENDMETHOD.


  METHOD build_mn_reason.
    rv = COND #(
      WHEN is_art-lifnr_dummy     = abap_true      THEN |MN: Lieferant Dummy (kein Stamm)|
      WHEN is_art-loevm IS NOT INITIAL             THEN |MN: Lieferant gesperrt ({ is_art-loevm })|
      WHEN is_art-datacare_status = 'S'            THEN |MN: Datacare storniert|
      WHEN is_art-datacare_status = '0'            THEN |MN: Artikel auf Null gesetzt|
      WHEN is_art-therapiegruppe  = '073'          THEN |MN: Therapiegruppe 73 (Pflanzenschutz)|
      ELSE                                              |MN: Sonderfall| ).
  ENDMETHOD.


  METHOD build_mb_reason.
    rv = COND #(
      WHEN is_art-is_ifa        = abap_true THEN |MB: IFA-Arzneimittel|
      WHEN is_art-is_sammel_pzn = abap_true THEN |MB: Preisansatz (Sammel-PZN)|
      WHEN is_art-lifnr_category = '5'      THEN |MB: Lieferantenkategorie 5|
      ELSE                                       |MB: Besorger| ).
  ENDMETHOD.

ENDCLASS.
