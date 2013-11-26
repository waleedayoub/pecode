/* 1. PUT THE START AND END DATES OF PROMO PERIODS IN VARIABLES */

%macro CREATE_PROMO_REPORT (CURRENT_PERIOD,PREVIOUS_PERIOD,PE_START_DATE,j);
%LET SPONSOR = 'NSLC','NSLL';
/*%LET PE_START_DATE = 20100101;
%LET j=2;
%LET CURRENT_PERIOD = 201302;
%LET PREVIOUS_PERIOD = 201202;*/

/* 1. PUT THE START AND END DATES OF PROMO PERIODS IN VARIABLES */

/* 1a. Previous Promo Period */
proc sql;
select min(DATE_ID), max(DATE_ID)
           into :PRE_START_DATE, :PRE_END_DATE
from nslc.NSLC_DATE_DIM
where PROMO_PERIOD = &PREVIOUS_PERIOD;
quit;

/* 1a. Current Promo Period */
proc sql;
select min(DATE_ID), max(DATE_ID)
           into: CUR_START_DATE, :CUR_END_DATE
from nslc.NSLC_DATE_DIM
where PROMO_PERIOD = &CURRENT_PERIOD;
quit;

/***********************************************************************/
/* 2. FIRST CREATE THE "SHELL" OF THE REPORT WITH OFFER CODES AND SKUS */

/* 2a. AIR MILES OFFERS - CURRENT PERIOD */
proc sql;
create table promo_AM_&CURRENT_PERIOD as
        select distinct d.CATEGORY_NAME as CATEGORY
                  ,d.SUBCATEGORY_NAME as SUBCATEGORY
                  ,d.SUBSUBCATEGORY_NAME as SUBSUBCATEGORY
                  ,input(compress(put(a.OFFER_START_DATE,YYMMDD10.),'-'),12.) as START_DATE
                  ,input(compress(put(a.OFFER_END_DATE,YYMMDD10.),'-'),12.) as END_DATE
                  ,&CURRENT_PERIOD as PROMO_PERIOD
                  ,a.OFFER_CODE FORMAT=$8.
                  ,a.OFFER_DESC
                  ,b.PRODUCT_MANAGER_NAME as SUPPLIER
                  ,c.VENDOR_NAME as VENDOR
                  ,a.ARTICLE as SKU
                  ,b.PRODUCT_ITEM_DESC as SKU_DESC
                  ,b.SELLING_UNIT_VOLUME as VOLUME_PER_SKU
                  ,b.PRICE_BRAND_DESCR as PRICE_BAND

        from nslc.PROMO_OFFER_DIM as a,
                 nslc.PRODUCT_ITEM_DIM as b,
                 nslc.VENDOR_DIM as c,
                 amrp.wa_NSLC_MERCH_CATS as d
                 
        where a.ARTICLE = b.SKU
        and b.product_group_4_code = d.subsubcategory_code
        and b.VENDOR_KEY = c.VENDOR_KEY
        and input(compress(put(a.OFFER_START_DATE,YYMMDD10.),'-'),12.) >= &CUR_START_DATE
        and input(compress(put(a.OFFER_END_DATE,YYMMDD10.),'-'),12.) <= &CUR_END_DATE
        order by 7,1,2,3,4,5,6,8,9,10,11,12,13,14;
quit;

/* 2b. LTO OFFERS - CURRENT PERIOD */
proc sql;
create table promo_LT_&CURRENT_PERIOD as
        select distinct d.CATEGORY_NAME as CATEGORY
                  ,d.SUBCATEGORY_NAME as SUBCATEGORY
                  ,d.SUBSUBCATEGORY_NAME as SUBSUBCATEGORY
                  ,input(compress(put(a.PROMO_START_DATE,YYMMDD10.),'-'),12.) as START_DATE
                  ,input(compress(put(a.PROMO_END_DATE,YYMMDD10.),'-'),12.) as END_DATE
                  ,&CURRENT_PERIOD as PROMO_PERIOD
                  ,a.PROMO_CODE as OFFER_CODE
                  ,a.ARTICLE_NOTES as OFFER_DESC
                  ,b.PRODUCT_MANAGER_NAME as SUPPLIER
                  ,c.VENDOR_NAME as VENDOR
                  ,b.SKU
                  ,b.PRODUCT_ITEM_DESC as SKU_DESC
                  ,b.SELLING_UNIT_VOLUME as VOLUME_PER_SKU
                  ,b.PRICE_BRAND_DESCR as PRICE_BAND

        from nslc.PROMO_DIM as a,
                 nslc.PRODUCT_ITEM_DIM as b,
                 nslc.VENDOR_DIM as c,
                 amrp.wa_NSLC_MERCH_CATS as d
                 
        where a.PRODUCT_ITEM_KEY = b.PRODUCT_ITEM_KEY
        and b.product_group_4_code = d.subsubcategory_code
        and b.VENDOR_KEY = c.VENDOR_KEY
        and substr(a.PROMO_DESC,1,2) = 'Y_'
        and input(compress(put(a.PROMO_START_DATE,YYMMDD10.),'-'),12.) >= &CUR_START_DATE
        and input(compress(put(a.PROMO_END_DATE,YYMMDD10.),'-'),12.) <= &CUR_END_DATE
        order by 7,1,2,3,4,5,6,7,8,9,10,11,12,13;
quit;

/* 2c. GET RID OF ANY NON-ALCOHOL SKUs - CURRENT PERIOD */
data promo_&CURRENT_PERIOD;
set promo_LT_&CURRENT_PERIOD(in=a) promo_AM_&CURRENT_PERIOD(in=b);
if CATEGORY = 'Non Alcohol' then delete;
AM=b;
run;

/***********************************************************************/
/* 3. ADD THE PREVIOUS YEAR'S PROMOTIONS */

/* need to create a macro in order to keep out previous period promo info if unavailable */

