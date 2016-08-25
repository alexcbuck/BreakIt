<<<<<<< HEAD
/*--------------------------------------------------------------------------------------*

*******************************************************
***  Copyright Rho, Inc. 2016, all rights reserved  ***
*******************************************************

MACRO:      AxisRange.sas

PURPOSE:    Determine if RANGES is appropriate given the data.
            Generate VALUES or RANGES text for use in YAXIS/XAXIS statements of SGPLOT.

ARGUMENTS:   Data     => REQUIRED.   Input dataset. Same dataset will be used in SGPLOT call.
             Var      => REQUIRED.   The variable to be graphed on axis of interest and will be used to derive VALUES/RANGES recommendation.
             ChkPct   => REQUIRED.   The requested percentage of the overall range that a gap must meet to consider the use of RANGE appropriate. Default is 0.25 (25%).
             MarPct   => REQUIRED.   The requested space, as a percentage of effective range, to be added above/below RANGES values. 
                                     Purpose is to avoid clipping data points in the graph at the edge of the range. Default is 0.10 (10%).
             MaxGap   => REQUIRED.   Limits macro in number of gaps to be used. Default is 3 (max allowed in program).


OUTPUTS:     Macro Variables
             &OvMin:     The overall minimum value from the dataset
             &OvMax:     The overall maximum value from the dataset
             &FigText:   Text string for XAXIS/YAXIS statement composed of &FIGLOW/&FIGUP values.
                         If gap value meets criteria will use RANGES option. RANGES=(&FigLow1-&FigUp1 &FigLow2-&FigUp2)
                         Otherwise, VALUES option. VALUES=(&FigLow1 to &FigUp1 by &FigBy)                     
             &FigLow1:   The derived lower value for the first range. If gap value does not meet criteria for use of RANGES, will be the lower limit of the graph values.
             &FigUp1:    The derived upper value for the first range. If gap value does not meet criteria for use of RANGES, will be the upper limit of the graph values.
             &FigLow2:   The derived lower value for the second range. Only present if gap value meets criteria for use of RANGES.
             &FigUp2:    The derived upper value for the second range. Only present if gap value meets criteria for use of RANGES.
             &FigLow3:   The derived lower value for the third range. Only present if two gap values meets criteria for use of RANGES.
             &FigUp3:    The derived upper value for the third range. Only present if two gap values meets criteria for use of RANGES.
             &FigLow4:   The derived lower value for the fourth range. Only present if three gap values meets criteria for use of RANGES.
             &FigUp4:    The derived upper value for the fourth range. Only present if three gap values meets criteria for use of RANGES.
             &FigBy:     The derived axis increment/by value. Only present if gap value does not meet criteria for use of RANGES.

EXAMPLE1:    %BreakIt (Data=work.adlb,
                       Var=aval)

             proc sgplot data=work.adlb;
                  scatter x=time y=aval/group=trt01a;
                  yaxis &FigText.;
             run;

EXAMPLE2:    %BreakIt (Data=work.adlb,
                       Var=aval,
                       ChkPct=0.35,
                       MargPct=0.15)

             proc sgplot data=work.adlb;
                  scatter x=time y=aval/group=trt01a;
                  yaxis &FigText.;
             run;
   

Program History:

DATE        PROGRAMMER          DESCRIPTION
---------   ------------------  ------------------------------------------------------ 
2016-03-25   Alex Buck           Create program
2016-08-04   Alex Buck           Update to use %AXISORDER, percentage of overall and effective range. Allow for multiple gaps. Merge ranges if lower overlaps with upper.
*--------------------------------------------------------------------------------------*/

%Macro BreakIt(Data=,
               Var=,
               ChkPct=0.25,
               MarPct=0.10,
               MaxGap=3);

   %global OVMIN OVMAX FIGLOW1 FIGUP1 FIGLOW2 FIGUP2 FIGBY FIGTEXT;

/* Confirm data and variable exists */

   %if %sysfunc(exist(&Data)) eq %then %do;
      %put BreakIt -> THE INPUT DATASET [ &Data ] DOES NOT EXIST.;
      %put THE MACRO WILL STOP EXECUTING;
      %goto breakend;
   %end;

   %let dsid = %sysfunc(open(&Data));
   %if %sysfunc(varnum(&dsid,&Var))<=0 %then %do;
	  %put BreakIt -> THE INPUT Variable [ &Var ] DOES NOT EXIST.;
      %put THE MACRO WILL STOP EXECUTING;
      %goto breakend;
   %end;
   %let rc = %sysfunc(close(&dsid));



   data _bi_indat;
      set &Data.;
      where not missing(&Var.);
      avar=&Var.;
   run;

