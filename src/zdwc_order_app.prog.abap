*&---------------------------------------------------------------------*
*& Report ZDWC_ORDER_APP
*&---------------------------------------------------------------------*
*& Aplikacja zamowien DWC
*&---------------------------------------------------------------------*
REPORT zdwc_order_app.

DATA: g_rcl_manager  TYPE REF TO zcl_dwc_manager,
      g_tab_products TYPE zdwc_tab_product,
      g_tab_orders_h TYPE STANDARD TABLE OF zdwc_orders_h.

DATA: g_rcl_cont_0100 TYPE REF TO cl_gui_custom_container,
      g_rcl_alv_0100  TYPE REF TO cl_gui_alv_grid,
      g_rcl_cont_0200 TYPE REF TO cl_gui_custom_container,
      g_rcl_alv_0200  TYPE REF TO cl_gui_alv_grid,
      g_rcl_cont_0300 TYPE REF TO cl_gui_custom_container,
      g_rcl_alv_0300  TYPE REF TO cl_gui_alv_grid.

DATA: g_var_okcode TYPE sy-ucomm.

*----------------------------------------------------------------------*
*       CLASS lcl_events DEFINITION
*----------------------------------------------------------------------*
CLASS lcl_events DEFINITION.
  PUBLIC SECTION.
    METHODS:
      on_double_click_0100 FOR EVENT double_click OF cl_gui_alv_grid
        IMPORTING e_row e_column,
      on_toolbar_0200 FOR EVENT toolbar OF cl_gui_alv_grid
        IMPORTING e_object e_interactive,
      on_user_command_0200 FOR EVENT user_command OF cl_gui_alv_grid
        IMPORTING e_ucomm.
ENDCLASS.                    "lcl_events DEFINITION

*----------------------------------------------------------------------*
*       CLASS lcl_events IMPLEMENTATION
*----------------------------------------------------------------------*
CLASS lcl_events IMPLEMENTATION.
  METHOD on_double_click_0100.
    DATA: ls_str_product TYPE zdwc_str_product,
          lv_var_qty     TYPE int4 VALUE 1. " Domyslnie dodajemy 1 sztuke
    READ TABLE g_tab_products INTO ls_str_product INDEX e_row-index.
    IF sy-subrc = 0.
      g_rcl_manager->add_to_cart(
        EXPORTING
          iv_var_id  = ls_str_product-product_id
          iv_var_qty = lv_var_qty
        EXCEPTIONS
          invalid_product  = 1
          invalid_quantity = 2
          OTHERS           = 3
      ).
      IF sy-subrc = 0.
        MESSAGE 'Dodano produkt do koszyka' TYPE 'S'.
      ELSE.
        MESSAGE 'Blad dodawania do koszyka' TYPE 'E'.
      ENDIF.
    ENDIF.
  METHOD on_toolbar_0200.
    DATA: ls_str_btn TYPE stb_button.
    ls_str_btn-function = 'SAVE_ORDER'.
    ls_str_btn-text     = 'Zloz zamowienie'.
    ls_str_btn-icon     = '@2L@'. " Save icon
    APPEND ls_str_btn TO e_object->mt_toolbar.

    ls_str_btn-function = 'DEL_ITEM'.
    ls_str_btn-text     = 'Usun pozycje'.
    ls_str_btn-icon     = '@11@'. " Delete icon
    APPEND ls_str_btn TO e_object->mt_toolbar.
  ENDMETHOD.

  METHOD on_user_command_0200.
    DATA: lt_tab_rows TYPE lvc_t_row,
          ls_str_row  TYPE lvc_s_row,
          ls_str_cart TYPE zcl_dwc_manager=>m_ty_cart.

    " Ensure edited data in ALV grid is flushed to internal table
    g_rcl_alv_0200->check_changed_data( ).

    CASE e_ucomm.
      WHEN 'SAVE_ORDER'.
        g_rcl_manager->save_order(
          EXCEPTIONS
            cart_is_empty      = 1
            number_range_error = 2
            db_save_error      = 3
            OTHERS             = 4
        ).
        IF sy-subrc = 0.
          MESSAGE 'Zlozono zamowienie pomyslnie' TYPE 'S'.
          g_rcl_alv_0200->refresh_table_display( ).
        ELSE.
          MESSAGE 'Blad podczas skladania zamowienia' TYPE 'E'.
        ENDIF.

      WHEN 'DEL_ITEM'.
        g_rcl_alv_0200->get_selected_rows( IMPORTING et_index_rows = lt_tab_rows ).
        " Sort descending to delete from bottom up, avoiding index shift issues
        SORT lt_tab_rows BY index DESCENDING.
        LOOP AT lt_tab_rows INTO ls_str_row.
          READ TABLE g_rcl_manager->m_tab_cart INTO ls_str_cart INDEX ls_str_row-index.
          IF sy-subrc = 0.
            g_rcl_manager->remove_from_cart(
              EXPORTING
                iv_var_id = ls_str_cart-product_id
              EXCEPTIONS
                not_found_in_cart = 1
                OTHERS            = 2
            ).
          ENDIF.
        ENDLOOP.
        g_rcl_alv_0200->refresh_table_display( ).
    ENDCASE.
  ENDMETHOD.
ENDCLASS.                    "lcl_events IMPLEMENTATION

DATA: g_rcl_events TYPE REF TO lcl_events.

START-OF-SELECTION.
  CREATE OBJECT g_rcl_manager.
  CREATE OBJECT g_rcl_events.
  CALL SCREEN 100.

