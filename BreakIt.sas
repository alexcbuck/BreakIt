/*--------------------------------------------------------------------------------------*

*******************************************************
***  Copyright Rho, Inc. 2016, all rights reserved  ***
*******************************************************

Project:    Graphic Range Values

Program:    BreakIt

Purpose:    Create macro values to be uses in RANGES options in XAXIS/YAXIS statements

Params:      •	INPUTDAT: The data to be graphed
             •	INVAL: The variable with the value graphed to the axis of interest
             •	GAPCHECK: The requested factor difference in input dataset values to consider the use of RANGE appropriate. Default is 2 times the lower value.
             •	MARG: The margin requested between the data values and the axis break. Default is 5.
             •	DIFFCHECK: The requested factor difference in macro variable values to consider the use of RANGE appropriate. Default is 2 times the lower value.
             •	OBSCHECK: The maximum number of iterations requested when determining macro values. Default is 100.


Outputs:     •	&OVMIN: The overall minimum value from the dataset
             •	&OVMAX: The overall maximum value from the dataset
             •	&PRIOVAL: The dataset value prior to the largest value gap
             •	&POSTVAL: The dataset value following the largest value gap
             •	&GAPVAL: The size of the value gap defined as the difference between &PRIORVAL and &POSTVAL
             •	&LOWBREAK: The suggested value for the lower axis range
             •	&UPBREAK: The suggest value for the upper axis range
             •	&DIFFP: The factor difference between &UPBREAK and &LOWBREAK



Program History:

DATE        PROGRAMMER          DESCRIPTION
---------   ------------------  ------------------------------------------------------ 
25MAR2016   Alex Buck           Create program
*--------------------------------------------------------------------------------------*/

%Macro Breakit(inputdat=,
                inval=,
                gapcheck=2,
                marg=5,
                diffcheck=2,
                obscheck=100);

%global OVMIN OVMAX PRIORVAL POSTVAL GAPVAL LOWBREAK UPBREAK DIFFP;
data indat;
   set &inputdat;
   where not missing(&inval);
   avar=&inval;
run;

proc sql;
   select min(avar) into:ovmin from indat;
   select max(avar) into:ovmax from indat;
quit;

proc sort data=indat out=indat_asort;
   by avar;
run;

data avardat;
   set indat_asort;
   by avar;

   avar_lag=lag(avar);
   avar_gap=avar-avar_lag;
run;

proc sort data=avardat out=avardat_gsort;
   by avar_gap;
run;

data avardat_gsort_last;
   set avardat_gsort end=eof;
   by avar_gap;

   gapperc=avar_gap/abs(avar_lag);
   if eof;
run;

proc sql;
   select avar into:postval from avardat_gsort_last;
   select avar_lag into:priorval from avardat_gsort_last;
   select avar_gap into:gapval from avardat_gsort_last;
   select gapperc into:gapp from avardat_gsort_last;
quit;

%macro checkgap();
%if %sysevalf(&gapp<&gapcheck.) %then %do;
%put GAP IS < &gapcheck. TIMES GREATER THAN PRIORVAL. RANGE MAY NOT BE APPROPRIATE FOR THIS DATA.;
%end;
%mend;
%checkgap;


%macro findrange(marg);
data avardat_break;
   set avardat_gsort_last;

   if (avar_lag>=1 and avar>=1) or (avar_lag<=-1 and avar<=-1) then do;
      low=avar_lag+&marg.;
      up=avar-&marg.;
   end;

   else if -1<avar_lag<1 and (avar>=1 or avar<=-1) then do;
      avar_lagc = strip(put(avar_lag, best.)); *Creates character version with all decimals or E-xx if very small amount;
      if index(avar_lagc,'E-')>0 then lag_mag=input(substr(avar_lagc,(index(avar_lagc,'E-')+2)),8.); *if E-, grab next value for magnitude;
      else lag_mag=prxmatch('/[^0]/', substr(avar_lagc, index(avar_lagc, '.') + 1)); *Finding first non-zero position after decimal;

      low=avar_lag+(&marg.*(0.1**lag_mag));
      up=avar-&marg.;
   end;

   else if -1<avar_lag<1 and -1<avar<1 then do;
      avar_lagc = strip(put(avar_lag, best.)); *Creates character version with all decimals or E-xx if very small amount;
      if index(avar_lagc,'E-')>0 then lag_mag=input(substr(avar_lagc,(index(avar_lagc,'E-')+2)),8.); *if E-, grab next value for magnitude;
      else lag_mag=prxmatch('/[^0]/', substr(avar_lagc, index(avar_lagc, '.') + 1)); *Finding first non-zero position after decimal;

      avarc = strip(put(avar, best.)); *Creates character version with all decimals or E-xx if very small amount;
      if index(avarc,'E-')>0 then var_mag=input(substr(avarc,(index(avarc,'E-')+2)),8.); *if E-, grab next value for magnitude;
      else var_mag=prxmatch('/[^0]/', substr(avarc, index(avarc, '.') + 1)); *Finding first non-zero position after decimal;

      low=avar_lag+(&marg.*(0.1**lag_mag));
      up=avar+(&marg.*(0.1**var_mag));
   end;

   else if -1<avar<1 and avar_lag<=-1 then do;
      avarc = strip(put(avar, best.)); *Creates character version with all decimals or E-xx if very small amount;
      if index(avarc,'E-')>0 then var_mag=input(substr(avarc,(index(avarc,'E-')+2)),8.); *if E-, grab next value for magnitude;
      else var_mag=prxmatch('/[^0]/', substr(avarc, index(avarc, '.') + 1)); *Finding first non-zero position after decimal;

      low=avar_lag+&marg.;
      up=avar+(&marg.*(0.1**var_mag));
   end;

   diff=up-low;
   diffperc=diff/low;
      
run;

proc sql;
   select up into:upbreak from avardat_break;
   select low into:lowbreak from avardat_break;
   select diffperc into:diffp from avardat_break;
quit;

%put Upbreak=&Upbreak.
     Lowbreak=&Lowbreak.
     DiffP=&DiffP.;



%mend findrange;

%let stopobs=0;
%let ready=0;
%macro rangecheck();
%do %until (&ready=1);

   %findrange(&marg);
   %let stopobs=%sysevalf(&stopobs+1);

   %if %sysevalf(&upbreak<=&lowbreak) or %sysevalf(&diffp<&diffcheck.) %then %do;
      %let ready=0 ;
      %let marg=%sysevalf(&marg-1);
   %end;

   %else %if %sysevalf(&upbreak>&lowbreak) and %sysevalf(&diffp>=&diffcheck.) %then %do;
      %let ready=1;
   %end;

   %if %sysevalf(&stopobs>&obscheck.) %then %do;
      %put MAXIMUM NUMBER OF ITERATIONS REACHED. PLEASE REVIEW MARGIN AND PERCENTAGE DIFFERENCE INPUTS;
      %let ready=1;
   %end;

%end;
%mend rangecheck;

%rangecheck;

%mend breakit;