/* Find overall min and overall max */
   proc sql;
      select min(avar) into:OvMin_ from _bi_indat;
      select max(avar) into:OvMax_ from _bi_indat;
   quit;

   %let OvMin=&OvMin_.;
   %let OvMax=&OvMax_.;

/* Find gap between ordered values*/
   proc sort data=_bi_indat out=_bi_indat_asort;
      by avar;
   run;

   data _bi_gap;
      set _bi_indat_asort;
      by avar;

      avar_lag=lag(avar);
      if nmiss(avar,avar_lag)=0 then avar_gap=avar-avar_lag;
   run;

   proc sort data=_bi_gap out=_bi_gapsort;
      by avar_gap;
   run;



/* 
Find overall range. If gap is greater than the user-defined percent of overall range, set flag.
Find effective range, excluding unused whitespace from the gap. 
Create lower and upper limits for each range using the user-defined percent of the effective range to set the margin.
Keep the obervation with gap meeting criteria. If no gap meets criteria, keep last observation.
*/
   data _bi_gapfl;
      set _bi_gapsort end=eof;
      by avar_gap;

      min=&OvMin.;
      max=&OvMax.;
      ovrange=max-min;
      if avar_gap >= (ovrange*&ChkPct.) then gapfl='Y';

      if gapfl='Y' or eof;
      call symputx('GapFl',gapfl);
   run;

/* 
If no gaps meet criteria, a range will not be produced.
Find Lower, Upper, and By values from %AXISORDER.
Produce text string for AXIS statment, VALUES option
*/
   %if &GapFl.^=Y %then %do;

      %put BREAKIT -> The largest gap is not greater than the user-specified cutoff (OvRange * [ &ChkPct. ]). RANGES option is not appropriate.;

      %axisorder(data=_bi_indat, var=avar);
      %let FigLow1=&_AxisStart.;
      %let FigUp1=&_AxisEnd.;
      %let FigBy=&_AxisBy.;
      %let FigText=%str(VALUES=(&FigLow1. to &FigUp1. by &Figby.));

/* List Final Macro Values */
      %put OvMin    = [ &OvMin. ];
      %put OvMax    = [ &OvMax. ];
      %put FigLow1  = [ &FigLow1. ];
      %put FigUp1   = [ &FigUp1. ];
      %put FigBy    = [ &FigBy. ];
      %put FigText  = [ &FigText. ];

   %end;

   

