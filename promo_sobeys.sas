/* LAST REVISION
/* $Date: 2013-06-20 16:13:35 -0400 (Thu, 20 Jun 2013) $
/* $Revision: 152 $
/* $Author: jasselin $
/* $HeadURL: file:///K:/svn/UTILITIES/trunk/UTILITIES/MACROS/promo_sobeys.sas $ */
/* **************************************************************************************** */
/* EXTRACT SOBEYS (ATL, LAW, QUE) RESPONDERS TO PROMOTIONS.
/*
/* CREATED BY: JEROME ASSELIN
/* JUNE 2013
/* **************************************************************************************** */

/* 
/* EXAMPLE
/* 
/**/

%MACRO PROMO_SOBEYS(RDM, PROMO=, OUTRESP=&RDM._PROMO_RESP, OUTDIM=&RDM._PROMO_DIM, ITEM=0, SUM=PROMO_VALUE_PTS);

	%LOCAL TMP I N VAR;
	%LET TMP=%RAN_STRING(PREFIX=B);

	%IF %SYSFUNC(EXIST(&PROMO))=0 %THEN %DO;
		PROC SQL;
			CREATE TABLE &TMP AS
			SELECT * FROM ISL.JASSELIN_&RDM._PROMO_DIM
			WHERE &PROMO ;
		QUIT;
		%LET PROMO=&TMP ;

		%IF &OUTDIM~= %THEN %DO;
			PROC SQL;
				CREATE TABLE &OUTDIM AS
				SELECT * FROM &TMP;
			QUIT;
		%END;
	%END;

	%IF &OUTRESP~= %THEN %DO;

		%LET N=%COUNTW(&SUM);
		PROC SQL;
       		 	CREATE TABLE &TMP.B AS
			SELECT F.TRANSACTION_RK, F.PROMO_SK
			%IF &N>0 %THEN %DO I=1 %TO &N ;
				%LET VAR=%SCAN(&SUM,&I);
				, SUM(&VAR) AS &VAR._B
			%END;
			FROM ISL.JASSELIN_&RDM._PROMO_BASKET_FACT F, &PROMO P
			WHERE F.PROMO_SK = P.PROMO_SK
			GROUP BY 1, 2
			ORDER BY 1, 2;
		QUIT;

		PROC SQL;
			CREATE TABLE &TMP.I AS
			SELECT F.TRANSACTION_RK, F.PROMO_SK
			%IF &ITEM=1 %THEN %DO;
				, F.ITEM_SK
			%END;
			%IF &N>0 %THEN %DO I=1 %TO &N ;
				%LET VAR=%SCAN(&SUM,&I);
				, SUM(&VAR) AS &VAR._I
			%END;
			FROM ISL.JASSELIN_&RDM._PROMO_ITEM_FACT F, &PROMO P
			WHERE F.PROMO_SK = P.PROMO_SK
			GROUP BY 1, 2
			%IF &ITEM=1 %THEN %DO;
				, F.ITEM_SK
			%END;
			ORDER BY 1, 2
			%IF &ITEM=1 %THEN %DO;
				, F.ITEM_SK
			%END;
			;
		QUIT;

		DATA &TMP.;
		MERGE &TMP.B &TMP.I;
		BY TRANSACTION_RK PROMO_SK;
		RUN;

		PROC SORT DATA=&TMP NODUPKEY;
		BY TRANSACTION_RK PROMO_SK
		%IF &ITEM=1 %THEN %DO;
			ITEM_SK
		%END;
		;
		RUN;

		DATA &OUTRESP.;
		SET &TMP.;
		RUN;

	%END;

	PROC DATASETS LIBRARY=WORK NOLIST;
	DELETE &TMP &TMP.B &TMP.I;
	QUIT;

%MEND PROMO_SOBEYS;

