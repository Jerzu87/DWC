class ZCL_DWC_MANAGER definition
  public
  final
  create public .

public section.

  types:
    begin of m_ty_cart,
      product_id type zdwc_e_prod_id,
      name       type char40,
      quantity   type int4,
      price      type zdwc_e_price,
      waers      type waers,
    end of m_ty_cart .
  types:
    m_tab_cart_type type standard table of m_ty_cart with default key .

  data m_tab_cart type m_tab_cart_type .

  methods GET_PRODUCTS
    returning
      value(rt_tab_products) type zdwc_tab_product .
  methods ADD_TO_CART
    importing
      !iv_var_id type zdwc_e_prod_id
      !iv_var_qty type int4
    exceptions
      INVALID_PRODUCT
      INVALID_QUANTITY .
  methods REMOVE_FROM_CART
    importing
      !iv_var_id type zdwc_e_prod_id
    exceptions
      NOT_FOUND_IN_CART .
  methods CALCULATE_TOTAL
    returning
      value(rv_var_total) type zdwc_e_price .
  methods SAVE_ORDER
    exceptions
      CART_IS_EMPTY
      NUMBER_RANGE_ERROR
      DB_SAVE_ERROR .
protected section.
private section.
ENDCLASS.



CLASS ZCL_DWC_MANAGER IMPLEMENTATION.


  METHOD add_to_cart.
    DATA: ls_str_product TYPE zdwc_str_product,
          ls_str_cart    TYPE m_ty_cart.

    IF iv_var_qty <= 0.
      RAISE invalid_quantity.
    ENDIF.

    " Sprawdz czy produkt istnieje
    SELECT SINGLE * FROM zdwc_products INTO ls_str_product
      WHERE product_id = iv_var_id.
    IF sy-subrc <> 0.
      RAISE invalid_product.
    ENDIF.

    " Sprawdz czy produkt jest w koszyku
    READ TABLE m_tab_cart INTO ls_str_cart WITH KEY product_id = iv_var_id.
    IF sy-subrc = 0.
      " Zaktualizuj ilosc
      ls_str_cart-quantity = ls_str_cart-quantity + iv_var_qty.
      MODIFY m_tab_cart FROM ls_str_cart INDEX sy-tabix.
    ELSE.
      " Dodaj nowy
      ls_str_cart-product_id = ls_str_product-product_id.
      ls_str_cart-name       = ls_str_product-name.
      ls_str_cart-quantity   = iv_var_qty.
      ls_str_cart-price      = ls_str_product-price.
      ls_str_cart-waers      = ls_str_product-waers.
      APPEND ls_str_cart TO m_tab_cart.
    ENDIF.

  ENDMETHOD.


  METHOD calculate_total.
    DATA: ls_str_cart TYPE m_ty_cart,
          lv_var_sum  TYPE zdwc_e_price.

    CLEAR rv_var_total.

    LOOP AT m_tab_cart INTO ls_str_cart.
      lv_var_sum = ls_str_cart-price * ls_str_cart-quantity.
      rv_var_total = rv_var_total + lv_var_sum.
    ENDLOOP.

  ENDMETHOD.


  METHOD get_products.
    SELECT * FROM zdwc_products INTO TABLE rt_tab_products.
  ENDMETHOD.


  METHOD remove_from_cart.
    DELETE m_tab_cart WHERE product_id = iv_var_id.
    IF sy-subrc <> 0.
      RAISE not_found_in_cart.
    ENDIF.
  ENDMETHOD.


  METHOD save_order.
    DATA: ls_str_order_h TYPE zdwc_orders_h,
          ls_str_order_i TYPE zdwc_orders_i,
          lt_tab_order_i TYPE TABLE OF zdwc_orders_i,
          ls_str_cart    TYPE m_ty_cart,
          lv_var_pos     TYPE int4 VALUE 10,
          lv_var_num     TYPE num10.

    IF lines( m_tab_cart ) = 0.
      RAISE cart_is_empty.
    ENDIF.

    " Pobierz nowy numer zamowienia
    CALL FUNCTION 'NUMBER_GET_NEXT'
      EXPORTING
        nr_range_nr             = '01'
        object                  = 'ZZ41_ID'
      IMPORTING
        number                  = lv_var_num
      EXCEPTIONS
        interval_not_found      = 1
        number_range_not_intern = 2
        object_not_found        = 3
        quantity_is_0           = 4
        quantity_is_not_1       = 5
        interval_overflow       = 6
        buffer_overflow         = 7
        OTHERS                  = 8.
    IF sy-subrc <> 0.
      RAISE number_range_error.
    ENDIF.

    " Uzupelnij naglowek
    ls_str_order_h-order_id   = lv_var_num.
    ls_str_order_h-user_id    = sy-uname.
    ls_str_order_h-order_date = sy-datum.
    ls_str_order_h-total_val  = me->calculate_total( ).
    " Zaloz ze pierwsza waluta z koszyka to waluta naglowka (uproszczenie)
    READ TABLE m_tab_cart INTO ls_str_cart INDEX 1.
    IF sy-subrc = 0.
      ls_str_order_h-waers = ls_str_cart-waers.
    ENDIF.

    " Uzupelnij pozycje
    LOOP AT m_tab_cart INTO ls_str_cart.
      ls_str_order_i-order_id   = lv_var_num.
      ls_str_order_i-item_pos   = lv_var_pos.
      ls_str_order_i-product_id = ls_str_cart-product_id.
      ls_str_order_i-quantity   = ls_str_cart-quantity.
      ls_str_order_i-price      = ls_str_cart-price.
      APPEND ls_str_order_i TO lt_tab_order_i.
      lv_var_pos = lv_var_pos + 10.
    ENDLOOP.

    " Zapisz do bazy
    INSERT zdwc_orders_h FROM ls_str_order_h.
    IF sy-subrc <> 0.
      ROLLBACK WORK.
      RAISE db_save_error.
    ENDIF.

    INSERT zdwc_orders_i FROM TABLE lt_tab_order_i.
    IF sy-subrc <> 0.
      ROLLBACK WORK.
      RAISE db_save_error.
    ENDIF.

    COMMIT WORK.
    CLEAR m_tab_cart. " Wyczysc koszyk po zapisie
  ENDMETHOD.
ENDCLASS.