/*
If gap is large is enough, set values for RANGE
*/
   %else %do;

   /* Find number of gaps (max is 3). Retain AVAR/AVAR_LAG values to create 1 final observation with all information */

      proc sort data=_bi_gapfl;
         by descending avar_gap;
      run;

      data _bi_gapfl_ngap;
         set _bi_gapfl;

         retain ngap_ 0;
         if _n_=1 then ngap_=ngap_+1;
         if _n_=2 then ngap_=ngap_+1;
         if _n_=3 then ngap_=ngap_+1;

         if _n_<=&MaxGap.;
      run;

      proc sort data=_bi_gapfl_ngap out=_bi_gapfl_asort;
         by avar_lag;
      run;

      data _bi_gapanly;
         set _bi_gapfl_asort end=eof;
      
         retain ravar_lag1 ravar1 ravar_lag2 ravar2 ravar_lag3 ravar3 . ngap 0;

         if _n_=1 then do;
            ravar_lag1=avar_lag;
            ravar1=avar;
            ngap=ngap+1;
         end;
   
         if _n_=2 then do;
            ravar_lag2=avar_lag;
            ravar2=avar;
            ngap=ngap+1;
         end;

         if _n_=3 then do;
            ravar_lag3=avar_lag;
            ravar3=avar;
            ngap=ngap+1;
         end;

         if eof;
         call symputx('NGap',ngap);
         keep ravar: min max ngap;
      run;

      /* Create range values based on effective range between each gap */
      data _bi_range;
         set _bi_gapanly;

         if ngap=1 then do;
            effrange1  = (max-ravar1)+(ravar_lag1-min);
            low1       = min - (effrange1*&MarPct.);
            up1        = ravar_lag1 + (effrange1*&MarPct.);
            low2       = ravar1 - (effrange1*&MarPct.);
            up2        = max+ (effrange1*&MarPct.);

            *If upper value in previous range is larger than lower than lower value if current range, put note in log;
            *Set &NGAP=0 to use AXISORDER and return VALUES text.;
            if up1>=low2 then do;
               putlog "BREAKIT -> UP1 >= LOW2. Review MarPct. Ranges will be merged. Macro will return VALUES text";
               call symputx('NGAP',0);
            end;
         end;

         if ngap=2 then do;
            effrange1  = (ravar_lag2-ravar1)+(ravar_lag1-min);
            effrange2  = (max-ravar2)+(ravar_lag2-ravar1);
            effrange12 = max(effrange1,effrange2);
            low1       = min - (effrange1*&MarPct.);
            up1        = ravar_lag1 + (effrange1*&MarPct.);
            low2       = ravar1 - (effrange12*&MarPct.);
            up2        = ravar_lag2 + (effrange12*&MarPct.);
            low3       = ravar2 - (effrange2*&MarPct.);
            up3        = max + (effrange2*&MarPct.);

            *If upper value in previous range is larger than lower than lower value if current range, put note in log and merge ranges that overlap;
            *Reset &NGAP to reflect new gap numbers;
            if up1>=low2 then do;
               putlog "BREAKIT -> UP1 >= LOW2. Review MarPct and/or MaxGap. Ranges will be merged";
            end;
            if up2>=low3 then do;
               putlog "BREAKIT -> UP2 >= LOW3. Review MarPct and/or MaxGap. Ranges will be merged";
            end;
            *If all ranges overlap return VALUES text.;
            if up1>=low2 and up2>=low3 then do;
               call symputx('NGAP',0);
            end;
            *Else merge ranges as needed. Reset values to reflect new number of gaps.;
            else if up1>=low2 and up2<low3 then do;
               up1=up2;
               low2=low3;
               up2=up3;
               call symputx('NGAP',1);
            end;
            else if up2>=low3 and up1<low2 then do;
               up2=up3;
               call symputx('NGAP',1);
            end;


         end;

         if ngap=3 then do;
            effrange1  = (ravar_lag2-ravar1)+(ravar_lag1-min);
            effrange2  = (ravar_lag3-ravar2)+(ravar_lag2-ravar1);
            effrange12 = max(effrange1,effrange2);
            effrange3  = (max-ravar3)+(ravar_lag3-ravar2);
            effrange23 = max(effrange3,effrange2);
            low1       = min - (effrange1*&MarPct.);
            up1        = ravar_lag1 + (effrange1*&MarPct.);
            low2       = ravar1 - (effrange1*&MarPct.);
            up2        = ravar_lag2 + (effrange1*&MarPct.);
            low3       = ravar2 - (effrange2*&MarPct.);
            up3        = ravar_lag3 + (effrange2*&MarPct.);
            low4       = ravar3 - (effrange3*&MarPct.);
            up4        = max + (effrange3*&MarPct.);

            *If upper value in previous range is larger than lower than lower value if current range, put note in log and merge ranges that overlap;
            *Reset &NGAP to reflect new gap numbers;
            if up1>=low2 then do;
               putlog "BREAKIT -> UP1 >= LOW2. Review MarPct and/or MaxGap";
            end;
            if up2>=low3 then do;
               putlog "BREAKIT -> UP2 >= LOW3. Review MarPct and/or MaxGap";
            end;
            if up3>=low4 then do;
               putlog "BREAKIT -> UP3 >= LOW4. Review MarPct and/or MaxGap";
            end;
            *If all ranges overlap return VALUES text.;
            if up1>=low2 and up2>=low3 and up3>=low4 then do;
               call symputx('NGAP',0);
            end;
            *Else merge ranges as needed. Reset values to reflect new number of gaps.;
            else if up1>=low2 and up2<low3 and up3<low4 then do;
               up1=up2;
               low2=low3;
               up2=up3;
               low3=low4;
               up3=up4;
               call symputx('NGAP',2);
            end;
            else if up2>=low3 and up1<low2 and up3<low4 then do;
               up2=up3;
               low3=low4;
               up3=up4;
               call symputx('NGAP',2);
            end;
            else if up3>=low4 and up1<low2 and up2<low3 then do;
               up3=up4;
               call symputx('NGAP',2);
            end;
            else if up1>=low2 and up2>=low3 and up3<low4 then do;
               up1=up3;
               low2=low4;
               up2=up4;
               call symputx('NGAP',1);
            end;
            else if up1>=low2 and up3>=low4 and up2<low3 then do;
               up1=up2;
               low2=low3;
               up2=up4;
               call symputx('NGAP',1);
            end;
            else if up2>=low3 and up3>=low4 and up1<low2 then do;
               up2=up4;
               call symputx('NGAP',1);
            end;
         end;

      
      run;

      %if &NGap.=1 %then %do;

         proc sql;
            select low1 into:low1 from _bi_range;
            select up1  into:up1 from _bi_range;
            select low2 into:low2 from _bi_range;
            select up2  into:up2 from _bi_range;
         quit;

         %let FigLow1 = &low1.;
         %let FigUp1  = &up1.;
         %let FigLow2 = &low2.;
         %let FigUp2  = &up2.;
         %let FigText = %str(RANGES=(&FigLow1.-&FigUp1. &FigLow2.-&FigUp2.));

      /* List Final Macro Values */
            %put OvMin    = [ &OvMin. ];
            %put OvMax    = [ &OvMax. ];
            %put FigLow1  = [ &FigLow1. ];
            %put FigUp1   = [ &FigUp1. ];
            %put FigLow2  = [ &FigLow2. ];
            %put FigUp2   = [ &FigUp2. ];
            %put FigText  = [ &FigText. ];

      %end;


      %if &NGap.=2 %then %do;

         proc sql;
            select low1 into:low1 from _bi_range;
            select up1  into:up1 from _bi_range;
            select low2 into:low2 from _bi_range;
            select up2  into:up2 from _bi_range;
            select low3 into:low3 from _bi_range;
            select up3  into:up3 from _bi_range;
         quit;

         %let FigLow1 = &low1.;
         %let FigUp1  = &up1.;
         %let FigLow2 = &low2.;
         %let FigUp2  = &up2.;
         %let FigLow3 = &low3.;
         %let FigUp3  = &up3.;
         %let FigText = %str(RANGES=(&FigLow1.-&FigUp1. &FigLow2.-&FigUp2. &FigLow3.-&FigUp3.));

      /* List Final Macro Values */
         %put OvMin    = [ &OvMin. ];
         %put OvMax    = [ &OvMax. ];
         %put FigLow1  = [ &FigLow1. ];
         %put FigUp1   = [ &FigUp1. ];
         %put FigLow2  = [ &FigLow2. ];
         %put FigUp2   = [ &FigUp2. ];
         %put FigLow3  = [ &FigLow3. ];
         %put FigUp3   = [ &FigUp3. ];
         %put FigText  = [ &FigText. ];

      %end;


      %if &NGap.=3 %then %do;

         proc sql;
            select low1 into:low1 from _bi_range;
            select up1  into:up1 from _bi_range;
            select low2 into:low2 from _bi_range;
            select up2  into:up2 from _bi_range;
            select low3 into:low3 from _bi_range;
            select up3  into:up3 from _bi_range;
            select low4 into:low4 from _bi_range;
            select up4  into:up4 from _bi_range;
         quit;

         %let FigLow1 = &low1.;
         %let FigUp1  = &up1.;
         %let FigLow2 = &low2.;
         %let FigUp2  = &up2.;
         %let FigLow3 = &low3.;
         %let FigUp3  = &up3.;
         %let FigLow4 = &low4.;
         %let FigUp4  = &up4.;
         %let FigText = %str(RANGES=(&FigLow1.-&FigUp1. &FigLow2.-&FigUp2. &FigLow3.-&FigUp3. &FigLow4.-&FigUp4.));

      /* List Final Macro Values */
         %put OvMin    = [ &OvMin. ];
         %put OvMax    = [ &OvMax. ];
         %put FigLow1  = [ &FigLow1. ];
         %put FigUp1   = [ &FigUp1. ];
         %put FigLow2  = [ &FigLow2. ];
         %put FigUp2   = [ &FigUp2. ];
         %put FigLow3  = [ &FigLow3. ];
         %put FigUp3   = [ &FigUp3. ];
         %put FigLow4  = [ &FigLow4. ];
         %put FigUp4   = [ &FigUp4. ];
         %put FigText  = [ &FigText. ];

      %end;

       %if &NGap=0 %then %do;

         %axisorder(data=_bi_indat, var=avar);
          %let FigLow1=&_AxisStart.;
          %let FigUp1=&_AxisEnd.;
          %let FigBy=&_AxisBy.;
          %let FigText=%str(VALUES=(&FigLow1. to &FigUp1. by &Figby.));

    /* List Final Macro Values */
          %put OvMin    = [ &OvMin. ];
          %put OvMax    = [ &OvMax. ];
          %put FigLow1  = [ &FigLow1. ];
          %put FigUp1   = [ &FigUp1. ];
          %put FigBy    = [ &FigBy. ];
          %put FigText  = [ &FigText. ];

      %end;


   %end;

  

 %breakend:

%mend breakit;
=======
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
>>>>>>> origin/master