%macro PREPERIOD(i=&j);
        %if &i ne 2 %then %do;
                        /* 3a. AIR MILES OFFERS - PREVIOUS PERIOD */
                        proc sql;
                        create table promo_AM_&PREVIOUS_PERIOD as
                                select distinct a.ARTICLE as SKU
                                                        ,a.OFFER_DESC
                                from nslc.PROMO_OFFER_DIM as a
                                where input(compress(put(a.OFFER_START_DATE,YYMMDD10.),'-'),12.) >= &PRE_START_DATE
                                and input(compress(put(a.OFFER_END_DATE,YYMMDD10.),'-'),12.) <= &PRE_END_DATE
                                order by 1,2;
                        quit;
                        
                        data promo_AM_&PREVIOUS_PERIOD (where = (OFFER_DESC ne ''));
                        set promo_AM_&PREVIOUS_PERIOD;
                        run;
                        proc sort data = promo_AM_&PREVIOUS_PERIOD; by SKU; run;
                        proc transpose data = promo_AM_&PREVIOUS_PERIOD out = promo_AM_&PREVIOUS_PERIOD(drop=_:) prefix=OFFER_DESC;
                                by SKU;
                                var OFFER_DESC;
                        run;
                        
                        data promo_AM_&PREVIOUS_PERIOD;
                        set promo_AM_&PREVIOUS_PERIOD;
                        AM_OFFER_DESC = catx(' // ',of OFFER_DESC:);
                        drop OFFER_DESC:;
                        run;
                        
                        /* 3b. LT OFFERS - PREVIOUS PERIOD */
                        proc sql;
                        create table promo_LT_&PREVIOUS_PERIOD as
                                select distinct b.SKU
                                                ,case when substr(a.PROMO_DESC,1,2) = 'Y_' then a.ARTICLE_NOTES
                                                                        when substr(a.PROMO_DESC,1,2) = 'J_' then 'Cash Area'
                                                                        when substr(a.PROMO_DESC,1,2) = 'E_' then 'Shelf Extender'
                                                                        when substr(a.PROMO_DESC,1,2) = 'O_' then 'On Shelf Promo Space'
                                                                        when substr(a.PROMO_DESC,1,2) = 'P_' then 'Instant Redemption Coupon'
                                                                        when substr(a.PROMO_DESC,1,2) = 'S_' then 'Bonus Buys'
                                                                        when substr(a.PROMO_DESC,1,2) = 'C_' then 'Physical Space - Spirits'
                                                                        when substr(a.PROMO_DESC,1,2) = 'N_' then 'Shelf Talkers/Necktags'
                                                                        when substr(a.PROMO_DESC,1,2) = 'Z_' then 'Clearance'
                                                                        when substr(a.PROMO_DESC,1,2) = 'A_' then 'Physical Space - Beer'
                                                                        when substr(a.PROMO_DESC,1,2) = 'D_' then 'Physical Space - Wine'
                                                                        when substr(a.PROMO_DESC,1,2) = 'B_' then 'Physical Space - RTD'
                                                                        when substr(a.PROMO_DESC,1,2) = 'X_' then 'Added Values'
                                                end as OFFER_DESC
                        
                                from nslc.PROMO_DIM as a,
                                                 nslc.PRODUCT_ITEM_DIM as b
                                where a.PRODUCT_ITEM_KEY = b.PRODUCT_ITEM_KEY
                                and input(compress(put(a.PROMO_START_DATE,YYMMDD10.),'-'),12.) >= &PRE_START_DATE
                                and input(compress(put(a.PROMO_END_DATE,YYMMDD10.),'-'),12.) <= &PRE_END_DATE
                                order by 1,2;
                        quit;
                        
                        data promo_LT_&PREVIOUS_PERIOD (where = (OFFER_DESC ne ''));
                        set promo_LT_&PREVIOUS_PERIOD;
                        keep SKU OFFER_DESC;
                        run;
                        
                        proc transpose data = promo_LT_&PREVIOUS_PERIOD out = promo_LT_&PREVIOUS_PERIOD(drop=_:) prefix=OFFER_DESC;
                                by SKU;
                                var OFFER_DESC;
                        run;
                        proc sort data = promo_LT_&PREVIOUS_PERIOD; by SKU; run;
                        data promo_LT_&PREVIOUS_PERIOD;
                        set promo_LT_&PREVIOUS_PERIOD;
                        LT_OFFER_DESC = catx(' // ',of OFFER_DESC:);
                        drop OFFER_DESC:;
                        run;
                        
                        /* 3c. keep only SKU and PREVIOUS PROMOTION based on PREVIOUS PERIOD    */
                        data promo_&PREVIOUS_PERIOD.;
                        merge promo_AM_&PREVIOUS_PERIOD(in=a) promo_LT_&PREVIOUS_PERIOD(in=b);
                        by SKU;
                        run;
                        
                        data promo_&PREVIOUS_PERIOD.;
                        set promo_&PREVIOUS_PERIOD.;
                        OFFER_DESC_PRE = catx(' // ', AM_OFFER_DESC, LT_OFFER_DESC);
                        drop AM_OFFER_DESC LT_OFFER_DESC;
                        run;
                        
                        /* 3d. Keep only CURRENT PERIOD SKUs and what PREVIOUS PROMO was */
                        proc sort data = promo_&CURRENT_PERIOD; by SKU; run;
                        proc sort data = promo_&PREVIOUS_PERIOD; by SKU; run;
                        
                        data promo_&CURRENT_PERIOD;
                        merge promo_&CURRENT_PERIOD(in=a) promo_&PREVIOUS_PERIOD(in=b);
                        by SKU;
                        if a;
                        run;
        %end;
%mend;
%PREPERIOD;

/*****************************************************************************/
/* 4. GET ALL THE AIR MILES ISSUED AGAINST CURRENT PERIOD'S AIR MILES OFFERS */

/* 4a. PUT ALL THE CURRENT AIR MILES OFFER CODES INTO A MACRO VARIABLE */
proc sql;
select distinct "'" || TRIM(OFFER_CODE) || "'"
           into :AM_OFFER_CODE SEPARATED BY ","
from work.PROMO_AM_&CURRENT_PERIOD;
quit;


