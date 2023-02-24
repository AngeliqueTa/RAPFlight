CLASS ltd_fields_handler DEFINITION CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES: if_botd_bufdbl_fields_handler.
  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA:
      max_agency_id TYPE /dmo/agency_id VALUE 0.

ENDCLASS.

CLASS ltd_fields_handler IMPLEMENTATION.

  METHOD if_botd_bufdbl_fields_handler~set_readonly_fields.
    CASE entity_name.
      WHEN '/DMO/R_AGENCYTP'.
        CASE operation.
          WHEN if_abap_behv=>op-m-create.
            TYPES: ty_create_instances TYPE TABLE FOR CREATE /dmo/r_agencytp.
            FIELD-SYMBOLS: <create_instances> TYPE ty_create_instances.
            ASSIGN instances TO <create_instances>.
            LOOP AT <create_instances> ASSIGNING FIELD-SYMBOL(<instance>).
              max_agency_id += 1.
              <instance>-agencyid = max_agency_id.
            ENDLOOP.
        ENDCASE.
    ENDCASE.
  ENDMETHOD.

ENDCLASS.



"! Using RAP BO TDF: Transactional buffer double variant
CLASS ltcl_agency_w_rap_tdf DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CONSTANTS:
      cv_bdef_name TYPE abp_root_entity_name VALUE '/DMO/R_AgencyTP' ##NO_TEXT.

    CLASS-DATA:
      environment TYPE REF TO if_botd_txbufdbl_bo_test_env.

    CLASS-METHODS:
      class_setup,
      class_teardown.

    METHODS:
      setup,
      teardown.

    METHODS:
      "! Checks if { @link ..lhc_agency.METH:validatecountry } behaves correctly
      "! for all valid combinations.
      validatecountry_valid FOR TESTING RAISING cx_static_check,

      "! Checks if { @link ..lhc_agency.METH:validatecountry } behaves correctly
      "! for all invalid combinations.
      validatecountry_invalidnumber FOR TESTING RAISING cx_static_check,

      "! Checks if { @link ..lhc_agency.METH:determineDiallingCode } behaves correctly
      "! for all combinations.
      determinecountrycode FOR TESTING RAISING cx_static_check,

      "! Checks if { @link ..lhc_agency.METH:determineCountryCode } behaves correctly
      "! for all combinations.
      determinediallingcode FOR TESTING RAISING cx_static_check,

      "! Checks if { @link ..lhc_agency.METH:createFromTemplate } does a proper
      "! copy of a given instance.
      createfromtemplate_valid FOR TESTING RAISING cx_static_check,

      "! Checks if { @link ..lhc_agency.METH:createFromTemplate }
      "! returns failed for a non-existing instance
      createfromtemplate_invalid FOR TESTING RAISING cx_static_check.

    DATA:
      class_under_test TYPE REF TO lhc_agency,
      double_agency    TYPE REF TO if_botd_txbufdbl_test_double.

ENDCLASS.


