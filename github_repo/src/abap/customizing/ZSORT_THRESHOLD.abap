***********************************************************************
* DDIC Tabelle : ZSORT_THRESHOLD
* Zweck        : Tablo 2 – Sensitivitätskategorie + Modul → Schwellwert
*                (Mindest-Auftragsmenge pro Monat)
*
* Logik:
*   Ist die tatsächliche Auftragsmenge (Wo 1-4) KLEINER als der
*   Schwellwert, wird das Modul auf die nächste Stufe HERABGESETZT:
*     M5 → M3 → M1
*
* Customizing: SM30 / Fiori "Custom Business Configurations" App
*
* SE11 Definition:
***********************************************************************

* Tabellenname : ZSORT_THRESHOLD
* Tabellentyp  : Transparente Tabelle (Customizing)
* Lieferkl.    : C (Customizing, mandantenabhängig)

* Felder:
*   MANDT        MANDT       Mandant                      (KEY)
*   SENSITIV     CHAR2       Sensitivitätskategorie S1–S4  (KEY)
*   MODUL        CHAR2       Sortimentsmodul M1/M3/M5      (KEY)
*   THRESHOLD    DEC7_2      Mindest-Auftragsmenge/Monat
*   DOWNGRADE_TO CHAR2       Ziel-Modul bei Unterschreitung
*   VALID_FROM   DATS        Gültig ab
*   CHANGED_BY   UNAME       Geändert von
*   CHANGED_AT   TIMESTAMP   Geändert am

***********************************************************************
* ABAP Class : ZCL_SORTMODUL_CUSTO_TABLE2
* Zweck      : Lesen + Cachen der Schwellwert-Tabelle
*              + Modul-Abstufungslogik
***********************************************************************
CLASS zcl_sortmodul_custo_table2 DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_threshold,
        sensitiv     TYPE char2,    " S1 / S2 / S3 / S4
        modul        TYPE char2,    " M1 / M3 / M5
        threshold    TYPE p LENGTH 7 DECIMALS 2,  " Mindestmenge/Monat
        downgrade_to TYPE char2,    " Ziel-Modul bei Unterschreitung
      END OF ty_threshold.

    TYPES tt_threshold TYPE HASHED TABLE OF ty_threshold
      WITH UNIQUE KEY sensitiv modul.

    " Hauptmethode: Soll-Modul auf Basis Menge + Sensitivität bestimmen
    " Gibt das abgestufte Modul zurück wenn Menge < Schwellwert
    CLASS-METHODS get_recommended_module
      IMPORTING
        iv_current_module  TYPE char2          " Aktuelles Modul (M1/M3/M5)
        iv_sensitiv        TYPE char2          " S1/S2/S3/S4
        iv_actual_qty_w1_4 TYPE p              " Tatsächliche Menge Wo 1-4
      RETURNING
        VALUE(rs_result)   TYPE ty_check_result.

    " Alle Schwellwerte lesen
    CLASS-METHODS get_all
      RETURNING
        VALUE(rt_threshold) TYPE tt_threshold.

    TYPES:
      BEGIN OF ty_check_result,
        recommended_module TYPE char2,    " Empfohlenes Modul
        threshold_value    TYPE p LENGTH 7 DECIMALS 2,
        actual_qty         TYPE p LENGTH 7 DECIMALS 2,
        downgraded         TYPE abap_bool, " X = Abstufung erfolgt
        reason             TYPE string,
      END OF ty_check_result.

  PRIVATE SECTION.
    CLASS-DATA gt_cache  TYPE tt_threshold.
    CLASS-DATA gv_loaded TYPE abap_bool.

    CLASS-METHODS load_cache.

    " Nächst-niedrigeres Modul ermitteln
    CLASS-METHODS get_next_lower_module
      IMPORTING iv_modul         TYPE char2
      RETURNING VALUE(rv_lower)  TYPE char2.

ENDCLASS.