/* 4b. GET THE AIR MILES ISSUANCE FOR THIS PERIOD */
proc sql;
        create table promo_miles_&CURRENT_PERIOD as     
                select b.issuance_offer_code as OFFER_CODE
                          ,count(distinct a.collector_key) as RESPONDERS
                          ,sum(a.amrm_earned) as MILES_ISSUED
                          ,sum(a.detail_count) as BONUS_TRS
                from amrp.issuance_fact as a,
                         amrp.issuance_offer_dim as b
                where a.issuance_offer_key = b.issuance_offer_key
                and b.issuance_offer_code in (&AM_OFFER_CODE)
                and b.issuance_offer_sponsor_code in (&SPONSOR)
                group by 1
                order by 1;
QUIT;

/************************************************************************/

/* step i) pull transactions and units moved per SKU by each period */
proc sql;
create table promo_sku_details1 as
select d.OFFER_CODE
          ,d.SKU
          ,d.SKU_DESC

          /* CURRENT PERIOD STATS */
          ,count(distinct case when a.date_id between d.start_date and d.end_date 
                                        then cats(a.pos_trans_id,a.store_location_key,a.pos_till_num,a.date_id,a.trans_time) end) as CUR_TOTAL_trs
          ,sum(case when a.date_id between d.start_date and d.end_date 
                                        then a.QUANTITY_SOLD end) as CUR_TOTAL_units

          ,count(distinct case when a.COLLECTOR_KEY > 0 and (a.date_id between d.start_date and d.end_date) 
                                        then cats(a.pos_trans_id,a.store_location_key,a.pos_till_num,a.date_id,a.trans_time) end) as CUR_AM_trs
          ,sum(case when a.COLLECTOR_KEY > 0 and (a.date_id between d.start_date and d.end_date) 
                                        then a.QUANTITY_SOLD else 0 end) as CUR_AM_units

          /* PREVIOUS PERIOD STATS */
          ,count(distinct case when a.date_id between &PRE_START_DATE and &PRE_END_DATE 
                                        then cats(a.pos_trans_id,a.store_location_key,a.pos_till_num,a.date_id,a.trans_time) end) as PRE_TOTAL_trs
          ,sum(case when a.date_id between &PRE_START_DATE and &PRE_END_DATE 
                                        then a.QUANTITY_SOLD end) as PRE_TOTAL_units

          ,count(distinct case when a.COLLECTOR_KEY > 0 and (a.date_id between &PRE_START_DATE and &PRE_END_DATE) 
                                        then cats(a.pos_trans_id,a.store_location_key,a.pos_till_num,a.date_id,a.trans_time) end) as PRE_AM_trs
          ,sum(case when a.COLLECTOR_KEY > 0 and (a.date_id between &PRE_START_DATE and &PRE_END_DATE) 
                                        then a.QUANTITY_SOLD else 0 end) as PRE_AM_units

          
from nslc.sales_item_fact as a,
         nslc.product_item_dim as b,
         promo_&CURRENT_PERIOD as d
where a.product_item_key = b.product_item_key
and b.sku = d.sku
and a.date_id between &PRE_START_DATE and d.end_date
group by 1,2,3
order by 1,2,3
;
QUIT;


/* step ii) pull unique transaction IDs and #units moved by each SKU for each period 
                                if more than 4 units are sold, group them into 4 */
proc sql;
create table promo_sku_details_&CURRENT_PERIOD as
select d.OFFER_CODE
          ,d.SKU
          ,d.SKU_DESC
          ,cats(a.pos_trans_id,a.store_location_key,a.pos_till_num,a.date_id,a.trans_time) as TXN_ID
          ,case when sum(a.QUANTITY_SOLD) >= 4 then 4 else sum(a.QUANTITY_SOLD) end as CUR_UNITS
 
from nslc.sales_item_fact as a,
         nslc.product_item_dim as b,
         promo_&CURRENT_PERIOD as d
where a.product_item_key = b.product_item_key
and b.sku = d.sku
and a.date_id between d.start_date and d.end_date
group by 1,2,3,4
order by 1,2,3,4
;
QUIT;

proc sql;
create table promo_sku_details_&PREVIOUS_PERIOD as
select d.OFFER_CODE
          ,d.SKU
          ,d.SKU_DESC
          ,cats(a.pos_trans_id,a.store_location_key,a.pos_till_num,a.date_id,a.trans_time) as TXN_ID
          ,case when sum(a.QUANTITY_SOLD) >= 4 then 4 else sum(a.QUANTITY_SOLD) end as PRE_UNITS
 
from nslc.sales_item_fact as a,
         nslc.product_item_dim as b,
         promo_&CURRENT_PERIOD as d
where a.product_item_key = b.product_item_key
and b.sku = d.sku
and a.date_id between &PRE_START_DATE and &PRE_END_DATE
group by 1,2,3,4
order by 1,2,3,4
;
QUIT;

proc sql;
create table promo_sku_details_offer as
select d.OFFER_CODE
          ,cats(a.pos_trans_id,a.store_location_key,a.pos_till_num,a.date_id,a.trans_time) as TXN_ID
          ,case when sum(a.QUANTITY_SOLD) >= 4 then 4 else sum(a.QUANTITY_SOLD) end as OFFER_UNITS
 
from nslc.sales_item_fact as a,
         nslc.product_item_dim as b,
         promo_&CURRENT_PERIOD as d
where a.product_item_key = b.product_item_key
and b.sku = d.sku
and a.date_id between d.start_date and d.end_date
group by 1,2
order by 1,2
;
QUIT;

/* step iii) count the number of transactions per sku/unit combination, i.e. group by units sold
                                this enables a view into how many transactions contained certain # of items */
proc sql;
create table promo_sku_details_&CURRENT_PERIOD as
select OFFER_CODE, SKU, SKU_DESC, CUR_UNITS, count(distinct TXN_ID) as TRS
from promo_sku_details_&CURRENT_PERIOD
group by 1,2,3,4
order by 1,2,3,4;
quit;

proc sql;
create table promo_sku_details_&PREVIOUS_PERIOD as
select OFFER_CODE, SKU, SKU_DESC, PRE_UNITS, count(distinct TXN_ID) as TRS
from promo_sku_details_&PREVIOUS_PERIOD
group by 1,2,3,4
order by 1,2,3,4;
quit;

