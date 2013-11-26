%macro PE(DATA=, MA_WEEKS=4, ADJ_LEVEL=, PROMO_TYPE='');

	/* need to include code to make sure there is a data table provided, that includes:
		WEEK, at least 2 levels, SKU, UNITS and PROMO_FLAG*/
	%LET ERRORFLAG = 0;

	%if %sysfunc(exist(&DATA))=0 %then %do;
		%put %str(ER)ROR: Data set %str(&DATA) does not exist.;
     	%goto exit;
	%end;
	
	/* sort the data by sku and then descending weeks */
	/* what happens if a particular week had zero sales? */
	proc sort data = &DATA; by SKU PROMO_FLAG WEEK; run;

	/* calculate the moving average */	
	data &DATA;
		set &DATA;
		by SKU;
		/*if PROMO_FLAG = 0;*/
		retain UNITS_SUM 0; /* running total of units */

		        if first.SKU then do;   /* reset the counter and running total */
		                CNT=0;
		                UNITS_SUM=0;
		        end;

		        CNT+1;
		        last&MA_WEEKS. = lag&MA_WEEKS.(UNITS);

		        if CNT gt &MA_WEEKS. then UNITS_SUM=sum(UNITS_SUM, UNITS, -last&MA_WEEKS.);
		        else UNITS_SUM = sum(UNITS_SUM, UNITS);

		        if CNT ge &MA_WEEKS. then MOV_AVG1 = UNITS_SUM/&MA_WEEKS.;      /* calculate the moving average based on &MA_WEEKS. */
		        else MOV_AVG1 = .;

		        BASELINE1 = lag(MOV_AVG1);      /* shift the average down one line */

		        if first.SKU then BASELINE1 = .;

		        if PROMO_FLAG = 1 then BASELINE1 = .;

		drop CNT UNITS_SUM last&MA_WEEKS. MOV_AVG1;
	run;

	/* STEP 4b: FILL IN THE VALUES FOR THE PROMO WEEKS */
	proc sort data=&DATA; by SKU descending WEEK; run;

	data &DATA;
		set &DATA;
		by SKU descending WEEK;
		retain x;
        if first.SKU then x = .;
        if BASELINE1 ne . then x=BASELINE1;
	run;

	data &DATA;
		set &DATA;
		if PROMO_FLAG = 1 and BASELINE1 = . then BASELINE1 = x;
		drop x;
	run;

	proc sort data = &DATA; by SKU WEEK; run;

	proc means data=&DATA noprint nway;
		class WEEK &ADJ_LEVEL;
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

%mend PE;