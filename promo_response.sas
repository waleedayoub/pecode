/* LAST REVISION
/* $Date: 2012-11-21 09:37:35 -0500 (Wed, 21 Nov 2012) $
/* $Revision: 92 $
/* $Author: jasselin $
/* $HeadURL: file:///K:/svn/UTILITIES/trunk/UTILITIES/MACROS/promo_response.sas $ */
/* **************************************************************************************** */
/* EXTRACT PROMOTION RESPONSE
/*
/* CREATED BY: JEROME ASSELIN
/* JULY 2011
/* **************************************************************************************** */


%MACRO PROMO_RESPONSE(CELL_CODES, MARKET_SPONSORS, TARGET_SPONSORS, SUCCESS_CONDITION=TRUE, WHERE=TRUE);

	OPTION NOSOURCE NONOTES ;

	/* ##################################################################
		 CHECK IF THE REQUIRED INFORMATION EXIST OR IS VALID
	/* ################################################################## */

	%LET ERRORFLAG = 0;

	/* REFORMAT CELL_CODES STATEMENT */
	%IF &CELL_CODES ~= "" %THEN %LET CELL_CODES=%UNDOUBLEQUOTE("AND MO.CELL_CODE IN (%SQL_LIST(&CELL_CODES))");

	/* REFORMAT MARKET_SPONSORS */
	%IF &MARKET_SPONSORS ~= "" %THEN %LET MARKET_SPONSORS=%UNDOUBLEQUOTE("AND S.SPONSOR_CODE IN (%SQL_LIST(&MARKET_SPONSORS))");

	/* REFORMAT TARGET_SPONSORS */
	%IF &TARGET_SPONSORS ~= "" %THEN %LET TARGET_SPONSORS=%UNDOUBLEQUOTE("AND ST.SPONSOR_CODE IS NOT NULL AND ST.SPONSOR_CODE IN (%SQL_LIST(&TARGET_SPONSORS))");

	/* ##################################################################
		 EXTRACT DATA
	/* ################################################################## */

	%IF &ERRORFLAG = 0 %THEN %DO;
		PROC SQL;
 			CONNECT TO NETEZZA AS &AMRP ;
 			CREATE TABLE MYLIB.MARKET_OFFER  AS
 			SELECT * FROM CONNECTION TO AMRP(
 			SELECT MO.MKT_OFFER_INSTANCE_KEY, MO.MKT_OFFER_CODE, MO.MKT_OFFER_NAME, MO.CELL_CODE, MO.CONTROL_FLAG, MO.CONTROL_MKT_OFFER_INSTANCE_KEY,
			MCF.COLLECTOR_KEY, MIN(T.DATE_ID) MINDATE, MAX(T.DATE_ID) MAXDATE,
			MO.MKT_OFFER_START_DATE, MO.MKT_OFFER_END_DATE,
			CASE WHEN SUM(CASE WHEN T.COLLECTOR_KEY IS NOT NULL &TARGET_SPONSORS AND &SUCCESS_CONDITION THEN 1 ELSE 0 END)>0 THEN 1 ELSE 0 END TARGET
			FROM AMRP.MKT_OFFER_INSTANCE_DIM MO JOIN AMRP.SPONSOR_DIM S
			ON S.SPONSOR_KEY = MO.SPONSOR_KEY
			&MARKET_SPONSORS
			JOIN AMRP.MKT_CAMPAIGN_DIM MC USING (MKT_CAMPAIGN_KEY)
			JOIN AMRP.MKT_CONTACT_FACT MCF USING (MKT_OFFER_INSTANCE_KEY)
			LEFT OUTER JOIN AMRP.ISSUANCE_FACT T
			ON MCF.COLLECTOR_KEY = T.COLLECTOR_KEY
			AND CAST(TO_CHAR(MO.MKT_OFFER_START_DATE, 'YYYYMMDD') AS INT) <= T.DATE_ID
			AND T.DATE_ID <= CAST(TO_CHAR(MO.MKT_OFFER_END_DATE, 'YYYYMMDD') AS INT)
			JOIN AMRP.SPONSOR_DIM ST
			ON T.SPONSOR_KEY = ST.SPONSOR_KEY
			JOIN AMRP.ISSUANCE_OFFER_DIM O USING (ISSUANCE_OFFER_KEY)
			WHERE &WHERE
			&CELL_CODES
			GROUP BY MO.MKT_OFFER_INSTANCE_KEY, MO.MKT_OFFER_CODE, MO.MKT_OFFER_NAME, MO.CELL_CODE, MO.CONTROL_FLAG, MO.CONTROL_MKT_OFFER_INSTANCE_KEY, MCF.COLLECTOR_KEY, MO.MKT_OFFER_START_DATE, MO.MKT_OFFER_END_DATE
			ORDER BY MO.MKT_OFFER_INSTANCE_KEY, MO.MKT_OFFER_CODE, MO.MKT_OFFER_NAME, MO.CELL_CODE, MO.CONTROL_FLAG, MO.CONTROL_MKT_OFFER_INSTANCE_KEY, MCF.COLLECTOR_KEY, MO.MKT_OFFER_START_DATE, MO.MKT_OFFER_END_DATE
			);
			DISCONNECT FROM AMRP;
		QUIT;

		PROC MEANS DATA=MYLIB.MARKET_OFFER;
			VAR TARGET;
			BY MKT_OFFER_INSTANCE_KEY MKT_OFFER_CODE MKT_OFFER_NAME CELL_CODE;
		RUN;

	%END;

	OPTION SOURCE NOTES ;

%MEND;