*&---------------------------------------------------------------------*
*&      Module  STATUS_0100  OUTPUT
*&---------------------------------------------------------------------*
MODULE status_0100 OUTPUT.
  SET PF-STATUS 'STATUS_0100'.
  SET TITLEBAR 'TITLE_0100'.

  IF g_rcl_cont_0100 IS INITIAL.
    CREATE OBJECT g_rcl_cont_0100
      EXPORTING container_name = 'CONT_0100'.
    CREATE OBJECT g_rcl_alv_0100
      EXPORTING i_parent = g_rcl_cont_0100.

    g_tab_products = g_rcl_manager->get_products( ).

    CALL METHOD g_rcl_alv_0100->set_table_for_first_display
      EXPORTING
        i_structure_name = 'ZDWC_STR_PRODUCT'
      CHANGING
        it_outtab        = g_tab_products.

    SET HANDLER g_rcl_events->on_double_click_0100 FOR g_rcl_alv_0100.
  ENDIF.
ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0100  INPUT
*&---------------------------------------------------------------------*
MODULE user_command_0100 INPUT.
  CASE g_var_okcode.
    WHEN 'BACK' OR 'EXIT' OR 'CANC'.
      LEAVE PROGRAM.
    WHEN 'CART'.
      CALL SCREEN 200.
    WHEN 'HIST'.
      CALL SCREEN 300.
  ENDCASE.
  CLEAR g_var_okcode.
ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  STATUS_0200  OUTPUT
*&---------------------------------------------------------------------*
MODULE status_0200 OUTPUT.
  SET PF-STATUS 'STATUS_0200'.
  SET TITLEBAR 'TITLE_0200'.

  IF g_rcl_cont_0200 IS INITIAL.
    CREATE OBJECT g_rcl_cont_0200
      EXPORTING container_name = 'CONT_0200'.
    CREATE OBJECT g_rcl_alv_0200
      EXPORTING i_parent = g_rcl_cont_0200.

    DATA: lt_tab_fcat TYPE lvc_t_fcat,
          ls_str_fcat TYPE lvc_s_fcat.

    " Ręczna definicja Fieldcat dla lokalnej struktury m_ty_cart
    ls_str_fcat-fieldname = 'PRODUCT_ID'. ls_str_fcat-ref_table = 'ZDWC_PRODUCTS'. APPEND ls_str_fcat TO lt_tab_fcat. CLEAR ls_str_fcat.
    ls_str_fcat-fieldname = 'NAME'. ls_str_fcat-ref_table = 'ZDWC_PRODUCTS'. APPEND ls_str_fcat TO lt_tab_fcat. CLEAR ls_str_fcat.
    ls_str_fcat-fieldname = 'QUANTITY'. ls_str_fcat-scrtext_m = 'Ilosc'. ls_str_fcat-edit = 'X'. APPEND ls_str_fcat TO lt_tab_fcat. CLEAR ls_str_fcat.
    ls_str_fcat-fieldname = 'PRICE'. ls_str_fcat-ref_table = 'ZDWC_PRODUCTS'. APPEND ls_str_fcat TO lt_tab_fcat. CLEAR ls_str_fcat.
    ls_str_fcat-fieldname = 'WAERS'. ls_str_fcat-ref_table = 'ZDWC_PRODUCTS'. APPEND ls_str_fcat TO lt_tab_fcat. CLEAR ls_str_fcat.

    CALL METHOD g_rcl_alv_0200->set_table_for_first_display
      CHANGING
        it_outtab       = g_rcl_manager->m_tab_cart
        it_fieldcatalog = lt_tab_fcat.

    SET HANDLER g_rcl_events->on_toolbar_0200 FOR g_rcl_alv_0200.
    SET HANDLER g_rcl_events->on_user_command_0200 FOR g_rcl_alv_0200.
  ENDIF.
  g_rcl_alv_0200->refresh_table_display( ).
ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0200  INPUT
*&---------------------------------------------------------------------*
MODULE user_command_0200 INPUT.
  CASE g_var_okcode.
    WHEN 'BACK' OR 'EXIT' OR 'CANC'.
      LEAVE TO SCREEN 100.
  ENDCASE.
  CLEAR g_var_okcode.
ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  STATUS_0300  OUTPUT
*&---------------------------------------------------------------------*
MODULE status_0300 OUTPUT.
  SET PF-STATUS 'STATUS_0300'.
  SET TITLEBAR 'TITLE_0300'.

  SELECT * FROM zdwc_orders_h INTO TABLE g_tab_orders_h.

  IF g_rcl_cont_0300 IS INITIAL.
    CREATE OBJECT g_rcl_cont_0300
      EXPORTING container_name = 'CONT_0300'.
    CREATE OBJECT g_rcl_alv_0300
      EXPORTING i_parent = g_rcl_cont_0300.

    CALL METHOD g_rcl_alv_0300->set_table_for_first_display
      EXPORTING
        i_structure_name = 'ZDWC_ORDERS_H'
      CHANGING
        it_outtab        = g_tab_orders_h.
  ENDIF.
  g_rcl_alv_0300->refresh_table_display( ).
ENDMODULE.

*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0300  INPUT
*&---------------------------------------------------------------------*
MODULE user_command_0300 INPUT.
  CASE g_var_okcode.
    WHEN 'BACK' OR 'EXIT' OR 'CANC'.
      LEAVE TO SCREEN 100.
  ENDCASE.
  CLEAR g_var_okcode.
ENDMODULE.
