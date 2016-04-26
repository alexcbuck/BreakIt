libname testdata "H:\My Documents\Presentations\PharmaSUG 2016\Data";

%include "H:\My Documents\Presentations\PharmaSUG 2016\breakit.sas";


%breakit(inputdat=testdata.norm_trtdiff,
         inval=value,
         gapcheck=2,
         marg=5,
         diffcheck=2,
         obscheck=100);


ods rtf file='H:\My Documents\Presentations\PharmaSUG 2016\Figures\Norm_trtdiff_final_test.rtf'; 

proc sgplot data=indat;
   scatter x=time y=value/group=trtn ;
   yaxis ranges=(&ovmin.-&lowbreak. &upbreak.-&ovmax.);
run;

ods rtf close;