proc sql;
create table promo_sku_details_offer as
select OFFER_CODE, OFFER_UNITS, count(distinct TXN_ID) as TRS
from promo_sku_details_offer
group by 1,2
order by 1,2;
quit;

/* step iv) transpose the data so that UNITS are on the top row */
proc transpose data= promo_sku_details_&CURRENT_PERIOD out= promo_sku_details_&CURRENT_PERIOD (drop = _NAME_ N: _0) ;
by OFFER_CODE SKU SKU_DESC /* variable that describes the rows */;
var TRS /* variable that is values in the matrix */;
id CUR_UNITS /* variable that describes columns */;
run;
data promo_sku_details_&CURRENT_PERIOD (rename = (_1 = CUR_1 _2 = CUR_2 _3 = CUR_3 _4 = CUR_4));
set promo_sku_details_&CURRENT_PERIOD;
run;

proc transpose data= promo_sku_details_&PREVIOUS_PERIOD out= promo_sku_details_&PREVIOUS_PERIOD (drop = _NAME_ N: _0) ;
by OFFER_CODE SKU SKU_DESC /* variable that describes the rows */;
var TRS /* variable that is values in the matrix */;
id PRE_UNITS /* variable that describes columns */;
run;
data promo_sku_details_&PREVIOUS_PERIOD (rename = (_1 = PRE_1 _2 = PRE_2 _3 = PRE_3 _4 = PRE_4));
set promo_sku_details_&PREVIOUS_PERIOD;
run;

proc transpose data= promo_sku_details_offer out= promo_sku_details_offer (drop = _NAME_ N: _0) ;
by OFFER_CODE /* variable that describes the rows */;
var TRS /* variable that is values in the matrix */;
id OFFER_UNITS /* variable that describes columns */;
run;
data promo_sku_details_offer (rename = (_1 = OFFER_1 _2 = OFFER_2 _3 = OFFER_3 _4 = OFFER_4));
set promo_sku_details_offer;
run;

/*********************************************/

/* STEP 1A: CREATE A TABLE WITH ALL SKUS AND CORRESPONDING WEEK, UNITS, ETC... THAT WERE PROMO'D
                   IN THE CURRENT PERIOD */
proc sql;
select distinct "'" || TRIM(SKU) || "'"
           into :PROMO_SKUS SEPARATED BY ","
from work.PROMO_&CURRENT_PERIOD;
quit;

proc sql;
create table promo_sku_fact as
        select b.SKU
                  ,a.PRODUCT_ITEM_KEY
                  ,c.CATEGORY_NAME
                  ,c.SUBCATEGORY_NAME
                  ,e.PROMO_PERIOD
                  ,e.NSLC_WEEK
                  ,sum(a.QUANTITY_SOLD) as UNITS          
        from nslc.sales_item_fact as a,
                 nslc.product_item_dim as b,
                 amrp.WA_NSLC_MERCH_CATS as c,
                 nslc.NSLC_DATE_DIM as e
        where a.product_item_key = b.product_item_key
        and a.date_id = e.date_id
        and b.product_group_4_code = c.subsubcategory_code
        and b.SKU in (&PROMO_SKUS)
        and a.customer_id = ''
        and e.date_id >= &PE_START_DATE
        group by 1,2,3,4,5,6
        order by 1,2,3,4,5,6;
QUIT;

/* add the merchandise category names */
/* data promo_sku_fact;
/* merge promo_sku_fact amrp.wa_nslc_merch_cats (keep = SUBCATEGORY_NAME CATEGORY_NAME);
/* by SKU;
/* run;

/* STEP 1b: FIX A PROBLEM WITH THE P9 AND P1 IN 2012 AND 2013 CROSSING DATES */
data promo_sku_fact;
set promo_sku_fact;
by SKU;
        temp = lag(UNITS);
        pre_period = lag(PROMO_PERIOD);
        pre_week = lag(NSLC_WEEK);
        if PROMO_PERIOD = 201301 and NSLC_WEEK = 201301 and pre_period = 201209 and pre_week = 201301 then UNITS = UNITS + temp;
        if PROMO_PERIOD = 201209 and NSLC_WEEK = 201301 then delete;

drop temp pre_period pre_week;
run;

/* STEP 1c: ARTIFICIALLY INJECT WEEKS WITH 0 UNIT SALES */

/* -- i) create a table with all possible promo_period/week combos and fix the 201209 thing */
proc sql;
create table all_weeks as
select distinct PROMO_PERIOD, NSLC_WEEK
from promo_sku_fact
order by 1,2;
run;

data all_weeks; 
set all_weeks; 
if PROMO_PERIOD = 201209 and NSLC_WEEK = 201301 then delete; 
run;

/* -- ii) create a table with all the skus */
data sku_info;
set promo_sku_fact (keep = SKU PRODUCT_ITEM_KEY CATEGORY_NAME SUBCATEGORY_NAME);
by SKU PRODUCT_ITEM_KEY CATEGORY_NAME SUBCATEGORY_NAME notsorted;
if first.SKU;
run;
/* -- iii) do a cartesian join on both tables to get all possible sku/week permutations */
proc sql;
create table sku_weeks as
select a.*, b.*
from sku_info as a, all_weeks as b
order by SKU, NSLC_WEEK;
quit;
/* -- iv) set all "new" rows to zero units */
data promo_sku_fact;
merge promo_sku_fact sku_weeks;
by SKU NSLC_WEEK;
if UNITS = . then UNITS = 0;
run;

/*STEP 2a: GET LIST OF SKUs ON AM PROMO BY WEEK */
proc sql;
create table promo_sku_am as
        select distinct c.SKU
                  ,e.NSLC_WEEK
        from work.promo_&CURRENT_PERIOD as c,
                 nslc.promo_offer_dim as d,
                 nslc.NSLC_DATE_DIM as e
where c.SKU=d.ARTICLE
and e.DATE_ID between input(compress(put(d.OFFER_START_DATE,YYMMDD10.),'-'),12.) and input(compress(put(d.OFFER_END_DATE,YYMMDD10.),'-'),12.)
order by 1,2;
quit;

