#!/bin/awk -f


#######################################################################
#
# Because of awk problems on the sgi, this file is converted to perl
# via 'a2p' to yield 'protify'.  Do not edit the perl version!!!!
#
#######################################################################


BEGIN {

  printf("\n");
  printf("/******************************************************  \n");
  printf(" * WARNING: This file automatically generated.        *  \n");
  printf(" ******************************************************  \n");
  printf(" */                                                      \n");
  printf("\n\n\n\n");
}


/[ \t]*extern/ { next }
/main\(/ { next }

/FORT_NAME/ {next}

# Ignore doctext comments
/\/\*[DMN@]/ { while (!match($0,/[DMN@]\*\//)) getline; next; }


/^[^ \t{}/*#].*[^ \t]+\(.*[^;]*$/ \
   {
     if ($1=="static")
       next;                   #continue;

     printf("extern %s",$0);

     while (!match($0,"\)"))
       {
         getline;
	 gsub("\t","        ");
         printf("\n       %s",$0);
       }
     printf(";\n");
   }