CLASS zcl_sortmodul_custo_table2 IMPLEMENTATION.

  METHOD get_recommended_module.
    load_cache( ).

    rs_result-recommended_module = iv_current_module.
    rs_result-actual_qty         = iv_actual_qty_w1_4.
    rs_result-downgraded         = abap_false.

    " Nur M1/M3/M5 werden abgestuft — MB/MN nicht prüfen
    IF iv_current_module NA 'M1M3M5' OR iv_sensitiv IS INITIAL.
      rs_result-reason = |Kein Schwellwert-Check (Modul={ iv_current_module })|.
      RETURN.
    ENDIF.

    " Schwellwert für diese Kombination lesen
    READ TABLE gt_cache
      WITH KEY sensitiv = iv_sensitiv
               modul    = iv_current_module
      INTO DATA(ls_threshold).

    IF sy-subrc <> 0.
      rs_result-reason = |Kein Schwellwert definiert für { iv_sensitiv }/{ iv_current_module }|.
      RETURN.
    ENDIF.

    rs_result-threshold_value = ls_threshold-threshold.

    " Menge UNTER Schwellwert → Modul abzustufen
    IF iv_actual_qty_w1_4 < ls_threshold-threshold.
      rs_result-recommended_module = ls_threshold-downgrade_to.
      rs_result-downgraded         = abap_true.
      rs_result-reason             = |Abstufung: { iv_current_module } → { ls_threshold-downgrade_to }| &
                                     | (Menge { iv_actual_qty_w1_4 } < Schwellwert { ls_threshold-threshold })|.
    ELSE.
      rs_result-reason = |OK: Menge { iv_actual_qty_w1_4} ≥ Schwellwert { ls_threshold-threshold }|.
    ENDIF.

  ENDMETHOD.


  METHOD get_all.
    load_cache( ).
    rt_threshold = gt_cache.
  ENDMETHOD.


  METHOD load_cache.
    CHECK gv_loaded = abap_false.

    SELECT sensitiv, modul, threshold, downgrade_to
      FROM zsort_threshold
      WHERE mandt = @sy-mandt
      INTO CORRESPONDING FIELDS OF TABLE @gt_cache.

    gv_loaded = abap_true.
  ENDMETHOD.


  METHOD get_next_lower_module.
    rv_lower = SWITCH #( iv_modul
      WHEN 'M5' THEN 'M3'
      WHEN 'M3' THEN 'M1'
      WHEN 'M1' THEN 'M1'   " M1 ist Minimum – nicht weiter abzustufen
      ELSE space ).
  ENDMETHOD.

ENDCLASS.


***********************************************************************
* Beispieldaten / Musterbefüllung
*
* Logik:
*   S1 = hochsensitiv → Schwellwerte HOCH (viel Drehung nötig für M5)
*   S4 = niedrigsensitiv → Schwellwerte NIEDRIG (wenig Drehung reicht)
*
* SENSITIV  MODUL  THRESHOLD  DOWNGRADE_TO  Erklärung
* --------  -----  ---------  ------------  ----------------------------
* S1        M5     50         M3            S1-Artikel brauchen 50 Pos/Monat für M5
* S1        M3     15         M1            S1-Artikel brauchen 15 Pos/Monat für M3
* S1        M1      0         M1            M1 ist Minimum
* S2        M5     30         M3
* S2        M3     10         M1
* S2        M1      0         M1
* S3        M5     15         M3
* S3        M3      5         M1
* S3        M1      0         M1
* S4        M5      5         M3            Niedrigsensitiv: wenig Drehung reicht
* S4        M3      2         M1
* S4        M1      0         M1
*
* Beispiel:
*   Artikel WVZ=PHARM_RX, Box=A → S1 (Tablo 1)
*   Aktuelles Modul = M5, Menge Wo1-4 = 40
*   Schwellwert S1/M5 = 50 → 40 < 50 → Abstufung M5→M3 ✓
*
***********************************************************************
