***********************************************************************
* DDIC Tabelle : ZSORT_SENSITIV_MAP
* Zweck        : Tablo 1 – WVZ + Box → Sensitivitätskategorie
*
* Customizing: SM30 / Fiori "Custom Business Configurations" App
*
* Beispieldaten:
*   WVZ=PHARM_RX + Box=A → S1 (hochsensitiv)
*   WVZ=PHARM_RX + Box=B → S2
*   WVZ=DIAB     + Box=A → S2
*   WVZ=CARD     + Box=C → S3
*   WVZ=ALLER    + Box=D → S4 (niedrigsensitiv)
*   ...
*
* SE11 Definition:
***********************************************************************

* Tabellenname : ZSORT_SENSITIV_MAP
* Tabellentyp  : Transparente Tabelle (Customizing)
* Lieferkl.    : C (Customizing, mandantenabhängig)

* Felder:
*   MANDT     MANDT        Mandant                    (KEY)
*   WVZ       PRODGRP      Warengruppe / WVZ           (KEY)
*   BOX       CHAR2        Box-Ausprägung (A/B/C/D/E)  (KEY)
*   SENSITIV  CHAR2        Sensitivitätskategorie (S1–S4)
*   VALID_FROM DATS        Gültig ab (optional)
*   CHANGED_BY UNAME       Geändert von
*   CHANGED_AT TIMESTAMP   Geändert am

***********************************************************************
* ABAP Class : ZCL_SORTMODUL_CUSTO_TABLE1
* Zweck      : Lesen + Cachen der Sensitivitäts-Zuordnung
***********************************************************************
CLASS zcl_sortmodul_custo_table1 DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_sensitiv_map,
        wvz      TYPE prodgrp,
        box      TYPE char2,
        sensitiv TYPE char2,     " S1 / S2 / S3 / S4
      END OF ty_sensitiv_map.

    TYPES tt_sensitiv_map TYPE HASHED TABLE OF ty_sensitiv_map
      WITH UNIQUE KEY wvz box.

    " Sensitivitätskategorie für WVZ + Box ermitteln
    CLASS-METHODS get_sensitiv_category
      IMPORTING
        iv_wvz           TYPE prodgrp
        iv_box           TYPE char2
      RETURNING
        VALUE(rv_sensitiv) TYPE char2.   " S1 / S2 / S3 / S4 / leer = nicht gefunden

    " Komplette Tabelle lesen (gecacht)
    CLASS-METHODS get_all
      RETURNING
        VALUE(rt_map) TYPE tt_sensitiv_map.

  PRIVATE SECTION.
    CLASS-DATA gt_cache TYPE tt_sensitiv_map.
    CLASS-DATA gv_loaded TYPE abap_bool.

    CLASS-METHODS load_cache.

ENDCLASS.


CLASS zcl_sortmodul_custo_table1 IMPLEMENTATION.

  METHOD get_sensitiv_category.
    load_cache( ).

    READ TABLE gt_cache
      WITH KEY wvz = iv_wvz box = iv_box
      INTO DATA(ls_entry).

    rv_sensitiv = COND #(
      WHEN sy-subrc = 0 THEN ls_entry-sensitiv
      ELSE space ).                        " Nicht gefunden → kein Schwellwert

  ENDMETHOD.


  METHOD get_all.
    load_cache( ).
    rt_map = gt_cache.
  ENDMETHOD.


  METHOD load_cache.
    CHECK gv_loaded = abap_false.

    SELECT wvz, box, sensitiv
      FROM zsort_sensitiv_map
      WHERE mandt = @sy-mandt
      INTO CORRESPONDING FIELDS OF TABLE @gt_cache.

    gv_loaded = abap_true.
  ENDMETHOD.

ENDCLASS.


***********************************************************************
* SM30 View : V_ZSORT_SENSITIV
* Zweck     : Pflegeoberfläche für ZSORT_SENSITIV_MAP
*
* SE54 → View anlegen → Wartungsdialog generieren
* SM30 → Tabelle pflegen
*
* Felder in der View:
*   WVZ        Warengruppe        F4: T023
*   BOX        Box-Ausprägung     F4: Domäne ZSORT_BOX_DOM (A/B/C/D/E)
*   SENSITIV   Sensitivität       F4: Domäne ZSORT_SENSITIV_DOM (S1/S2/S3/S4)
*   VALID_FROM Gültig ab          Datumfeld
***********************************************************************


***********************************************************************
* Beispieldaten / Musterbefüllung
* (als ABAP Unit Test / Seed-Daten dokumentiert)
***********************************************************************
*
* WVZ          BOX   SENSITIV   Erklärung
* ------------ ----- ---------- ----------------------------------
* PHARM_RX     A     S1         Rx-Pharma, schnelldrehend → hochsensitiv
* PHARM_RX     B     S1         Rx-Pharma, mitteldrehend
* PHARM_RX     C     S2         Rx-Pharma, langsamdrehend
* PHARM_RX     D     S3
* PHARM_RX     E     S4         Rx-Pharma, sehr niedrige Drehung
* DIAB         A     S1         Diabetes, schnelldrehend
* DIAB         B     S2
* DIAB         C     S2
* DIAB         D     S3
* DIAB         E     S4
* CARD         A     S2         Kardio
* CARD         B     S2
* CARD         C     S3
* CARD         D     S3
* CARD         E     S4
* ALLER        A     S2         Allergie
* ALLER        B     S3
* ALLER        C     S3
* ALLER        D     S4
* ALLER        E     S4
* THYRO        A     S2         Schilddrüse
* THYRO        B     S2
* THYRO        C     S3
* THYRO        D     S4
* THYRO        E     S4
*
***********************************************************************