CLASS ltcl_agency_w_rap_tdf IMPLEMENTATION.

  METHOD class_setup.
    DATA(env_config) = cl_botd_txbufdbl_bo_test_env=>prepare_environment_config(
                         )->set_bdef_dependencies( VALUE #( ( cv_bdef_name ) )
                         )->handle_draft( VALUE #( ( cv_bdef_name ) ) ).

    environment = cl_botd_txbufdbl_bo_test_env=>create( env_config ).
  ENDMETHOD.

  METHOD class_teardown.
    environment->destroy(  ).
  ENDMETHOD.

  METHOD setup.
    CREATE OBJECT class_under_test FOR TESTING.
    environment->clear_doubles( ).
    double_agency =  environment->get_test_double( cv_bdef_name ).
    double_agency->configure_additional_behavior(  )->set_fields_handler( fields_handler = NEW ltd_fields_handler( ) ).
  ENDMETHOD.

  METHOD teardown.
    double_agency->clear_double( ).
  ENDMETHOD.

  METHOD validatecountry_valid.
    DATA:
      create_instances TYPE TABLE FOR CREATE /dmo/r_agencytp,
      failed           TYPE RESPONSE FOR FAILED LATE /dmo/i_agencytp,
      reported         TYPE RESPONSE FOR REPORTED LATE /dmo/i_agencytp.

    create_instances = VALUE #(
        ( phonenumber = '0049123'  countrycode = 'DE' )
        ( phonenumber = '+49123'   countrycode = 'DE' )
        ( phonenumber = ''         countrycode = 'DE' )
        ( phonenumber = '+1123'    countrycode = 'US' )
      ).

    MODIFY ENTITIES OF /dmo/r_agencytp
      ENTITY /dmo/agency
        CREATE FIELDS ( countrycode phonenumber )
          AUTO FILL CID WITH create_instances
        MAPPED DATA(mapped)
        FAILED DATA(create_failed)
        REPORTED DATA(create_reported).

    cl_abap_unit_assert=>assert_initial( create_failed ).
    cl_abap_unit_assert=>assert_initial( create_reported ).
    cl_abap_unit_assert=>assert_not_initial( mapped ).


    class_under_test->validatediallingcode(
        EXPORTING
          keys     = CORRESPONDING #( mapped-/dmo/agency )
        CHANGING
          failed   = failed
          reported = reported
      ).

    cl_abap_unit_assert=>assert_initial( failed ).
    cl_abap_unit_assert=>assert_equals(
        exp = lines( create_instances )
        act = lines( reported-/dmo/agency )
      ).
  ENDMETHOD.

  METHOD validatecountry_invalidnumber.
    TYPES:
      ts_create TYPE STRUCTURE FOR CREATE /dmo/r_agencytp,
      tt_create TYPE TABLE FOR CREATE /dmo/r_agencytp.

    TYPES BEGIN OF ts_agency_test_data.
    INCLUDE TYPE ts_create.
    TYPES t100 LIKE if_t100_message=>t100key.
    TYPES END OF ts_agency_test_data.
    TYPES tt_agency_test_data TYPE STANDARD TABLE OF ts_agency_test_data.

    DATA:
      agency_test_data          TYPE tt_agency_test_data,
      reported                  TYPE RESPONSE FOR REPORTED LATE  /dmo/i_agencytp,
      reported_with_message     TYPE STRUCTURE FOR REPORTED LATE /dmo/i_agencytp,
      reported_clear_state_area TYPE STRUCTURE FOR REPORTED LATE /dmo/i_agencytp.

    agency_test_data = VALUE #(
        ( %cid = '1' phonenumber = '49'     countrycode = 'DE'  t100 = CORRESPONDING #( /dmo/zz_cx_agency_country=>number_invalid      ) )
        ( %cid = '2' phonenumber = '49'     countrycode = 'D'   t100 = CORRESPONDING #( /dmo/zz_cx_agency_country=>number_invalid      ) )
        ( %cid = '3' phonenumber = '+49'    countrycode = 'D'   t100 = CORRESPONDING #( /dmo/zz_cx_agency_country=>combination_invalid ) )
        ( %cid = '4' phonenumber = '008955' countrycode = 'DE'  t100 = CORRESPONDING #( /dmo/zz_cx_agency_country=>combination_invalid ) )
      ).

    MODIFY ENTITIES OF /dmo/r_agencytp
      ENTITY /dmo/agency
        CREATE FIELDS ( countrycode phonenumber )
          AUTO FILL CID WITH CORRESPONDING #( agency_test_data )
        MAPPED DATA(mapped)
        FAILED DATA(create_failed)
        REPORTED DATA(create_reported).

    cl_abap_unit_assert=>assert_initial( create_failed ).
    cl_abap_unit_assert=>assert_initial( create_reported ).
    cl_abap_unit_assert=>assert_not_initial( mapped ).

    LOOP AT agency_test_data ASSIGNING FIELD-SYMBOL(<agency>).
      DATA(agencyid) = VALUE #( mapped-/dmo/agency[ %cid = <agency>-%cid ]-agencyid OPTIONAL ).
      cl_abap_unit_assert=>assert_not_initial( agencyid ).
      <agency>-agencyid = agencyid.
    ENDLOOP.

    class_under_test->validatediallingcode(
      EXPORTING
        keys     = CORRESPONDING #( agency_test_data MAPPING agencyid = agencyid EXCEPT * )
      CHANGING
        reported = reported
    ).

    cl_abap_unit_assert=>assert_not_initial( act = reported ).
    cl_abap_unit_assert=>assert_equals(
        msg = 'Reported has not the correct amount of messages'
        exp = 2 * lines( agency_test_data )
        act = lines( reported-/dmo/agency )
        quit = if_abap_unit_constant=>quit-no
      ).

    LOOP AT agency_test_data INTO DATA(agency).
      CLEAR: reported_with_message, reported_clear_state_area.

      LOOP AT reported-/dmo/agency INTO DATA(reported_line) USING KEY entity WHERE agencyid = agency-agencyid.
        IF reported_line-%msg IS BOUND.
          reported_with_message     = reported_line.
        ELSE.
          reported_clear_state_area = reported_line.
        ENDIF.

        cl_abap_unit_assert=>assert_equals(
            exp = lhc_agency=>validate_dialling_code
            act = reported_line-%state_area
          ).
        cl_abap_unit_assert=>assert_equals(
             exp = agency-agencyid
             act = reported_line-agencyid
           ).
        cl_abap_unit_assert=>assert_equals(
            exp = if_abap_behv=>mk-off
            act = reported_line-%is_draft
          ).
      ENDLOOP.

      cl_abap_unit_assert=>assert_not_initial( act = reported_with_message      msg = |Message not found for Agency {          agency-agencyid }!| ).
      cl_abap_unit_assert=>assert_not_initial( act = reported_clear_state_area  msg = |Invalidate State not found for Agency { agency-agencyid }!| ).

      "check message
      cl_abap_unit_assert=>assert_equals(
          exp = if_abap_behv=>mk-on
          act = reported_with_message-%element-phonenumber
        ).
      DATA(elements) = reported_with_message-%element.
      elements-phonenumber = if_abap_behv=>mk-off.
      cl_abap_unit_assert=>assert_initial( elements ).

      cl_abap_unit_assert=>assert_equals(
          exp = agency-t100
          act = reported_with_message-%msg->if_t100_message~t100key
        ).
    ENDLOOP.

  ENDMETHOD.


  METHOD determinecountrycode.
    TYPES:
      ts_create TYPE STRUCTURE FOR CREATE /dmo/r_agencytp,
      tt_create TYPE TABLE FOR CREATE /dmo/r_agencytp.

    TYPES BEGIN OF ts_agency_test_data.
    INCLUDE TYPE ts_create.
    TYPES exp_country_code TYPE /dmo/agency-country_code.
    TYPES END OF ts_agency_test_data.
    TYPES tt_agency_test_data TYPE STANDARD TABLE OF ts_agency_test_data.

    DATA:
      agency_test_data          TYPE tt_agency_test_data,
      agency_mock_data          TYPE TABLE FOR CREATE /dmo/r_agencytp,
      reported                  TYPE RESPONSE FOR REPORTED LATE  /dmo/i_agencytp,
      reported_with_message     TYPE STRUCTURE FOR REPORTED LATE /dmo/i_agencytp,
      reported_clear_state_area TYPE STRUCTURE FOR REPORTED LATE /dmo/i_agencytp.

    agency_test_data = VALUE #(
        ( %cid = '1' phonenumber = '+49 1234'    countrycode = 'EN'  exp_country_code = 'EN' )
        ( %cid = '2' phonenumber = '+49 1234'                        exp_country_code = 'DE' )
        ( %cid = '3' phonenumber = '0049 1234'                       exp_country_code = 'DE' )
        ( %cid = '4' phonenumber = '0089 1234'                       exp_country_code = ''   )
        ( %cid = '5' phonenumber = '+89 1234'                        exp_country_code = ''   )
        ( %cid = '6' phonenumber = '+1 1234'                         exp_country_code = 'US' )
        ( %cid = '7' phonenumber = '+358 1234'                       exp_country_code = 'FI' )
      ).

    MODIFY ENTITIES OF /dmo/r_agencytp
      ENTITY /dmo/agency
        CREATE FIELDS ( countrycode phonenumber )
          AUTO FILL CID WITH CORRESPONDING #( agency_test_data )
        MAPPED DATA(mapped)
        FAILED DATA(create_failed)
        REPORTED DATA(create_reported).

    cl_abap_unit_assert=>assert_initial( create_failed ).
    cl_abap_unit_assert=>assert_initial( create_reported ).
    cl_abap_unit_assert=>assert_not_initial( mapped ).

    LOOP AT agency_test_data ASSIGNING FIELD-SYMBOL(<agency>).
      DATA(agencyid) = VALUE #( mapped-/dmo/agency[ %cid = <agency>-%cid ]-agencyid OPTIONAL ).
      cl_abap_unit_assert=>assert_not_initial( agencyid ).
      <agency>-agencyid = agencyid.
    ENDLOOP.

    class_under_test->determinecountrycode(
      EXPORTING
        keys     = CORRESPONDING #( agency_test_data MAPPING agencyid = agencyid EXCEPT * )
      CHANGING
        reported = reported
    ).

    cl_abap_unit_assert=>assert_initial( act = reported ).

    READ ENTITIES OF /dmo/i_agencytp IN LOCAL MODE
        ENTITY /dmo/agency
          FIELDS ( countrycode ) WITH CORRESPONDING #( agency_test_data MAPPING agencyid = agencyid EXCEPT * )
        RESULT DATA(agencies_afterwards).

    cl_abap_unit_assert=>assert_equals(
        exp = lines( agency_test_data )
        act = lines( agencies_afterwards )
      ).

    LOOP AT agency_test_data INTO DATA(agency).
      cl_abap_unit_assert=>assert_equals(
          exp = agency-exp_country_code
          act = agencies_afterwards[ KEY entity  agencyid = agency-agencyid ]-countrycode
        ).
    ENDLOOP.
  ENDMETHOD.


  METHOD determinediallingcode.
    TYPES:
      ts_create TYPE STRUCTURE FOR CREATE /dmo/r_agencytp,
      tt_create TYPE TABLE FOR CREATE /dmo/r_agencytp.

    TYPES BEGIN OF ts_agency_test_data.
    INCLUDE TYPE ts_create.
    TYPES exp_phone_number TYPE /dmo/agency-phone_number.
    TYPES END OF ts_agency_test_data.
    TYPES tt_agency_test_data TYPE STANDARD TABLE OF ts_agency_test_data.

    DATA:
      agency_test_data          TYPE tt_agency_test_data,
      agency_mock_data          TYPE TABLE FOR CREATE /dmo/r_agencytp,
      reported                  TYPE RESPONSE FOR REPORTED LATE  /dmo/i_agencytp,
      reported_with_message     TYPE STRUCTURE FOR REPORTED LATE /dmo/i_agencytp,
      reported_clear_state_area TYPE STRUCTURE FOR REPORTED LATE /dmo/i_agencytp.

    agency_test_data = VALUE #(
        ( %cid = '1' countrycode = 'EN'  phonenumber = '+49'   exp_phone_number = '+49'  )
        ( %cid = '2' countrycode = 'EN'  phonenumber = '0049'  exp_phone_number = '0049' )
        ( %cid = '3' countrycode = 'DE'                        exp_phone_number = '+49'  )
        ( %cid = '4' countrycode = 'XX'                        exp_phone_number = '' )
      ).

    MODIFY ENTITIES OF /dmo/r_agencytp
      ENTITY /dmo/agency
        CREATE FIELDS ( countrycode phonenumber )
          AUTO FILL CID WITH CORRESPONDING #( agency_test_data )
        MAPPED DATA(mapped)
        FAILED DATA(create_failed)
        REPORTED DATA(create_reported).

    cl_abap_unit_assert=>assert_initial( create_failed ).
    cl_abap_unit_assert=>assert_initial( create_reported ).
    cl_abap_unit_assert=>assert_not_initial( mapped ).

    LOOP AT agency_test_data ASSIGNING FIELD-SYMBOL(<agency>).
      DATA(agencyid) = VALUE #( mapped-/dmo/agency[ %cid = <agency>-%cid ]-agencyid OPTIONAL ).
      cl_abap_unit_assert=>assert_not_initial( agencyid ).
      <agency>-agencyid = agencyid.
    ENDLOOP.

    class_under_test->determinediallingcode(
      EXPORTING
        keys     = CORRESPONDING #( agency_test_data MAPPING agencyid = agencyid EXCEPT * )
      CHANGING
        reported = reported
    ).

    cl_abap_unit_assert=>assert_initial( act = reported ).

    READ ENTITIES OF /dmo/i_agencytp IN LOCAL MODE
        ENTITY /dmo/agency
          FIELDS ( phonenumber ) WITH CORRESPONDING #( agency_test_data MAPPING agencyid = agencyid EXCEPT * )
        RESULT DATA(agencies_afterwards).

    cl_abap_unit_assert=>assert_equals(
        exp = lines( agency_test_data )
        act = lines( agencies_afterwards )
      ).

    LOOP AT agency_test_data INTO DATA(agency).
      cl_abap_unit_assert=>assert_equals(
          exp = agency-exp_phone_number
          act = agencies_afterwards[ KEY entity  agencyid = agency-agencyid ]-phonenumber
        ).
    ENDLOOP.
  ENDMETHOD.

  METHOD createfromtemplate_valid.
    CONSTANTS:
      cid TYPE abp_behv_cid VALUE 'Test'.
    DATA:
      agency_to_test TYPE STRUCTURE FOR CREATE /DMO/R_AgencyTP,
      agency_mock_data TYPE TABLE for CREATE /DMO/R_AgencyTP,
      mapped           TYPE RESPONSE FOR MAPPED EARLY /dmo/i_agencytp,
      reported         TYPE RESPONSE FOR REPORTED EARLY /dmo/i_agencytp,
      failed           TYPE RESPONSE FOR FAILED EARLY /dmo/i_agencytp.

    agency_to_test = VALUE #(
        name         = 'Test'
        street       = 'Street'
        postalcode   = '123'
        city         = 'City'
        countrycode  = 'TE'
        phonenumber  = '+99123'
        emailaddress = 'test@test.test'
        webaddress   = 'test.test'
      ).
    agency_mock_data = VALUE #( ( agency_to_test ) ).

    MODIFY ENTITIES OF /dmo/r_agencytp
      ENTITY /dmo/agency
        CREATE FIELDS ( CountryCode PostalCode City Street )
          AUTO FILL CID WITH agency_mock_data
        MAPPED DATA(create_mapped)
        FAILED DATA(create_failed)
        REPORTED DATA(create_reported).

    cl_abap_unit_assert=>assert_initial( create_failed ).
    cl_abap_unit_assert=>assert_initial( create_reported ).
    cl_abap_unit_assert=>assert_not_initial( create_mapped ).

    class_under_test->createfromtemplate(
        EXPORTING
          keys     = VALUE #(
                         (
                           %cid = cid
                           %is_draft = if_abap_behv=>mk-off
                           agencyid = create_mapped-/dmo/agency[ 1 ]-agencyid
                         )
                       )
        CHANGING
          mapped   = mapped
          failed   = failed
          reported = reported
      ).

    cl_abap_unit_assert=>assert_initial( reported ).
    cl_abap_unit_assert=>assert_initial( failed   ).
    cl_abap_unit_assert=>assert_initial( mapped-/dmo/zz_review ).

    cl_abap_unit_assert=>assert_not_initial( mapped-/dmo/agency ).
    cl_abap_unit_assert=>assert_equals(
        act = lines( mapped-/dmo/agency )
        exp = 1
      ).

    DATA(mapped_line) = mapped-/dmo/agency[ 1 ].
    cl_abap_unit_assert=>assert_equals(
        act = mapped_line-%cid
        exp = cid
      ).
    cl_abap_unit_assert=>assert_equals(
        act = mapped_line-%is_draft
        exp = if_abap_behv=>mk-on
      ).

    READ ENTITIES OF /dmo/i_agencytp
      ENTITY /dmo/agency
        FIELDS (
          name
          street
          postalcode
          city
          countrycode
          phonenumber
          emailaddress
          webaddress
          attachment
          mimetype
          filename
        ) WITH CORRESPONDING #( mapped-/dmo/agency )
      RESULT DATA(copied_agencies).

    cl_abap_unit_assert=>assert_equals(
        act = lines( copied_agencies )
        exp = 1
      ).

    DATA(act_copied_agency) = copied_agencies[ 1 ].
    CLEAR: act_copied_agency-%tky.

    DATA: exp_copied_agency LIKE act_copied_agency.
    exp_copied_agency = CORRESPONDING #( agency_to_test
        MAPPING
          countrycode = countrycode
          postalcode  = postalcode
          city        = city
          street      = street
        EXCEPT *
      ).

    cl_abap_unit_assert=>assert_equals(
        act = act_copied_agency
        exp = exp_copied_agency
      ).
  ENDMETHOD.

  METHOD createfromtemplate_invalid.
    CONSTANTS:
      cid       TYPE abp_behv_cid VALUE 'Test',
      agency_id TYPE /dmo/agency_id VALUE '42'.
    DATA:
      mapped   TYPE RESPONSE FOR MAPPED EARLY /dmo/i_agencytp,
      reported TYPE RESPONSE FOR REPORTED EARLY /dmo/i_agencytp,
      failed   TYPE RESPONSE FOR FAILED EARLY /dmo/i_agencytp.


    class_under_test->createfromtemplate(
        EXPORTING
          keys     = VALUE #(
                         (
                           %cid = cid
                           %is_draft = if_abap_behv=>mk-off
                           agencyid = agency_id
                         )
                       )
        CHANGING
          mapped   = mapped
          failed   = failed
          reported = reported
      ).

    cl_abap_unit_assert=>assert_initial( reported ).
    cl_abap_unit_assert=>assert_initial( mapped ).
    cl_abap_unit_assert=>assert_initial( failed-/dmo/zz_review ).

    cl_abap_unit_assert=>assert_equals(
        act = lines( failed-/dmo/agency )
        exp = 1
      ).

    cl_abap_unit_assert=>assert_equals(
        act = failed-/dmo/agency[ 1 ]-%fail-cause
        exp = if_abap_behv=>cause-not_found
      ).
  ENDMETHOD.