/*STEP 2b: GET LIST OF SKUs ON LT PROMO BY WEEK */
proc sql;
create table promo_sku_lt as
        select distinct a.SKU
                  ,e.NSLC_WEEK
        from nslc.product_item_dim as a,
             work.promo_&CURRENT_PERIOD as c,
                 nslc.promo_dim as d,
                 nslc.NSLC_DATE_DIM as e
where a.SKU=c.SKU
and a.PRODUCT_ITEM_KEY = d.PRODUCT_ITEM_KEY
and substr(d.PROMO_DESC,1,2) = 'Y_'
and e.DATE_ID between input(compress(put(d.PROMO_START_DATE,YYMMDD10.),'-'),12.) and input(compress(put(d.PROMO_END_DATE,YYMMDD10.),'-'),12.)
order by 1,2;
quit;

/* STEP 2c: MAKE SURE TLOG TABLE IS SORTED PROPERLY AND APPEND A PROMO_FLAG 1 = promo that week, 0 = no promo */
proc sort data=promo_sku_fact; by sku nslc_week; run;
data promo_sku_fact;
merge promo_sku_fact(in=a) promo_sku_am(in=b) promo_sku_lt(in=c);
by SKU NSLC_WEEK;
        if a;
        PROMO_FLAG = b or c;
run;

/* STEP 3a: DROP SKUs WITH LESS THAN 4 WEEKS NON PROMO DATA */
/* this can probably be done later in the code when the 4wk moving average is being calculated */

/* STEP 3b: DROP SKUs IN THE BOTTOM 5TH PERCENTILE OF TOTAL UNIT SALES */
/* not sure if this is necessary? */

/* STEP 4: CALCULATE BASELINE1 - i.e. the 4wk non-promo moving average */

/* STEP 4a: CALCULATE THE 4 WK MOVING AVERAGE FOR NON PROMO WEEKS 
                         - sort the table by PROMO_FLAG so that all the 1s are at the bottom */
proc sort data=promo_sku_fact; by SKU PROMO_FLAG NSLC_WEEK; run;

%LET WEEKS = 4; /* set the moving average amount */

data promo_sku_fact;
set promo_sku_fact;
by SKU;
/*if PROMO_FLAG = 0;*/
retain UNITS_SUM 0; /* running total of units */

        if first.SKU then do;   /* reset the counter and running total */
                CNT=0;
                UNITS_SUM=0;
        end;

        CNT+1;
        last&WEEKS = lag&WEEKS(UNITS);

        if CNT gt &WEEKS then UNITS_SUM=sum(UNITS_SUM, UNITS, -last&WEEKS);
        else UNITS_SUM = sum(UNITS_SUM, UNITS);

        if CNT ge &WEEKS then MOV_AVG1 = UNITS_SUM/&WEEKS;      /* calculate the moving average based on &WEEKS */
        else MOV_AVG1 = .;

        BASELINE1 = lag(MOV_AVG1);      /* shift the average down one line */

        if first.SKU then BASELINE1 = .;

        if PROMO_FLAG = 1 then BASELINE1 = .;

drop CNT UNITS_SUM last&WEEKS MOV_AVG1;
run;

/* STEP 4b: FILL IN THE VALUES FOR THE PROMO WEEKS */
proc sort data=promo_sku_fact; by SKU descending NSLC_WEEK; run;

data promo_sku_fact;
set promo_sku_fact;
by SKU descending NSLC_WEEK;
retain x;
        if first.SKU then x = .;
        if BASELINE1 ne . then x=BASELINE1;
run;

data promo_sku_fact;
set promo_sku_fact;
if PROMO_FLAG = 1 and BASELINE1 = . then BASELINE1 = x;
drop x;
run;

proc sort data = promo_sku_fact; by SKU NSLC_WEEK; run;

/* STEP 5: CALCULATE THE ADJUSTMENT FACTOR BY CATEGORY OR SUBCATEGORY */
proc means data=promo_sku_fact noprint nway;
class NSLC_WEEK CATEGORY_NAME;
where PROMO_FLAG = 0 and BASELINE1 ne .;
var UNITS BASELINE1;
output out = baseline (drop = _freq_ _type_) sum = ;
run;

data baseline;
set baseline;
if BASELINE1 gt 0 then do;
        ADJ = UNITS/BASELINE1;
        output;
end;
run;

/* STEP 6: CALCULATE THE ADJUSTED BASELINE */
proc sql;
create table promo_incremental as
        select a.*
                  ,b.ADJ
                  ,case when b.ADJ = . then a.BASELINE1
                                else b.ADJ*a.BASELINE1
                   end as BASELINE_ADJ
        from promo_sku_fact as a left join baseline as b on (a.NSLC_WEEK = b.NSLC_WEEK
                                                                and a.CATEGORY_NAME = b.CATEGORY_NAME)
        where a.PROMO_PERIOD = &CURRENT_PERIOD
        order by SKU, NSLC_WEEK;
quit;

/* STEP 7: CONVERT ALL THE WEEK INFORMATION INTO OFFER_CODE INFORMATION FOR REPORT */
/* 7a join promo_incremental with the calendar to get start and end dates for each week_id */
proc sql;
create table promo_incremental1 as
select c.OFFER_CODE
          ,a.SKU
          ,a.PROMO_PERIOD
          ,a.NSLC_WEEK
          ,a.UNITS
          ,a.BASELINE_ADJ
          ,c.START_DATE as PROMO_START_DATE
          ,c.END_DATE as PROMO_END_DATE
          ,min(b.date_id) as START_DATE
          ,max(b.date_id) as END_DATE
from promo_incremental as a,
         nslc.nslc_date_dim as b,
         promo_&CURRENT_PERIOD as c
where a.nslc_week = b.nslc_week
and a.SKU = c.SKU
group by 1,2,3,4,5,6,7,8;
quit;

/* 7b remove all records that are outside the valid promo period for that sku/offer */
data promo_incremental2;
set promo_incremental1;
if START_DATE < PROMO_START_DATE then delete;
if END_DATE > PROMO_END_DATE then delete;
run;

