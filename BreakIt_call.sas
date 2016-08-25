libname testdata H:\My Documents\Presentations\Breakit\Data";

%let pgmdir = H:\My Documents\Presentations\Breakit\;

option 
   sasautos=("&pgmdir" sasautos)
   mprint
   ;

libname testdata "&pgmdir.\Data";
ods listing
   gpath = "&pgmdir"
   ;

ods graphics / 
   reset=all
   ;

%Breakit(data=testdata.norm_trtdiff_2gap,var=value,chkpct=0.25,marpct=0.10);

ods rtf file='H:\My Documents\Presentations\Breakit\Figures\Norm_trtdiff_2gap.rtf'; 

proc sgplot data=testdata.norm_trtdiff_2gap;
   scatter x=time y=value/group=trtn ;
   yaxis &FigText.;
run;

ods rtf close;