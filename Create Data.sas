data norm_trtdiff;
   do i=1 to 2;
      do j=1 to 100;
         do k=1 to 10;
         trtn=i;
         subject=j;
         time=k; 
         if trtn=1 then value=rand('NORMAL',10,1);
         else if trtn=2 then value=rand('NORMAL',100, 1);output;
         end;
      end;
   end;

   label trtn='Treatment Group' time='Time Point' value='Value of Interest';
   
run;

libname testdata "H:\My Documents\Presentations\PharmaSUG 2016\Data";

data testdata.norm_trtdiff;
   set norm_trtdiff;
run;

data norm_outlier;
   do i=1 to 2;
      do j=1 to 100;
         do k=1 to 10;
         trtn=i;
         subject=j;
         time=k; 
         if trtn=2 and subject=78 and time=6 then value=rand('NORMAL',75,3);
         else value=rand('NORMAL',10, 2);output;
         end;
      end;
   end;

   label trtn='Treatment Group' time='Time Point' value='Value of Interest'; 
 
run;

data testdata.norm_outlier;
   set norm_outlier;
run;