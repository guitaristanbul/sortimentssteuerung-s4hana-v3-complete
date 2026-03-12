***********************************************************************
* ABAP Unit Test : ZCL_SORTMODUL_RULE_ENGINE_TEST
* Zweck          : Unit Tests für Kural Motoru + Customizing Tabellen
*
* Ausführen in ADT:
*   Rechtsklick auf Klasse → Run As → ABAP Unit Test
*   Oder: Strg+Shift+F10
*
* Test-Abdeckung:
*   ✅ Stufe 1: ModuleLocked – keine Änderung
*   ✅ Stufe 2: Nichtsortiment MN (alle 4 Regeln)
*   ✅ Stufe 2: Besorger MB (alle 3 Regeln)
*   ✅ Stufe 2: Neuer Artikel (MN + MB)
*   ✅ Stufe 3: Schwellwert-Abstufung M5→M3, M3→M1
*   ✅ Stufe 3: Schwellwert OK → kein Downgrade
*   ✅ Stufe 3: Keine Sensitivität → unverändert
*   ✅ Customizing Tablo 1: WVZ+Box Zuordnung
*   ✅ Customizing Tablo 2: Schwellwert-Berechnung
***********************************************************************
CLASS zcl_sortmodul_rule_engine_test DEFINITION FINAL
  FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.

    " ── Hilfsmethoden ───────────────────────────────────────────────
    CLASS-METHODS make_article
      IMPORTING
        iv_module       TYPE char2    DEFAULT 'M5'
        iv_locked       TYPE abap_bool DEFAULT abap_false
        iv_lifnr_dummy  TYPE abap_bool DEFAULT abap_false
        iv_loevm        TYPE loevm    DEFAULT space
        iv_dc_status    TYPE char1    DEFAULT space
        iv_new_article  TYPE abap_bool DEFAULT abap_false
        iv_therapiegr   TYPE char3    DEFAULT space
        iv_ifa          TYPE abap_bool DEFAULT abap_false
        iv_sammel_pzn   TYPE abap_bool DEFAULT abap_false
        iv_lifnr_cat    TYPE char2    DEFAULT space
        iv_wvz          TYPE prodgrp  DEFAULT 'PHARM_RX'
        iv_box          TYPE char2    DEFAULT 'A'
        iv_qty_w1_4     TYPE p        DEFAULT 100
      RETURNING
        VALUE(rs_art)   TYPE zcl_sortmodul_rule_engine=>ty_article_input.

    " ── Test Methods: Stufe 1 ────────────────────────────────────────
    METHODS test_locked_no_change          FOR TESTING.

    " ── Test Methods: Stufe 2 – MN ───────────────────────────────────
    METHODS test_mn_lieferant_dummy        FOR TESTING.
    METHODS test_mn_lieferant_gesperrt     FOR TESTING.
    METHODS test_mn_datacare_storniert     FOR TESTING.
    METHODS test_mn_datacare_null          FOR TESTING.
    METHODS test_mn_therapiegruppe_73      FOR TESTING.

    " ── Test Methods: Stufe 2 – MB ───────────────────────────────────
    METHODS test_mb_ifa                    FOR TESTING.
    METHODS test_mb_sammel_pzn             FOR TESTING.
    METHODS test_mb_liefkategorie_5        FOR TESTING.

    " ── Test Methods: Stufe 2 – Neuer Artikel ────────────────────────
    METHODS test_new_article_mn            FOR TESTING.
    METHODS test_new_article_mb            FOR TESTING.

    " ── Test Methods: Stufe 3 – Schwellwert ──────────────────────────
    METHODS test_threshold_m5_downgrade    FOR TESTING.
    METHODS test_threshold_m3_downgrade    FOR TESTING.
    METHODS test_threshold_ok_no_downgrade FOR TESTING.
    METHODS test_threshold_no_sensitiv     FOR TESTING.
    METHODS test_locked_beats_threshold    FOR TESTING.
    METHODS test_mn_beats_threshold        FOR TESTING.

    " ── Test Methods: Batch ──────────────────────────────────────────
    METHODS test_batch_multiple_articles   FOR TESTING.

ENDCLASS.