/* 7c consolidate weekly information into promotional period information */ 
proc sql;
create table promo_incremental3 as
select OFFER_CODE
          ,SKU
          ,PROMO_START_DATE
          ,PROMO_END_DATE
          ,sum(UNITS) as UNITS
          ,sum(BASELINE_ADJ) as BASELINE
from promo_incremental2
group by 1,2,3,4
order by 1,2,3,4;
quit;

/******************************************/

/* put the # of skus that are in spirits_promo (or any promo table) into a variable */
proc sql;
        select count(sku) into :num_skus
        from promo_&CURRENT_PERIOD;
quit;

/* create a master table for later looping to pull responder activity */
proc sql;
CONNECT TO Netezza AS AMRP (server="production.nz.db.loyalty.com" database=EXTNSLCP port=5480 user=wayoub password="&dbpass");
create table nslc_master as     
select * from connection to AMRP(
        select a.collector_key
              ,a.date_id
              ,b.product_group_2_code as CATEGORY_CODE
              ,b.SKU
               
              ,sum(a.SALES_VALUE) as SALES
              ,sum(a.QUANTITY_SOLD*b.SELLING_UNIT_VOLUME/1000) as VOLUME
              ,sum(a.QUANTITY_SOLD) as UNITS
              ,count(distinct (a.POS_TRANS_ID || a.STORE_LOCATION_KEY || a.POS_TILL_NUM || a.DATE_ID || a.TRANS_TIME)) as TRS
        from nslc.sales_item_fact as a,
             nslc.product_item_dim as b
        where a.product_item_key = b.product_item_key
        and a.customer_id = ''
        and a.collector_key > 0
        and a.date_id >= 20120220
        group by 1,2,3,4
        order by 3,1,2,4);
DISCONNECT from AMRP;
QUIT;

/* use the CATEGORY_NAME instead of the PRODUCT_GROUP_4_CODE */
data nslc_master;
merge nslc_master(in=a) amrp.wa_nslc_merch_cats(in=b keep = CATEGORY_CODE CATEGORY_NAME);
by CATEGORY_CODE;
run;

%macro CREATE_SKU_REPORT;
/*options nosource nonotes;*/
options source notes;

        %do j = 1 %to &num_skus;
/*      %do j = 1 %to 5; */
                data _null_;
                        set promo_&CURRENT_PERIOD (firstobs=&j obs=&j);
                        call symput('CATEGORY',CATEGORY);
                        call symput('OFFER_CODE',OFFER_CODE);
                        call symput('SKU',SKU);
                        call symput('START_DATE',START_DATE);
                        call symput('END_DATE',END_DATE);
                run;
                
                /* step 1: pull the list of responders to the promo'd sku */
                proc sql;
                create table responders as
                        select a.collector_key
                        from nslc_master as a
                        where a.SKU = "&SKU"
                        and a.date_id between &START_DATE and &END_DATE
                        order by 1;
                quit;
                
                /* step 2: take the responders from above and compute their activity in the pre and post at the category level */
                /*         note - pre is anything before the end of the promo period that contains the category promo'd */
                proc sql;
                create table responder_activity as
                        select b.collector_key
                              ,"&OFFER_CODE" as OFFER_CODE
                              ,"&SKU" as SKU
                              ,"&CATEGORY" as CATEGORY
                              ,case when (((a.date_id between &START_DATE and &END_DATE) and (a.SKU <> "&SKU")) or a.date_id < &START_DATE) then 'PRE'
                                    when a.date_id > &END_DATE then 'PST'
                                    else 'PRM'
                               end as PERIOD
                               /* now start pulling the sales info for the particular category*/
                              ,sum(a.SALES) as SALES
                              ,sum(a.VOLUME) as VOLUME  /* convert mL to L */
                              ,sum(a.UNITS) as UNITS
                              ,sum(a.TRS) as TRS
                        from nslc_master as a,
                             responders as b
                        where a.collector_key = b.collector_key
                        and a.CATEGORY_NAME = "&CATEGORY"
                        group by 1,2,3,4,5
                        order by 1,2,3,4,5;
                quit;

                data responder_prm;
                set responder_activity;
                if PERIOD = 'PRM';
                SPT = SALES/TRS;
                SPV = SALES/VOLUME;
                VPU = VOLUME/UNITS;
                VPT = VOLUME/TRS;
                UPT = UNITS/TRS;
                run;
                
                data responder_pre;
                set responder_activity;
                if PERIOD = 'PRE';
                SPT = SALES/TRS;
                SPV = SALES/VOLUME;
                VPU = VOLUME/UNITS;
                VPT = VOLUME/TRS;
                UPT = UNITS/TRS;                
                run;
                
                data responder_pst;
                set responder_activity;
                if PERIOD = 'PST';
                SPT = SALES/TRS;
                SPV = SALES/VOLUME;
                VPU = VOLUME/UNITS;
                VPT = VOLUME/TRS;
                UPT = UNITS/TRS;                
                run;
                
                /* get a prepromo and promo comparison of collector activity */
                proc sql;
                create table summary_sku as
                        select a.OFFER_CODE
                              ,a.CATEGORY
                              ,a.sku
                              
                                  /* Shift in Basket Size - Sales per Transaction */
                              ,sum(case when a.spt>=b.spt and b.spt is not null then 1 else 0 end) as SPT_UP
                              ,sum(case when a.spt<b.spt and b.spt is not null then 1 else 0 end) as SPT_DN

                                  /* Shift in Price paid per Litre */
                              ,sum(case when a.spv>=b.spv and b.spv is not null then 1 else 0 end) as SPV_UP
                              ,sum(case when a.spv<b.spv and b.spv is not null then 1 else 0 end) as SPV_DN
