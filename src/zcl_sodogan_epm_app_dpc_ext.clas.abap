class zcl_sodogan_epm_app_dpc_ext definition
  public
  inheriting from zcl_sodogan_epm_app_dpc
  create public .

  public section.
    types: tt_header_data type table of bapi_epm_so_header with default key.
    types: tt_item_data type table of bapi_epm_so_item with default key.
    types: tt_return type standard table of bapiret2 with default key.
    types: tt_range_soid type standard table of bapi_epm_so_id_range with empty key.
*  methods: /iwbep/if_mgw_appl_srv_runtime~get_expanded_entityset redefinition.
  protected section.
    methods: salesorders_get_entityset redefinition.
    methods: salesorders_get_entity redefinition.
    methods: salesorderitems_get_entity redefinition.
    methods: salesorderitems_get_entityset redefinition.
    methods: products_get_entity redefinition.
    methods: products_get_entityset redefinition.


  private section.
    methods get_header_data importing iv_max_rows               type i default 100
                            exporting reference(et_header_data) type tt_header_data.
    methods check_return_messages
      importing
        it_return             type zcl_sodogan_epm_app_dpc_ext=>tt_return
      returning
        value(r_error_exists) type abap_bool.
endclass.



class zcl_sodogan_epm_app_dpc_ext implementation.


  method salesorderitems_get_entity.
    data: lv_vbeln_raw type snwd_so_id.
    data: lv_item_raw type snwd_so_item_pos.
    data: lv_posnr_raw type snwd_so_item_pos.

    data(ls_max_rows) =  value bapi_epm_max_rows( ).
    ls_max_rows-bapimaxrow = 20.

    data(lt_item_data) = value tt_item_data( ).



    call function 'BAPI_EPM_SO_GET_LIST'
      exporting
        max_rows   = ls_max_rows           " EPM: Max row specifictation
      tables
        soitemdata = lt_item_data.

**Can be called with the navigation property
    if line_exists( it_navigation_path[ nav_prop = 'OrderToItem' ] ).
**Now read the source tab for the sales order
      data(lt_tab) = it_navigation_path[ nav_prop = 'OrderToItem' ].
      if line_exists( lt_tab-key_tab[ name = 'SoId' ] )
        and
        line_exists( lt_tab-key_tab[ name = 'SoItemPos' ] )
        .
        lv_vbeln_raw =   lt_tab-key_tab[ name = 'SoId' ]-value.
        lv_vbeln_raw = |{ lv_vbeln_raw  alpha = in } |.

        lv_posnr_raw =   lt_tab-key_tab[ name = 'SoItemPos' ]-value.
        lv_posnr_raw = |{ lv_posnr_raw  alpha = in } |.

      endif.
    endif.


    if ( line_exists( it_key_tab[ name = 'SoId' ] ) ) and
       ( line_exists( it_key_tab[ name = 'SoItemPos' ] ) ).
      lv_vbeln_raw =  it_key_tab[ name = 'SoId' ]-value.
      lv_posnr_raw =  it_key_tab[ name = 'SoItemPos' ]-value.
      lv_vbeln_raw = |{ lv_vbeln_raw  alpha = in } |.
      lv_posnr_raw = |{ lv_posnr_raw  alpha = in } |.
    endif.
    " EPM: Sales Order header data of BOR object 'EpmSalesOrder'

    break-point.

    er_entity = lt_item_data[ so_id = lv_vbeln_raw  so_item_pos = lv_posnr_raw ].

  endmethod.


  method salesorders_get_entity.
*    data: lv_vbeln_raw type snwd_so_id.

    break-point.

    data(lt_header_data) = value tt_header_data( ).
    data(lt_return) = value tt_return(  ).
    data(lt_selections) = value tt_range_soid(  ).

*   data(_exists) = line_exists( it_key_tab[ name = 'SoId' ] ).
    data(exists) = xsdbool( line_exists( it_key_tab[ name = 'SoId' ] ) ).
    if exists eq abap_true.
      data(lv_vbeln) = |{ it_key_tab[ name = 'SoId' ]-value } |.
      lv_vbeln = |{ lv_vbeln  alpha = in } |.
      append value #( sign = 'I' option = 'EQ' low = lv_vbeln ) to lt_selections.
    endif.


    data(lv_test) = cond string( when line_exists( it_key_tab[ name = 'SoId' ] )
                                   then  |{ it_key_tab[ name = 'SoId' ]-value } |
                                    else | | ).


    call function 'BAPI_EPM_SO_GET_LIST'
      tables
        selparamsoid = lt_selections
        soheaderdata = lt_header_data
        return       = lt_return.              " EPM: Sales Order header data of BOR object 'EpmSalesOrder'


    if check_return_messages( lt_return ).
      raise exception type cx_epm_api_exception
        exporting
          textid = cx_epm_api_exception=>gc_no_epm_db_table