ENDCLASS.






CLASS ltcl_agency_w_cds_tdf DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.

    CLASS-DATA:
      cds_test_environment TYPE REF TO if_cds_test_environment,
      sql_test_environment TYPE REF TO if_osql_test_environment.

    CLASS-METHODS:
      "! Instantiate class under test and set up test double framework
      class_setup,

      "! Destroy test environment and test double
      class_teardown.

    DATA:
      class_under_test TYPE REF TO lhc_agency.

    METHODS:
      "! Reset test double
      setup,

      "! Reset transactional buffer
      teardown.

    METHODS:
      "! Checks if { @link ..lhc_agency.METH:validatecountry } behaves correctly
      "! for all valid combinations.
      validatecountry_valid FOR TESTING RAISING cx_static_check,

      "! Checks if { @link ..lhc_agency.METH:validatecountry } behaves correctly
      "! for all invalid combinations.
      validatecountry_invalidnumber FOR TESTING RAISING cx_static_check,

      "! Checks if { @link ..lhc_agency.METH:determineDiallingCode } behaves correctly
      "! for all combinations.
      determinecountrycode FOR TESTING RAISING cx_static_check,

      "! Checks if { @link ..lhc_agency.METH:determineCountryCode } behaves correctly
      "! for all combinations.
      determinediallingcode FOR TESTING RAISING cx_static_check,

      "! Checks if { @link ..lhc_agency.METH:createFromTemplate } does a proper
      "! copy of a given instance.
      createfromtemplate_valid FOR TESTING RAISING cx_static_check,

      "! Checks if { @link ..lhc_agency.METH:createFromTemplate }
      "! returns failed for a non-existing instance
      createfromtemplate_invalid FOR TESTING RAISING cx_static_check,

      "! Checks that { @link ..lhc_agency.METH:get_global_authorizations } returns initial values
      "! for <em>result</em> and <em>reported</em>.
      get_global_authorizations     FOR TESTING RAISING cx_static_check.