/*                                ,sum(case when a.spv=b.spv and b.spv is not null then 1 else 0 end) as SPV_SM*/

                                  /* 2 metrics for Volume shift - per trans and per item */
                              ,sum(case when a.vpu>=b.vpu and b.vpu is not null then 1 else 0 end) as VPU_UP
                              ,sum(case when a.vpu<b.vpu and b.vpu is not null then 1 else 0 end) as VPU_DN
                              ,sum(case when a.vpt>=b.vpt and b.vpt is not null then 1 else 0 end) as VPT_UP
                              ,sum(case when a.vpt<b.vpt and b.vpt is not null then 1 else 0 end) as VPT_DN

                                  /* Unit shift - i.e. # of articles they put in basket */
                              ,sum(case when a.upt>=b.upt and b.upt is not null then 1 else 0 end) as UPT_UP
                              ,sum(case when a.upt<b.upt and b.upt is not null then 1 else 0 end) as UPT_DN

                                  /* new collectors and re-purchasing collectors */
                              ,sum(case when b.sales is null then 1 else 0 end) as NEW_ACTIVES
                              ,sum(case when c.sales is not null then 1 else 0 end) as ALL_RETURN
                              ,sum(case when b.sales is null and c.sales is not null then 1 else 0 end) as NEW_RETURN

                                  /* over all counts of collectors */
                              ,sum(case when b.sales is not null then 1 else 0 end) as PRE_ACTIVES
                              ,sum(case when a.sales is not null then 1 else 0 end) as PRM_ACTIVES
                              ,sum(case when c.sales is not null then 1 else 0 end) as PST_ACTIVES

                                  /* actual metrics for % lift/decline calcs */
                              ,sum(b.sales) as pre_sales
                              ,sum(case when b.sales is not null then a.sales else 0 end) as prm_sales
                              ,sum(b.volume) as pre_volume
                              ,sum(case when b.volume is not null then a.volume else 0 end) as prm_volume
                              ,sum(b.units) as pre_units
                              ,sum(case when b.units is not null then a.units else 0 end) as prm_units
                              ,sum(b.trs) as pre_trs
                              ,sum(case when b.trs is not null then a.trs else 0 end) as prm_trs

                        from responder_prm as a
                                        left join responder_pre as b
                                                on a.collector_key = b.collector_key
                                        left join responder_pst as c
                                                on a.collector_key = c.collector_key
                                 
                        group by 1,2,3
                        order by 1,2,3;
                quit;

                %if &j=1 %then %do;
                        data summary_all; set summary_sku; run;
                %end;
                %else %do;
                        proc append base=summary_all data=summary_sku; run;
                %end;   
        %end;
/*option source notes;*/
%mend CREATE_SKU_REPORT;
%CREATE_SKU_REPORT;