CLASS zcl_sortmodul_rule_engine_test IMPLEMENTATION.

  "======================================================================
  " HILFSMETHODE: Test-Artikel erstellen
  "======================================================================
  METHOD make_article.
    rs_art = VALUE #(
      matnr          = '000000001234'
      pzn            = '01234567'
      current_module = iv_module
      module_locked  = iv_locked
      lifnr          = '0000100001'
      lifnr_dummy    = iv_lifnr_dummy
      loevm          = iv_loevm
      lifnr_category = iv_lifnr_cat
      datacare_status = iv_dc_status
      is_new_article  = iv_new_article
      therapiegruppe  = iv_therapiegr
      is_ifa          = iv_ifa
      is_sammel_pzn   = iv_sammel_pzn
      wvz             = iv_wvz
      box             = iv_box
      qty_w1_4        = iv_qty_w1_4 ).
  ENDMETHOD.


  "======================================================================
  " STUFE 1: GESPERRTES MODUL
  "======================================================================

  METHOD test_locked_no_change.
    " Gesperrtes Modul M3 → trotz Menge=0 keine Änderung
    DATA(ls_art) = make_article(
      iv_module  = 'M3'
      iv_locked  = abap_true
      iv_qty_w1_4 = 0 ).          " Menge = 0, würde normalerweise abzustufen

    DATA(ls_result) = zcl_sortmodul_rule_engine=>determine_single( ls_art ).

    cl_abap_unit_assert=>assert_equals(
      act = ls_result-recommended_module
      exp = 'M3'
      msg = 'Gesperrtes Modul darf nicht geändert werden' ).

    cl_abap_unit_assert=>assert_false(
      act = ls_result-change_required
      msg = 'change_required muss false sein bei gesperrtem Modul' ).
  ENDMETHOD.


  "======================================================================
  " STUFE 2: NICHTSORTIMENT (MN)
  "======================================================================

  METHOD test_mn_lieferant_dummy.
    DATA(ls_result) = zcl_sortmodul_rule_engine=>determine_single(
      make_article( iv_lifnr_dummy = abap_true iv_module = 'M5' ) ).

    cl_abap_unit_assert=>assert_equals(
      act = ls_result-recommended_module  exp = 'MN'
      msg = 'Dummy-Lieferant → MN' ).
    cl_abap_unit_assert=>assert_true(
      act = ls_result-change_required
      msg = 'Änderung M5→MN erforderlich' ).
  ENDMETHOD.


  METHOD test_mn_lieferant_gesperrt.
    DATA(ls_result) = zcl_sortmodul_rule_engine=>determine_single(
      make_article( iv_loevm = 'X' iv_module = 'M3' ) ).

    cl_abap_unit_assert=>assert_equals(
      act = ls_result-recommended_module  exp = 'MN'
      msg = 'Gesperrter Lieferant → MN' ).
  ENDMETHOD.


  METHOD test_mn_datacare_storniert.
    DATA(ls_result) = zcl_sortmodul_rule_engine=>determine_single(
      make_article( iv_dc_status = 'S' iv_module = 'M5' ) ).

    cl_abap_unit_assert=>assert_equals(
      act = ls_result-recommended_module  exp = 'MN'
      msg = 'Datacare storniert (S) → MN' ).
  ENDMETHOD.


  METHOD test_mn_datacare_null.
    DATA(ls_result) = zcl_sortmodul_rule_engine=>determine_single(
      make_article( iv_dc_status = '0' iv_module = 'M5' ) ).

    cl_abap_unit_assert=>assert_equals(
      act = ls_result-recommended_module  exp = 'MN'
      msg = 'Datacare auf Null (0) → MN' ).
  ENDMETHOD.


  METHOD test_mn_therapiegruppe_73.
    DATA(ls_result) = zcl_sortmodul_rule_engine=>determine_single(
      make_article( iv_therapiegr = '073' iv_module = 'M3' ) ).

    cl_abap_unit_assert=>assert_equals(
      act = ls_result-recommended_module  exp = 'MN'
      msg = 'Therapiegruppe 073 → MN' ).
  ENDMETHOD.


  "======================================================================
  " STUFE 2: BESORGER (MB)
  "======================================================================

  METHOD test_mb_ifa.
    DATA(ls_result) = zcl_sortmodul_rule_engine=>determine_single(
      make_article( iv_ifa = abap_true iv_module = 'M1' ) ).

    cl_abap_unit_assert=>assert_equals(
      act = ls_result-recommended_module  exp = 'MB'
      msg = 'IFA-Arzneimittel → MB' ).
  ENDMETHOD.


  METHOD test_mb_sammel_pzn.
    DATA(ls_result) = zcl_sortmodul_rule_engine=>determine_single(
      make_article( iv_sammel_pzn = abap_true iv_module = 'M3' ) ).

    cl_abap_unit_assert=>assert_equals(
      act = ls_result-recommended_module  exp = 'MB'
      msg = 'Sammel-PZN → MB' ).
  ENDMETHOD.


  METHOD test_mb_liefkategorie_5.
    DATA(ls_result) = zcl_sortmodul_rule_engine=>determine_single(
      make_article( iv_lifnr_cat = '5' iv_module = 'M5' ) ).

    cl_abap_unit_assert=>assert_equals(
      act = ls_result-recommended_module  exp = 'MB'
      msg = 'Lieferantenkategorie 5 → MB' ).
  ENDMETHOD.


  "======================================================================
  " STUFE 2: NEUER ARTIKEL
  "======================================================================

  METHOD test_new_article_mn.
    " Neuer Artikel + Dummy-Lieferant → MN
    DATA(ls_result) = zcl_sortmodul_rule_engine=>determine_single(
      make_article(
        iv_new_article = abap_true
        iv_lifnr_dummy = abap_true
        iv_module      = 'MB' ) ).

    cl_abap_unit_assert=>assert_equals(
      act = ls_result-recommended_module  exp = 'MN'
      msg = 'Neuer Artikel + Dummy → MN' ).
  ENDMETHOD.


  METHOD test_new_article_mb.
    " Neuer Artikel + normaler Lieferant → MB
    DATA(ls_result) = zcl_sortmodul_rule_engine=>determine_single(
      make_article(
        iv_new_article = abap_true
        iv_module      = 'M5' ) ).

    cl_abap_unit_assert=>assert_equals(
      act = ls_result-recommended_module  exp = 'MB'
      msg = 'Neuer Artikel + normaler Lieferant → MB' ).
  ENDMETHOD.


  "======================================================================
  " STUFE 3: SCHWELLWERT-PRÜFUNG
  " HINWEIS: Diese Tests benötigen Mock-Daten in ZSORT_SENSITIV_MAP
  "          und ZSORT_THRESHOLD (oder Test-Double Framework)
  "
  " Für echte Unit Tests: cl_abap_testdouble verwenden
  " Hier: Integrations-Stil mit echten Customizing-Tabellen
  "======================================================================

  METHOD test_threshold_m5_downgrade.
    " Annahme: WVZ=PHARM_RX, Box=A → S1
    "          S1/M5 Schwellwert = 50
    "          Menge = 30 < 50 → M5 → M3
    DATA(ls_result) = zcl_sortmodul_rule_engine=>determine_single(
      make_article(
        iv_module   = 'M5'
        iv_wvz      = 'PHARM_RX'
        iv_box      = 'A'
        iv_qty_w1_4 = 30 ) ).

    cl_abap_unit_assert=>assert_equals(
      act = ls_result-recommended_module  exp = 'M3'
      msg = 'M5 → M3 bei Unterschreitung Schwellwert S1/M5=50, Menge=30' ).
    cl_abap_unit_assert=>assert_true(
      act = ls_result-downgraded
      msg = 'downgraded Flag muss gesetzt sein' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_result-sensitiv_category  exp = 'S1'
      msg = 'Sensitivität S1 erwartet' ).
  ENDMETHOD.


  METHOD test_threshold_m3_downgrade.
    " S1/M3 Schwellwert = 15, Menge = 8 → M3 → M1
    DATA(ls_result) = zcl_sortmodul_rule_engine=>determine_single(
      make_article(
        iv_module   = 'M3'
        iv_wvz      = 'PHARM_RX'
        iv_box      = 'A'
        iv_qty_w1_4 = 8 ) ).

    cl_abap_unit_assert=>assert_equals(
      act = ls_result-recommended_module  exp = 'M1'
      msg = 'M3 → M1 bei Unterschreitung S1/M3=15, Menge=8' ).
  ENDMETHOD.


  METHOD test_threshold_ok_no_downgrade.
    " S1/M5 Schwellwert = 50, Menge = 75 → kein Downgrade
    DATA(ls_result) = zcl_sortmodul_rule_engine=>determine_single(
      make_article(
        iv_module   = 'M5'
        iv_wvz      = 'PHARM_RX'
        iv_box      = 'A'
        iv_qty_w1_4 = 75 ) ).

    cl_abap_unit_assert=>assert_equals(
      act = ls_result-recommended_module  exp = 'M5'
      msg = 'Keine Abstufung wenn Menge >= Schwellwert' ).
    cl_abap_unit_assert=>assert_false(
      act = ls_result-downgraded
      msg = 'downgraded Flag darf nicht gesetzt sein' ).
    cl_abap_unit_assert=>assert_false(
      act = ls_result-change_required
      msg = 'Keine Änderung erforderlich' ).
  ENDMETHOD.


  METHOD test_threshold_no_sensitiv.
    " WVZ ohne Sensitivitäts-Eintrag → Modul unverändert
    DATA(ls_result) = zcl_sortmodul_rule_engine=>determine_single(
      make_article(
        iv_module   = 'M5'
        iv_wvz      = 'UNKNOWN'    " Kein Eintrag in Tablo 1
        iv_box      = 'Z'
        iv_qty_w1_4 = 0 ) ).

    cl_abap_unit_assert=>assert_equals(
      act = ls_result-recommended_module  exp = 'M5'
      msg = 'Ohne Sensitivität → Modul unverändert' ).
    cl_abap_unit_assert=>assert_initial(
      act = ls_result-sensitiv_category
      msg = 'Sensitivitätskategorie leer erwartet' ).
  ENDMETHOD.


  METHOD test_locked_beats_threshold.
    " Gesperrt + Menge=0 → Sperre hat Vorrang vor Schwellwert
    DATA(ls_result) = zcl_sortmodul_rule_engine=>determine_single(
      make_article(
        iv_module   = 'M5'
        iv_locked   = abap_true
        iv_qty_w1_4 = 0 ) ).

    cl_abap_unit_assert=>assert_equals(
      act = ls_result-recommended_module  exp = 'M5'
      msg = 'Sperre hat Vorrang vor Schwellwert-Abstufung' ).
  ENDMETHOD.


  METHOD test_mn_beats_threshold.
    " MN-Sonderfall hat Vorrang vor Schwellwert
    DATA(ls_result) = zcl_sortmodul_rule_engine=>determine_single(
      make_article(
        iv_module      = 'M5'
        iv_lifnr_dummy = abap_true
        iv_qty_w1_4    = 100 ) ).  " Hohe Menge – aber Dummy-Lieferant

    cl_abap_unit_assert=>assert_equals(
      act = ls_result-recommended_module  exp = 'MN'
      msg = 'MN-Sonderfall hat Vorrang vor Schwellwert' ).
  ENDMETHOD.


  "======================================================================
  " BATCH-TEST: Mehrere Artikel auf einmal
  "======================================================================

  METHOD test_batch_multiple_articles.
    DATA(lt_articles) = VALUE zcl_sortmodul_rule_engine=>tt_article_input(
      " Artikel 1: Normal, hoch Menge → kein Downgrade
      ( matnr = '000000000001' current_module = 'M5'
        wvz = 'PHARM_RX' box = 'A' qty_w1_4 = 100 )
      " Artikel 2: Dummy-Lieferant → MN
      ( matnr = '000000000002' current_module = 'M3'
        lifnr_dummy = abap_true )
      " Artikel 3: IFA → MB
      ( matnr = '000000000003' current_module = 'M5'
        is_ifa = abap_true )
      " Artikel 4: Gesperrt → keine Änderung
      ( matnr = '000000000004' current_module = 'M1'
        module_locked = abap_true ) ).

    DATA(lt_results) = zcl_sortmodul_rule_engine=>determine_modules(
      it_articles = lt_articles ).

    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_results )  exp = 4
      msg = '4 Ergebnisse erwartet' ).

    READ TABLE lt_results WITH KEY matnr = '000000000002' INTO DATA(ls_r2).
    cl_abap_unit_assert=>assert_equals(
      act = ls_r2-recommended_module  exp = 'MN'
      msg = 'Artikel 2: Dummy → MN' ).

    READ TABLE lt_results WITH KEY matnr = '000000000003' INTO DATA(ls_r3).
    cl_abap_unit_assert=>assert_equals(
      act = ls_r3-recommended_module  exp = 'MB'
      msg = 'Artikel 3: IFA → MB' ).

    READ TABLE lt_results WITH KEY matnr = '000000000004' INTO DATA(ls_r4).
    cl_abap_unit_assert=>assert_false(
      act = ls_r4-change_required
      msg = 'Artikel 4: Gesperrt → keine Änderung' ).
  ENDMETHOD.

ENDCLASS.