ENDCLASS.


CLASS ltcl_agency_w_cds_tdf IMPLEMENTATION.


  METHOD class_setup.
    cds_test_environment = cl_cds_test_environment=>create(
                             i_for_entity                = '/dmo/i_agencytp'
                             i_select_base_dependencies = abap_true
                           ).
  ENDMETHOD.

  METHOD class_teardown.
    cds_test_environment->destroy( ).
  ENDMETHOD.

  METHOD setup.
    CREATE OBJECT class_under_test FOR TESTING.
    cds_test_environment->clear_doubles( ).
  ENDMETHOD.

  METHOD teardown.
    ROLLBACK ENTITIES.                                 "#EC CI_ROLLBACK
  ENDMETHOD.



  METHOD validatecountry_valid.

    DATA agency_mock_data TYPE STANDARD TABLE OF /dmo/agency.
    agency_mock_data = VALUE #(
        country_code = 'DE'
        ( agency_id = '1' phone_number = '+49'     )
        ( agency_id = '2' phone_number = '0049555' )
        ( agency_id = '3' phone_number = ''        )
      ).
    cds_test_environment->insert_test_data( agency_mock_data ).

    DATA reported TYPE RESPONSE FOR REPORTED LATE  /dmo/i_agencytp.

    class_under_test->validatediallingcode(
      EXPORTING
        keys     = CORRESPONDING #( agency_mock_data MAPPING agencyid = agency_id EXCEPT * )
      CHANGING
        reported = reported
    ).

    cl_abap_unit_assert=>assert_not_initial( msg = 'reported' act = reported ).
    cl_abap_unit_assert=>assert_equals(
        msg = 'Reported has not the correct amount of messages'
        exp = lines( agency_mock_data )
        act = lines( reported-/dmo/agency )
      ).

  ENDMETHOD.

  METHOD validatecountry_invalidnumber.
    TYPES BEGIN OF ts_agency_test_data.
    INCLUDE TYPE /dmo/agency.
    TYPES t100 LIKE if_t100_message=>t100key.
    TYPES END OF ts_agency_test_data.
    TYPES tt_agency_test_data TYPE STANDARD TABLE OF ts_agency_test_data.

    DATA:
      agency_test_data          TYPE tt_agency_test_data,
      agency_mock_data          TYPE STANDARD TABLE OF /dmo/agency,
      reported                  TYPE RESPONSE FOR REPORTED LATE  /dmo/i_agencytp,
      reported_with_message     TYPE STRUCTURE FOR REPORTED LATE /dmo/i_agencytp,
      reported_clear_state_area TYPE STRUCTURE FOR REPORTED LATE /dmo/i_agencytp.

    agency_test_data = VALUE #(
        ( agency_id = '1' phone_number = '49'     country_code = 'DE'  t100 = CORRESPONDING #( /dmo/zz_cx_agency_country=>number_invalid      ) )
        ( agency_id = '2' phone_number = '49'     country_code = 'D'   t100 = CORRESPONDING #( /dmo/zz_cx_agency_country=>number_invalid      ) )
        ( agency_id = '3' phone_number = '+49'    country_code = 'D'   t100 = CORRESPONDING #( /dmo/zz_cx_agency_country=>combination_invalid ) )
        ( agency_id = '4' phone_number = '008955' country_code = 'DE'  t100 = CORRESPONDING #( /dmo/zz_cx_agency_country=>combination_invalid ) )
      ).
    agency_mock_data = CORRESPONDING #( agency_test_data ).
    cds_test_environment->insert_test_data( agency_mock_data ).


    class_under_test->validatediallingcode(
      EXPORTING
        keys     = CORRESPONDING #( agency_test_data MAPPING agencyid = agency_id EXCEPT * )
      CHANGING
        reported = reported
    ).

    cl_abap_unit_assert=>assert_not_initial( act = reported ).
    cl_abap_unit_assert=>assert_equals(
        msg = 'Reported has not the correct amount of messages'
        exp = 2 * lines( agency_test_data )
        act = lines( reported-/dmo/agency )
        quit = if_abap_unit_constant=>quit-no
      ).

    LOOP AT agency_test_data ASSIGNING FIELD-SYMBOL(<agency>).
      CLEAR: reported_with_message, reported_clear_state_area.

      LOOP AT reported-/dmo/agency INTO DATA(reported_line) USING KEY entity WHERE agencyid = <agency>-agency_id.
        IF reported_line-%msg IS BOUND.
          reported_with_message     = reported_line.
        ELSE.
          reported_clear_state_area = reported_line.
        ENDIF.

        cl_abap_unit_assert=>assert_equals(
            exp = lhc_agency=>validate_dialling_code
            act = reported_line-%state_area
          ).
        cl_abap_unit_assert=>assert_equals(
             exp = <agency>-agency_id
             act = reported_line-agencyid
           ).
        cl_abap_unit_assert=>assert_equals(
            exp = if_abap_behv=>mk-off
            act = reported_line-%is_draft
          ).
      ENDLOOP.

      cl_abap_unit_assert=>assert_not_initial( act = reported_with_message      msg = |Message not found for Agency {          <agency>-agency_id }!| ).
      cl_abap_unit_assert=>assert_not_initial( act = reported_clear_state_area  msg = |Invalidate State not found for Agency { <agency>-agency_id }!| ).

      "check message
      cl_abap_unit_assert=>assert_equals(
          exp = if_abap_behv=>mk-on
          act = reported_with_message-%element-phonenumber
        ).
      DATA(elements) = reported_with_message-%element.
      elements-phonenumber = if_abap_behv=>mk-off.
      cl_abap_unit_assert=>assert_initial( elements ).

      cl_abap_unit_assert=>assert_equals(
          exp = <agency>-t100
          act = reported_with_message-%msg->if_t100_message~t100key
        ).
    ENDLOOP.

  ENDMETHOD.


  METHOD determinecountrycode.
    TYPES BEGIN OF ts_agency_test_data.
    INCLUDE TYPE /dmo/agency.
    TYPES exp_country_code TYPE /dmo/agency-country_code.
    TYPES END OF ts_agency_test_data.
    TYPES tt_agency_test_data TYPE STANDARD TABLE OF ts_agency_test_data.

    DATA:
      agency_test_data          TYPE tt_agency_test_data,
      agency_mock_data          TYPE STANDARD TABLE OF /dmo/agency,
      reported                  TYPE RESPONSE FOR REPORTED LATE  /dmo/i_agencytp,
      reported_with_message     TYPE STRUCTURE FOR REPORTED LATE /dmo/i_agencytp,
      reported_clear_state_area TYPE STRUCTURE FOR REPORTED LATE /dmo/i_agencytp.

    agency_test_data = VALUE #(
        ( agency_id = '1' phone_number = '+49 1234'    country_code = 'EN'  exp_country_code = 'EN' )
        ( agency_id = '2' phone_number = '+49 1234'                         exp_country_code = 'DE' )
        ( agency_id = '3' phone_number = '0049 1234'                        exp_country_code = 'DE' )
        ( agency_id = '4' phone_number = '0089 1234'                        exp_country_code = ''   )
        ( agency_id = '5' phone_number = '+89 1234'                         exp_country_code = ''   )
        ( agency_id = '6' phone_number = '+1 1234'                          exp_country_code = 'US' )
        ( agency_id = '7' phone_number = '+358 1234'                        exp_country_code = 'FI' )
      ).
    agency_mock_data = CORRESPONDING #( agency_test_data ).
    cds_test_environment->insert_test_data( agency_mock_data ).

    class_under_test->determinecountrycode(
      EXPORTING
        keys     = CORRESPONDING #( agency_test_data MAPPING agencyid = agency_id EXCEPT * )
      CHANGING
        reported = reported
    ).

    cl_abap_unit_assert=>assert_initial( act = reported ).

    READ ENTITIES OF /dmo/i_agencytp IN LOCAL MODE
        ENTITY /dmo/agency
          FIELDS ( countrycode ) WITH CORRESPONDING #( agency_test_data MAPPING agencyid = agency_id EXCEPT * )
        RESULT DATA(agencies_afterwards).

    cl_abap_unit_assert=>assert_equals(
        exp = lines( agency_test_data )
        act = lines( agencies_afterwards )
      ).

    LOOP AT agency_test_data INTO DATA(agency).
      cl_abap_unit_assert=>assert_equals(
          exp = agency-exp_country_code
          act = agencies_afterwards[ KEY entity  agencyid = agency-agency_id ]-countrycode
        ).
    ENDLOOP.
  ENDMETHOD.


  METHOD determinediallingcode.
    TYPES BEGIN OF ts_agency_test_data.
    INCLUDE TYPE /dmo/agency.
    TYPES exp_phone_number TYPE /dmo/agency-phone_number.
    TYPES END OF ts_agency_test_data.
    TYPES tt_agency_test_data TYPE STANDARD TABLE OF ts_agency_test_data.

    DATA:
      agency_test_data          TYPE tt_agency_test_data,
      agency_mock_data          TYPE STANDARD TABLE OF /dmo/agency,
      reported                  TYPE RESPONSE FOR REPORTED LATE  /dmo/i_agencytp,
      reported_with_message     TYPE STRUCTURE FOR REPORTED LATE /dmo/i_agencytp,
      reported_clear_state_area TYPE STRUCTURE FOR REPORTED LATE /dmo/i_agencytp.

    agency_test_data = VALUE #(
        ( agency_id = '1' country_code = 'EN'  phone_number = '+49'   exp_phone_number = '+49'  )
        ( agency_id = '2' country_code = 'EN'  phone_number = '0049'  exp_phone_number = '0049' )
        ( agency_id = '3' country_code = 'DE'                         exp_phone_number = '+49'  )
        ( agency_id = '4' country_code = 'XX'                         exp_phone_number = '' )
      ).
    agency_mock_data = CORRESPONDING #( agency_test_data ).
    cds_test_environment->insert_test_data( agency_mock_data ).

    class_under_test->determinediallingcode(
      EXPORTING
        keys     = CORRESPONDING #( agency_test_data MAPPING agencyid = agency_id EXCEPT * )
      CHANGING
        reported = reported
    ).

    cl_abap_unit_assert=>assert_initial( act = reported ).

    READ ENTITIES OF /dmo/i_agencytp IN LOCAL MODE
        ENTITY /dmo/agency
          FIELDS ( phonenumber ) WITH CORRESPONDING #( agency_test_data MAPPING agencyid = agency_id EXCEPT * )
        RESULT DATA(agencies_afterwards).

    cl_abap_unit_assert=>assert_equals(
        exp = lines( agency_test_data )
        act = lines( agencies_afterwards )
      ).

    LOOP AT agency_test_data INTO DATA(agency).
      cl_abap_unit_assert=>assert_equals(
          exp = agency-exp_phone_number
          act = agencies_afterwards[ KEY entity  agencyid = agency-agency_id ]-phonenumber
        ).
    ENDLOOP.
  ENDMETHOD.

  METHOD get_global_authorizations.
    DATA:
      requested_authorizations TYPE STRUCTURE FOR GLOBAL AUTHORIZATION REQUEST /dmo/i_agencytp\\/dmo/agency,
      result                   TYPE STRUCTURE FOR GLOBAL AUTHORIZATION RESULT /dmo/i_agencytp\\/dmo/agency,
      reported                 TYPE RESPONSE  FOR REPORTED EARLY /dmo/i_agencytp.

    requested_authorizations-%action-/dmo/createfromtemplate = if_abap_behv=>mk-on.

    class_under_test->get_global_authorizations(
      EXPORTING
        requested_authorizations = requested_authorizations
      CHANGING
        result                   = result
        reported                 = reported
    ).

    cl_abap_unit_assert=>assert_initial( result   ).
    cl_abap_unit_assert=>assert_initial( reported ).
  ENDMETHOD.

  METHOD createfromtemplate_valid.
    CONSTANTS:
      cid TYPE abp_behv_cid VALUE 'Test'.
    DATA:
      agency_mock_data TYPE STANDARD TABLE OF /dmo/agency,
      mapped           TYPE RESPONSE FOR MAPPED EARLY /dmo/i_agencytp,
      reported         TYPE RESPONSE FOR REPORTED EARLY /dmo/i_agencytp,
      failed           TYPE RESPONSE FOR FAILED EARLY /dmo/i_agencytp.

    DATA(agency_to_test) = VALUE /dmo/agency(
        agency_id             = '1'
        name                  = 'Test'
        street                = 'Street'
        postal_code           = '123'
        city                  = 'City'
        country_code          = 'TE'
        phone_number          = '+99123'
        email_address         = 'test@test.test'
        web_address           = 'test.test'
      ).
    agency_mock_data = VALUE #( ( agency_to_test ) ).
    cds_test_environment->insert_test_data( agency_mock_data ).

    class_under_test->createfromtemplate(
        EXPORTING
          keys     = VALUE #(
                         (
                           %cid = cid
                           %is_draft = if_abap_behv=>mk-off
                           agencyid = agency_to_test-agency_id
                         )
                       )
        CHANGING
          mapped   = mapped
          failed   = failed
          reported = reported
      ).

    cl_abap_unit_assert=>assert_initial( reported ).
    cl_abap_unit_assert=>assert_initial( failed   ).
    cl_abap_unit_assert=>assert_initial( mapped-/dmo/zz_review ).

    cl_abap_unit_assert=>assert_not_initial( mapped-/dmo/agency ).
    cl_abap_unit_assert=>assert_equals(
        act = lines( mapped-/dmo/agency )
        exp = 1
      ).

    DATA(mapped_line) = mapped-/dmo/agency[ 1 ].
    cl_abap_unit_assert=>assert_equals(
        act = mapped_line-%cid
        exp = cid
      ).
    cl_abap_unit_assert=>assert_equals(
        act = mapped_line-%is_draft
        exp = if_abap_behv=>mk-on
      ).
    cl_abap_unit_assert=>assert_not_initial( mapped_line-%pid ).

    READ ENTITIES OF /dmo/i_agencytp
      ENTITY /dmo/agency
        FIELDS (
          name
          street
          postalcode
          city
          countrycode
          phonenumber
          emailaddress
          webaddress
          attachment
          mimetype
          filename
          /dmo/zzsloganzag
        ) WITH CORRESPONDING #( mapped-/dmo/agency )
      RESULT DATA(copied_agencies).

    cl_abap_unit_assert=>assert_equals(
        act = lines( copied_agencies )
        exp = 1
      ).

    DATA(act_copied_agency) = copied_agencies[ 1 ].
    CLEAR: act_copied_agency-%tky.

    DATA: exp_copied_agency LIKE act_copied_agency.
    exp_copied_agency = CORRESPONDING #( agency_to_test
        MAPPING
          countrycode = country_code
          postalcode  = postal_code
          city        = city
          street      = street
        EXCEPT *
      ).

    cl_abap_unit_assert=>assert_equals(
        act = act_copied_agency
        exp = exp_copied_agency
      ).
  ENDMETHOD.

  METHOD createfromtemplate_invalid.
    CONSTANTS:
      cid       TYPE abp_behv_cid VALUE 'Test',
      agency_id TYPE /dmo/agency_id VALUE '42'.
    DATA:
      mapped   TYPE RESPONSE FOR MAPPED EARLY /dmo/i_agencytp,
      reported TYPE RESPONSE FOR REPORTED EARLY /dmo/i_agencytp,
      failed   TYPE RESPONSE FOR FAILED EARLY /dmo/i_agencytp.


    class_under_test->createfromtemplate(
        EXPORTING
          keys     = VALUE #(
                         (
                           %cid = cid
                           %is_draft = if_abap_behv=>mk-off
                           agencyid = agency_id
                         )
                       )
        CHANGING
          mapped   = mapped
          failed   = failed
          reported = reported
      ).

    cl_abap_unit_assert=>assert_initial( reported ).
    cl_abap_unit_assert=>assert_initial( mapped ).
    cl_abap_unit_assert=>assert_initial( failed-/dmo/zz_review ).

    cl_abap_unit_assert=>assert_equals(
        act = lines( failed-/dmo/agency )
        exp = 1
      ).

    cl_abap_unit_assert=>assert_equals(
        act = failed-/dmo/agency[ 1 ]-%fail-cause
        exp = if_abap_behv=>cause-not_found
      ).
  ENDMETHOD.

ENDCLASS.