/******************************************/

        /* master offer table */
        proc sort data = promo_&CURRENT_PERIOD; by OFFER_CODE SKU; run;

        /* offer summary info */
        proc sort data = promo_miles_&CURRENT_PERIOD; by OFFER_CODE; run;
        proc sort data = promo_sku_details_offer; by OFFER_CODE; run;

        /* offer AND sku summary info */
        proc sort data = promo_sku_details1; by OFFER_CODE SKU; run;
        proc sort data = promo_sku_details_&CURRENT_PERIOD; by OFFER_CODE SKU; run;
        proc sort data = promo_sku_details_&PREVIOUS_PERIOD; by OFFER_CODE SKU; run;
        proc sort data = promo_incremental3; by OFFER_CODE SKU; run;
        proc sort data = summary_all; by OFFER_CODE SKU; run;

        data promo_final_offer;
        merge promo_&CURRENT_PERIOD(in=a) promo_miles_&CURRENT_PERIOD(in=b) promo_sku_details_offer(in=c);
        by OFFER_CODE;
        if a;
        run;

        data promo_final_offersku;
        merge promo_final_offer(in=a) promo_sku_details1(in=b) promo_sku_details_&CURRENT_PERIOD(in=c)
                promo_sku_details_&PREVIOUS_PERIOD(in=d) promo_incremental3(in=e) summary_all(in=f);
        by OFFER_CODE SKU;
        run;

        proc stdize method=mean reponly missing=0 data=promo_final_offersku out=promo_final;
                var RESPONDERS MILES_ISSUED BONUS_TRS OFFER_1 OFFER_2 OFFER_3 OFFER_4 CUR: PRE:;
        run;


        /* create consolidated PROMO_SUMMARY_SKU output */
        /* create one at the offer level */
        proc sql;
        create table promo_summary_offer as
                select OFFER_CODE as Promo_Offer_Code
                          ,sum(OFFER_1)/(sum(OFFER_1)+sum(OFFER_2)+sum(OFFER_3)+sum(OFFER_4)) as offer1
                          ,sum(OFFER_2)/(sum(OFFER_1)+sum(OFFER_2)+sum(OFFER_3)+sum(OFFER_4)) as offer2
                          ,sum(OFFER_3)/(sum(OFFER_1)+sum(OFFER_2)+sum(OFFER_3)+sum(OFFER_4)) as offer3
                          ,sum(OFFER_4)/(sum(OFFER_1)+sum(OFFER_2)+sum(OFFER_3)+sum(OFFER_4)) as offer4
                          ,sum(CUR_TOTAL_UNITS)/sum(CUR_TOTAL_TRS) as offer_upt
                          ,sum(CUR_AM_UNITS)/sum(CUR_TOTAL_UNITS) as offer_am_units
                          ,sum(CUR_AM_TRS)/sum(CUR_TOTAL_TRS) as offer_am_trs
                from promo_final
                group by 1
                order by 1;
        quit;


        proc sql;
        create table promo_summary_sku as
                select case when AM = 0 then 'LT' else 'Air Miles' end as Type_of_Promotion
                          ,CATEGORY as Category
                          ,SUBCATEGORY as Sub_Category
                          ,SUBSUBCATEGORY as Sub_Sub_Category
                          ,SUPPLIER as Vendor
                          ,PROMO_PERIOD as Promo_Period
                          ,START_DATE as Promo_Start_Date
                          ,END_DATE as Promo_End_Date
                          ,OFFER_CODE as Promo_Offer_Code
                          ,SKU as Sku
                          ,SKU_DESC as Item_Name
                          ,OFFER_DESC as Article_Notes_Air_Miles_Offer
                          ,PRICE_BAND as Price_Band
                          ,VOLUME_PER_SKU as Unit_Volume
                          ,MILES_ISSUED as Air_Miles_Issued
                          ,case when AM = 0 then 0 else RESPONDERS end as Air_Miles_Responders
                          ,CUR_TOTAL_TRS as Total_Transactions
                          ,CUR_AM_TRS as Air_Miles_Transactions
                          ,CUR_TOTAL_UNITS as Total_Units
                          ,CUR_AM_UNITS as Air_Miles_Units
                          ,PRE_TOTAL_TRS as Total_Transactions_PRE
                          ,PRE_AM_TRS as Air_Miles_Transactions_PRE
                          ,PRE_TOTAL_UNITS as Total_Units_PRE
                          ,PRE_AM_UNITS as Air_Miles_Units_PRE                    
                          ,UNITS
                          ,BASELINE
                          ,UNITS/BASELINE-1 as Lift_vs_Baseline
                          ,CUR_TOTAL_UNITS/PRE_TOTAL_UNITS-1 as Lift_vs_Previous_Year


                          /*%if &j ne 2 %then %do;*/
                          ,OFFER_DESC_PRE as Previous_Year_Promo
                          /*%end;
                          %else %do;
                          ,'' as Previous_Year_Promo
                          %end;*/
                          /* current period metrics */

                          ,(CUR_1)/((CUR_1)+(CUR_2)+(CUR_3)+(CUR_4)) as cur1
                          ,(CUR_2)/((CUR_1)+(CUR_2)+(CUR_3)+(CUR_4)) as cur2
                          ,(CUR_3)/((CUR_1)+(CUR_2)+(CUR_3)+(CUR_4)) as cur3
                          ,(CUR_4)/((CUR_1)+(CUR_2)+(CUR_3)+(CUR_4)) as cur4
                          ,(CUR_TOTAL_UNITS)/(CUR_TOTAL_TRS) as cur_upt
                          ,(CUR_AM_UNITS)/(CUR_TOTAL_UNITS) as cur_am_units
                          ,(CUR_AM_TRS)/(CUR_TOTAL_TRS) as cur_am_trs

                          /* previous period metrics */

                          ,(PRE_1)/((PRE_1)+(PRE_2)+(PRE_3)+(PRE_4)) as pre1
                          ,(PRE_2)/((PRE_1)+(PRE_2)+(PRE_3)+(PRE_4)) as pre2
                          ,(PRE_3)/((PRE_1)+(PRE_2)+(PRE_3)+(PRE_4)) as pre3
                          ,(PRE_4)/((PRE_1)+(PRE_2)+(PRE_3)+(PRE_4)) as pre4
                          ,(PRE_TOTAL_UNITS)/(PRE_TOTAL_TRS) as pre_upt
                          ,(PRE_AM_UNITS)/(PRE_TOTAL_UNITS) as pre_am_units
                          ,(PRE_AM_TRS)/(PRE_TOTAL_TRS) as pre_am_trs

                          ,SPT_UP
                          ,SPT_DN
                          ,SPV_UP       
                          ,SPV_DN       
                          ,VPU_UP       
                          ,VPU_DN       
                          ,VPT_UP       
                          ,VPT_DN       
                          ,UPT_UP       
                          ,UPT_DN       
                          ,NEW_ACTIVES
                          ,ALL_RETURN   
                          ,NEW_RETURN   
                          ,PRE_ACTIVES  
                          ,PRM_ACTIVES  
                          ,PST_ACTIVES  
                          ,pre_sales    
                          ,prm_sales    
                          ,pre_volume   
                          ,prm_volume   
                          ,pre_units    
                          ,prm_units    
                          ,pre_trs      
                          ,prm_trs
                          ,(prm_sales/prm_volume)/(pre_sales/pre_volume)-1 as spv_diff
                          ,(prm_units/prm_trs)/(pre_units/pre_trs)-1 as upt_diff
                          ,(prm_volume/prm_trs)/(pre_volume/pre_trs)-1 as vpt_diff
                          ,(prm_sales/prm_trs)/(pre_sales/pre_trs)-1 as spt_diff

                from promo_final
                order by OFFER_CODE;
        quit;

        /* merge the offer details with the sku details */
        data promo_summary;
        merge promo_summary_offer promo_summary_sku;
        by PROMO_OFFER_CODE;
        if Type_Of_Promotion = 'Air Miles' then 
                numTiers = countc(Article_Notes_Air_Miles_Offer,';')+1;
        else numTiers = 0;
        run;

        /*%if &j=1 %then %do;
                data output.promo_summary_skuALL; set output.promo_summary_sku; run;
                data output.promo_summary_dataALL; set output.promo_summary_data; run;
                data output.promo_summary; set output.promo_summary; run;
        %end;
        %else %do;*/
                proc append base=promo_summary_skuALL data=promo_summary_sku; run;
                proc append base=amrp.NSLC_PROMO_SUMMARY data=promo_summary; run;
        /*%end;*/
%mend CREATE_PROMO_REPORT;

/* %macro CREATE_PROMO_REPORT (CURRENT_PERIOD,PREVIOUS_PERIOD,PE_START_DATE,SPONSOR,j); */
/*%CREATE_PROMO_REPORT (201303, 201203,20100101,2);*/
/*%CREATE_PROMO_REPORT (201304, 201204,20100101,2);
%CREATE_PROMO_REPORT (201305, 201205,20100101,2);
%CREATE_PROMO_REPORT (201306, 201206,20100101,2);
%CREATE_PROMO_REPORT (201307, 201207,20100101,2);

%CREATE_PROMO_REPORT (201302, 201202,20100101,2);
%CREATE_PROMO_REPORT (201308, 201208,20100101,2);

%CREATE_PROMO_REPORT (201309, 201209,20100101,999);
%CREATE_PROMO_REPORT (201402, 201302,20100101,999);*/

/*%CREATE_PROMO_REPORT (201302, 201202,20100101,2);*/
/*%CREATE_PROMO_REPORT (201308, 201208,20100101,2);*/
/*%CREATE_PROMO_REPORT (201402, 201302,20100101,999);*/

/*%CREATE_PROMO_REPORT (201403, 201303,20100101,999);*/
/*%CREATE_PROMO_REPORT(201404,201304,20100101,999);*/
%CREATE_PROMO_REPORT(201405,201305,20100101,999);