*         previous =
*         mv_var1  =
*         mv_var2  =
*         mv_var3  =
*         mv_var4  =
        .
    endif.


    if line_exists( lt_header_data[ so_id = lv_vbeln ] ).
      er_entity = lt_header_data[ so_id = lv_vbeln ].
    else.
      return.
    endif.
  endmethod.


  method get_header_data.

    break-point.

    data: lo_ex                   type ref to cx_epm_exception,
          lv_text                 type sy-msgv1,
          lt_epm_so_id_range      type if_epm_so_header=>tt_sel_par_header_ids,
          lt_epm_buyer_name_range type if_epm_so_header=>tt_sel_par_company_names,
          lt_epm_product_id_range type if_epm_so_header=>tt_sel_par_product_ids,
          li_message_buffer       type ref to if_epm_message_buffer,
          li_epm_so_header        type ref to if_epm_so_header,
          li_epm_so_item          type ref to if_epm_so_item,
          lt_epm_so_header_data   type if_epm_so_header=>tt_node_data,
          lt_epm_so_item_data     type if_epm_so_item=>tt_node_data,
          ls_so_id                type bapi_epm_so_id,
          lt_epm_hdr_node_keys    type if_epm_bo=>tt_node_keys.



    try.
        data(lv_max_rows) = iv_max_rows.
        li_epm_so_header ?=  cl_epm_service_facade=>get_bo( if_epm_so_header=>gc_bo_name ) .


        li_epm_so_header->set_processor_context(
       exporting
         iv_is_business_partner = abap_false
         iv_has_to_be_confirmed = abap_true ).

        break-point.


        " retrieve EPM SO header data according to given selection criteria
        li_epm_so_header->query_by_header(
          exporting
            iv_max_rows              = lv_max_rows
          importing
             et_data                 = lt_epm_so_header_data[] ).


        et_header_data = value #( for ls_header_data in lt_epm_so_header_data ( corresponding #( ls_header_data ) ) ).

      catch cx_epm_api_exception into data(lr_exception).

    endtry.


  endmethod.


  method salesorders_get_entityset.
    constants: number_of_records type i value 10.
    data(ls_max_rows) =  value bapi_epm_max_rows( bapimaxrow = number_of_records ).

    data(lt_return) =  value tt_return(  ).
    data(lt_header_data) = value tt_header_data( ).
    data(lt_item_data) = value tt_item_data(  ).
    data(lt_selection_range) = value tt_range_soid( ).

*"*"Local Interface:
*"  IMPORTING
*"     VALUE(MAX_ROWS) TYPE  BAPI_EPM_MAX_ROWS OPTIONAL
*"  TABLES
*"      SOHEADERDATA STRUCTURE  BAPI_EPM_SO_HEADER OPTIONAL
*"      SOITEMDATA STRUCTURE  BAPI_EPM_SO_ITEM OPTIONAL
*"      SELPARAMSOID STRUCTURE  BAPI_EPM_SO_ID_RANGE OPTIONAL
*"      SELPARAMBUYERNAME STRUCTURE  BAPI_EPM_CUSTOMER_NAME_RANGE
*"       OPTIONAL
*"      SELPARAMPRODUCTID STRUCTURE  BAPI_EPM_PRODUCT_ID_RANGE OPTIONAL
*"      RETURN STRUCTURE  BAPIRET2 OPTIONAL
    call function 'BAPI_EPM_SO_GET_LIST'
      exporting
        max_rows     = value bapi_epm_max_rows( bapimaxrow = 10 )
      tables
        soheaderdata = lt_header_data              " EPM: Sales Order header data of BOR object 'EpmSalesOrder'
        selparamsoid = lt_selection_range
*       soitemdata   = lt_item_data         " EPM: Max row specifictation
        return       = lt_return
      .                  " Return Parameter

    break sodogan.

    if check_return_messages( lt_return ).
      raise exception type cx_epm_api_exception
        exporting
          textid = cx_epm_api_exception=>gc_no_epm_db_table
*         previous =
*         mv_var1  =
*         mv_var2  =
*         mv_var3  =
*         mv_var4  =
        .
    endif.


    et_entityset = value tt_header_data( for ls_header_data in lt_header_data ( ls_header_data ) ).

    "    me->get_header_data(
    "      exporting
    "        iv_max_rows = ls_max_rows-bapimaxrow
    "      importing
    "        et_header_data = data(lt_header_data)
    "    ).

** Append all the results of the header data to entity set
*    et_entityset = value #( for ls_header in lt_header_data ( ls_header ) ).

  endmethod.


  method salesorderitems_get_entityset.
    data(lt_item_data) = value tt_item_data( ).

    data(lt_selections) =  value tt_range_soid(  ).

    break sodogan.

    if line_exists( it_key_tab[ name = 'SoId' ] ) AND line_exists( it_navigation_path[ nav_prop = 'OrderToItem' ] ).
      data(lv_vbeln) = |{ it_key_tab[ name = 'SoId' ]-value } |.
      lv_vbeln = |{ lv_vbeln  alpha = in } |.
      insert value #( sign = 'I' option = 'EQ' low = lv_vbeln )  into  table lt_selections.
    endif.



    call function 'BAPI_EPM_SO_GET_LIST'
    exporting
     max_rows     = value bapi_epm_max_rows( bapimaxrow = 10 )
      tables
        selparamsoid = lt_selections
        soitemdata   = lt_item_data.                 " EPM: Sales Order header data of BOR object 'EpmSalesOrder'



**Can be called with navigation property as well
**Now read the source tab for the sales order
      et_entityset = value tt_item_data( for ls_item in lt_item_data ( ls_item )   ).


  endmethod.


  method products_get_entity.
**Get Single product!
    data: lv_vbeln_raw type snwd_so_id.
    if line_exists( it_key_tab[ name ='ProductId' ] ).
      data(lv_prod_id) =  it_key_tab[ name ='ProductId' ]-value.


      call function 'BAPI_EPM_PRODUCT_GET_DETAIL'
        exporting
          product_id = value bapi_epm_product_id( product_id = lv_prod_id )                  " EPM: Product header data of BOR object SEPM002
        importing
          headerdata = er_entity                " EPM: Product header data of BOR object SEPM002
*    tables
*         conversion_factors =                  " EPM: Product conversion factor data of BOR object SEPM002
*         return     =                  " Return Parameter
        .
      return.

    endif.

    if line_exists( it_navigation_path[ nav_prop = 'ItemToProduct' ] ).
**Now read the source tab for the sales order


      if line_exists( it_key_tab[ name ='SoId' ] ).
        data(lt_item_data) = value tt_item_data( ).
        lv_vbeln_raw =  it_key_tab[ name ='SoId' ]-value.
        lv_vbeln_raw = |{ lv_vbeln_raw  alpha = in } |.



        data(lt_selections) = value if_epm_so_header=>tt_sel_par_header_ids( ( sign = 'I' option = 'EQ' low = lv_vbeln_raw )  ).


        call function 'BAPI_EPM_SO_GET_LIST'
          tables
            selparamsoid = lt_selections
            soitemdata   = lt_item_data.

        if line_exists( lt_item_data[ so_id = lv_vbeln_raw ] ).

          data(lt_filtered) = value tt_item_data( for ls_item_data in lt_item_data ( ls_item_data ) ).

          er_entity = corresponding #( lt_filtered[ 0 ] ).
        endif.
      endif.
    endif.
  endmethod.


  method products_get_entityset.
**Get all the Products
    data(ls_max_rows) = value bapi_epm_max_rows( bapimaxrow = 10 ).
    call function 'BAPI_EPM_PRODUCT_GET_LIST'
      exporting
        max_rows   = ls_max_rows               " Maximum number of lines of hits
      tables
        headerdata = et_entityset                 " EPM: Product header data of BOR object SEPM002
*       selparamproductid     =                  " EPM: BAPI range table for product ids
*       selparamsuppliernames =                  " EPM: BAPI range table for company names
*       selparamcategories    =                  " EPM: Range table for product categories
*       return     =                  " Return Parameter
      .

  endmethod.




  method check_return_messages.

    r_error_exists  =  cond #( when line_exists( it_return[ type = 'E' ] ) or line_exists( it_return[ type = 'A' ]  ) then abap_true
                            else abap_false
                            ).

  endmethod.

endclass.
