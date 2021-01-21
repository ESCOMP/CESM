#!/usr/bin/env perl

use strict;
use warnings;
use FileHandle;
use File::stat;
use File::Basename;
use Getopt::Long;

my($verbose);
my($nargs);
my($template_fname, $output_fname);
# If the template source has PIO_TF_AUTO_TEST* and the test
# does not have a test driver we need to create it
# Auto test functions do not have any arguments so our life is easy
my($template_has_auto_funcs, $template_has_test_driver);
# Indicates whether auto funcs have already been inserted
my($template_auto_funcs_inserted);
# Used to disable write of template functions - the template
# functions are read in the first pass and inserted just before
# the driver
# 0 => write is NOT disabled
# 1 => write is disabled
my($template_disable_wr);
my($annotate_source);
# The current test case number is modified by multiple funcs
# * its logically easier to keep it a global
my($cur_test_case_num);

# template function name ==> template function body
my (%template_funcs);
# template function name ==> template function typenames
my (%template_func_typenames);
# template function typename ==> concrete types
my (%template_typename_types);
# Predefined typename ==> predefined types
my (%template_predef_typename_types);

# Initializing global vars
$verbose = 0;
$nargs = 0;
$template_fname = '';
$output_fname = '';
$template_has_auto_funcs = 0;
$template_auto_funcs_inserted = 0;
$template_disable_wr = 0;
$template_has_test_driver = 0;
$annotate_source = 0;
$cur_test_case_num = 1;

# Initialize predefined types
sub init_predef_types
{
  $template_predef_typename_types{"PIO_TF_DATA_TYPE"} = [];
  $template_predef_typename_types{"PIO_TF_FC_DATA_TYPE"} = [];
  push(@{$template_predef_typename_types{"PIO_TF_DATA_TYPE"}}, "PIO_int");
  push(@{$template_predef_typename_types{"PIO_TF_FC_DATA_TYPE"}}, "integer(kind=fc_int)");
  push(@{$template_predef_typename_types{"PIO_TF_DATA_TYPE"}}, "PIO_short");
  push(@{$template_predef_typename_types{"PIO_TF_FC_DATA_TYPE"}}, "integer(kind=fc_short)");
  push(@{$template_predef_typename_types{"PIO_TF_DATA_TYPE"}}, "PIO_real");
  push(@{$template_predef_typename_types{"PIO_TF_FC_DATA_TYPE"}}, "real(kind=fc_real)");
  push(@{$template_predef_typename_types{"PIO_TF_DATA_TYPE"}}, "PIO_double");
  push(@{$template_predef_typename_types{"PIO_TF_FC_DATA_TYPE"}}, "real(kind=fc_double)");
}

# Generates the generic template function bodies (or names)
sub generate_gen_templates
{
  my ($gen_templ_func_name, $ref_modif_gen_templ_func_names,
      $base_file_name, $ifline_num) = @_;
  my ($gen_templ_func_bodies) = "";

  # Find typenames for the template and corresponding concrete types
  my (@typenames);
  my ($ntypenames);
  my (@typename_counter, @typename_counter_max);
  my ($typename);

  if($verbose) {print "Going to generate functions from \"$gen_templ_func_name\"\n"; }
  if(not exists $template_func_typenames{$gen_templ_func_name}){
    print "ERROR: Error parsing template file ($base_file_name:$ifline_num)\n";
    print "       Check the name of the function\n";
    return "";
  }
  @typenames = @{$template_func_typenames{$gen_templ_func_name}};
  $ntypenames = @typenames;
  if($verbose) { print "TYPENAMES: " . join(",",@typenames) . " : $ntypenames\n"; }
  if($ntypenames < 1){
    if($verbose) {print "WARNING: No typenames to generate template func name ($gen_templ_func_name)\n";}
    return "";
  }
  foreach $typename (@typenames){
    if(exists $template_predef_typename_types{$typename}){
      my $ntypes;
      $ntypes = @{$template_predef_typename_types{$typename}};
      push(@typename_counter, 0);
      push(@typename_counter_max, $ntypes);
    }
    else{
      print "ERROR: Only predefined types are allowed in template functions\n";
      print "       $base_file_name:$ifline_num\n";
      print "       \"$typename\" is NOT a predefined type\n";
      return "";
    }
  }

  # We are guaranteed there is atleast one typename and it has some (>1)
  # predefined types
  my ($cnt_max) = 1;
  my ($i, $j, $k);
  for($i=0; $i < $ntypenames; $i++){
    if($cnt_max < $typename_counter_max[$i]){
      $cnt_max = $typename_counter_max[$i];
    }
  }
  my $gen_templ_func_body = "";
  for($i=0; $i < $cnt_max; $i++){
    my (@concrete_types);

    $gen_templ_func_body = $template_funcs{$gen_templ_func_name};
    for($j=0; $j < $ntypenames; $j++){
      my ($ctype);
      $ctype = @{$template_predef_typename_types{$typenames[$j]}}[$typename_counter[$j]];
      $gen_templ_func_body =~ s/$typenames[$j]/$ctype/mg;
      $ctype =~ s/[(]/_/g;
      $ctype =~ s/[)]/_/g;
      $ctype =~ s/[=]/_/g;
      push(@concrete_types, $ctype);
    }
    $typename_counter[0] += 1;
    for($k = $ntypenames - 1; $k > 0; $k--){
      $typename_counter[$k] += 1;
      if($typename_counter[$k] >= $typename_counter_max[$k]){
        $typename_counter[$k] = 0;
        $typename_counter[$k - 1] += 1;
      }
    }
    my ($modif_gen_templ_func_name) = $gen_templ_func_name;
    my ($type);
    $modif_gen_templ_func_name .= "_" . join("_", @concrete_types) . "__";
    push(@{$ref_modif_gen_templ_func_names}, $modif_gen_templ_func_name);
    $gen_templ_func_body =~ s/$gen_templ_func_name/$modif_gen_templ_func_name/mg;

    $gen_templ_func_bodies .= "\n\n" . $gen_templ_func_body;
    $gen_templ_func_body = "";
    undef(@concrete_types);
  }
  if($verbose) {print "GENERATED TEMPLATE FUNCTIONS: \n" . $gen_templ_func_bodies; }
  return $gen_templ_func_bodies;
}

# FIXME - Not used, kept around so that the logic is not lost
# Could be used to generate templates with all permutations of the typenames
sub generate_gen_templates_all_permutes
{
  my ($gen_templ_func_name, $ref_modif_gen_templ_func_names,
      $base_file_name, $ifline_num) = @_;
  my ($gen_templ_func_bodies) = "";

  # Find typenames for the template and corresponding concrete types
  my (@typenames);
  my ($ntypenames);
  my (@typename_counter, @typename_counter_max);
  my ($typename);

  if($verbose) {print "Going to generate functions from \"$gen_templ_func_name\"\n"; }
  if(not exists $template_func_typenames{$gen_templ_func_name}){
    print "ERROR: Error parsing template file ($base_file_name:$ifline_num)\n";
    print "       Check the name of the function\n";
    return "";
  }
  @typenames = @{$template_func_typenames{$gen_templ_func_name}};
  $ntypenames = @typenames;
  if($verbose) { print "TYPENAMES: " . join(",",@typenames) . " : $ntypenames\n"; }
  if($ntypenames < 1){
    if($verbose) {print "WARNING: No typenames to generate template func name ($gen_templ_func_name)\n";}
    return "";
  }
  foreach $typename (@typenames){
    if(exists $template_predef_typename_types{$typename}){
      my $ntypes;
      $ntypes = @{$template_predef_typename_types{$typename}};
      push(@typename_counter, 0);
      push(@typename_counter_max, $ntypes);
    }
    else{
      print "ERROR: Only predefined types are allowed in template functions\n";
      print "       $base_file_name:$ifline_num\n";
      print "       \"$typename\" is NOT a predefined type\n";
      return "";
    }
  }

  # We are guaranteed there is atleast one typename and it has some (>1)
  # predefined types
  my ($cnt_max) = 1;
  my ($i, $j, $k);
  for($i=0; $i < $ntypenames; $i++){
    $cnt_max *= $typename_counter_max[$i];
  }
  my $gen_templ_func_body = "";
  for($i=0; $i < $cnt_max; $i++){
    my (@concrete_types);

    $gen_templ_func_body = $template_funcs{$gen_templ_func_name};
    for($j=0; $j < $ntypenames; $j++){
      my ($ctype);
      $ctype = @{$template_predef_typename_types{$typenames[$j]}}[$typename_counter[$j]];
      push(@concrete_types, $ctype);
      $gen_templ_func_body =~ s/$typenames[$j]/$ctype/mg;
    }
    $typename_counter[$ntypenames - 1] += 1;
    for($k = $ntypenames - 1; $k > 0; $k--){
      if($typename_counter[$k] >= $typename_counter_max[$k]){
        $typename_counter[$k] = 0;
        $typename_counter[$k - 1] += 1;
      }
    }
    my ($modif_gen_templ_func_name) = $gen_templ_func_name;
    my ($type);
    $modif_gen_templ_func_name .= "_" . join("_", @concrete_types) . "__";
    push(@{$ref_modif_gen_templ_func_names}, $modif_gen_templ_func_name);
    $gen_templ_func_body =~ s/$gen_templ_func_name/$modif_gen_templ_func_name/mg;

    $gen_templ_func_bodies .= "\n\n" . $gen_templ_func_body;
    $gen_templ_func_body = "";
    undef(@concrete_types);
  }
  if($verbose) {print "GENERATED TEMPLATE FUNCTIONS: \n" . $gen_templ_func_bodies; }
  return $gen_templ_func_bodies;
}

# This function transforms the template source one line at a time
# * Does the transformation of the template source
sub transform_src
{
  my($ref_auto_funcs_list, $in_line, $template_fname, $template_line_no, $ref_modif) = @_;
  my($out_line);
  if($verbose){ print "Transforming: $in_line\n"; }
  $_ = $in_line;
  # By default assume that source is transformed/modified
  # reset otherwise
  $$ref_modif = 1;
  if(/^(\s*)(PIO_TF_TEST_SUB_BEGIN)(.*)$/s){
      $out_line = "# $template_line_no \"$template_fname\"\n";
      $out_line .= $1 . "SUBROUTINE" . $3 . "\n";
      $out_line .= $1 . "  USE pio_tutil\n";
  }
  elsif(/^(\s*)(PIO_TF_TEST_SUB_END)(.*)$/s){
    if($template_disable_wr == 0){
      $out_line = $1 . "END SUBROUTINE" . $3;
    }
    else{
      $out_line = $1;
      $template_disable_wr = 0;
    }
  }
  elsif(/^(\s*)(PIO_TF_AUTO_TEST_SUB_BEGIN)(\s*)(.*)$/s){
    $out_line = $1 . "SUBROUTINE" . $3 . $4 . "\n";
    $out_line = $out_line . $1 . "  USE pio_tutil\n";
    $template_has_auto_funcs = 1;

    # Add auto test func into the auto func list
    if($template_disable_wr == 0){
      push @{$ref_auto_funcs_list}, $4;
    }
  }
  elsif(/^(\s*)(PIO_TF_AUTO_TEST_SUB_END)(\s*)(.*)\s*$/s){
    if($template_disable_wr == 0){
      $out_line = $1 . "END SUBROUTINE" . $3 . $4;
    }
    else{
      my (@gen_templ_func_names);
      $out_line = generate_gen_templates($4, \@gen_templ_func_names,
                    $template_fname, $template_line_no);
      $template_disable_wr = 0;
    }
  }
  elsif(/^(\s*)(PIO_TF_TEMPLATE)(.*)$/s){
    $out_line = $1 . "";
    $template_disable_wr = 1;
  }
  elsif(/^(\s*)(PIO_TF_TEST_DRIVER_BEGIN)(.*)$/s){
    $out_line = $1 . "SUBROUTINE PIO_TF_Test_driver_" . $3 . "\n";
    $out_line = $out_line . $1 . "  USE pio_tutil\n";
    $template_has_test_driver = 1;
  }
  elsif(/^(\s*)(PIO_TF_TEST_DRIVER_END)(.*)$/s){
    # Make sure to add any auto test functions before the end
    $out_line = $1 . "\n";
    if($template_auto_funcs_inserted == 0){
    foreach(@{$ref_auto_funcs_list}){
      $out_line = $out_line . $1 . "  pio_tf_retval_utest_ = 0\n";
      $out_line = $out_line . $1 . "  IF (pio_tf_world_rank_ == 0) THEN\n";
      $out_line = $out_line . $1 . "    PRINT *, \"PIO_TF: Starting $_\"\n";
      $out_line = $out_line . $1 . "  END IF\n";
      $out_line = $out_line . $1 . "  CALL $_()\n";
      $out_line = $out_line . $1 . "  IF (pio_tf_retval_utest_ /= 0) THEN\n";
      $out_line = $out_line . $1 . "    pio_tf_nerrs_total_ = pio_tf_nerrs_total_ + 1\n";
      $out_line = $out_line . $1 . "  END IF\n";
      $out_line = $out_line . $1 . "  IF (pio_tf_world_rank_ == 0) THEN\n";
      $out_line = $out_line . $1 . "    IF (pio_tf_retval_utest_ == 0) THEN\n";
      $out_line = $out_line . $1 . "      WRITE(*,PIO_TF_TEST_RES_FMT) \"PIO_TF:Test $cur_test_case_num:\",&\n";
      $out_line = $out_line . $1 . "        \"$_\",&\n";
      $out_line = $out_line . $1 . "        \"---------\",\"PASSED\"\n";
      $out_line = $out_line . $1 . "    ELSE\n";
      $out_line = $out_line . $1 . "      WRITE(*,PIO_TF_TEST_RES_FMT) \"PIO_TF:Test $cur_test_case_num:\",&\n";
      $out_line = $out_line . $1 . "        \"$_\",&\n";
      $out_line = $out_line . $1 . "        \"---------\",\"FAILED\"\n";
      $out_line = $out_line . $1 . "    END IF\n";
      $out_line = $out_line . $1 . "  END IF\n";
      $cur_test_case_num += 1;
    }
    }
    $out_line = $out_line . $1 . "END SUBROUTINE PIO_TF_Test_driver_" . $3;
  }
  elsif(/^(\s*)(PIO_TF_AUTO_TESTS_RUN)\((.*)\)\s*$/s){
    # Make sure to add any auto test functions before the end
    $out_line = $1 . "\n";
    $out_line = $out_line . $1 . "  IF (pio_tf_world_rank_ == 0) THEN\n";
    $out_line = $out_line . $1 . "    PRINT *, \"PIO_TF: Running AUTO tests: \", $3\n";
    $out_line = $out_line . $1 . "  END IF\n";
    foreach(@{$ref_auto_funcs_list}){
      $out_line = $out_line . $1 . "  pio_tf_retval_utest_ = 0\n";
      $out_line = $out_line . $1 . "  pio_tf_tmp_log_str_=\"$_\"//\"(\"//$3//\")\"\n";
      $out_line = $out_line . $1 . "  IF (pio_tf_world_rank_ == 0) THEN\n";
      $out_line = $out_line . $1 . "    PRINT *, \"PIO_TF: Starting $_\"\n";
      $out_line = $out_line . $1 . "  END IF\n";
      $out_line = $out_line . $1 . "  CALL $_()\n";
      $out_line = $out_line . $1 . "  IF (pio_tf_retval_utest_ /= 0) THEN\n";
      $out_line = $out_line . $1 . "    pio_tf_nerrs_total_ = pio_tf_nerrs_total_ + 1\n";
      $out_line = $out_line . $1 . "  END IF\n";
      $out_line = $out_line . $1 . "  IF (pio_tf_world_rank_ == 0) THEN\n";
      $out_line = $out_line . $1 . "    IF (pio_tf_retval_utest_ == 0) THEN\n";
      $out_line = $out_line . $1 . "      WRITE(*,PIO_TF_TEST_RES_FMT) \"PIO_TF:Test $cur_test_case_num:\",&\n";
      $out_line = $out_line . $1 . "        pio_tf_tmp_log_str_,&\n";
      $out_line = $out_line . $1 . "        \"---------\",\"PASSED\"\n";
      $out_line = $out_line . $1 . "    ELSE\n";
      $out_line = $out_line . $1 . "      WRITE(*,PIO_TF_TEST_RES_FMT) \"PIO_TF:Test $cur_test_case_num:\",&\n";
      $out_line = $out_line . $1 . "        pio_tf_tmp_log_str_,&\n";
      $out_line = $out_line . $1 . "        \"---------\",\"FAILED\"\n";
      $out_line = $out_line . $1 . "    END IF\n";
      $out_line = $out_line . $1 . "  END IF\n";
      $cur_test_case_num += 1;
    }
    $template_auto_funcs_inserted = 1;
  }
  elsif(/^(\s*)PIO_TF_TEST_RUN\(\s*([^(]+)\((.*)\),(.*)\)\s*$/s){
    my ($test_name) = $2;
    my ($test_args) = $3;
    # $4 is $comment

    $out_line = $1 . "\n";
    $out_line = $out_line . $1 . "pio_tf_retval_utest_ = 0\n";
    $out_line = $out_line . $1 . "pio_tf_tmp_log_str_=\"$test_name\"//\"(\"//$4//\")\"\n";
    $out_line = $out_line . $1 . "IF (pio_tf_world_rank_ == 0) THEN\n";
    $out_line = $out_line . $1 . "  PRINT *, \"PIO_TF: Starting \",&\n";
    $out_line = $out_line . $1 . "    pio_tf_tmp_log_str_\n";
    $out_line = $out_line . $1 . "END IF\n";
    $out_line = $out_line . $1 . "CALL $test_name($test_args)\n";
    $out_line = $out_line . $1 . "IF (pio_tf_retval_utest_ /= 0) THEN\n";
    $out_line = $out_line . $1 . "  pio_tf_nerrs_total_ = pio_tf_nerrs_total_ + 1\n";
    $out_line = $out_line . $1 . "END IF\n";
    $out_line = $out_line . $1 . "IF (pio_tf_world_rank_ == 0) THEN\n";
    $out_line = $out_line . $1 . "  IF (pio_tf_retval_utest_ == 0) THEN\n";
    $out_line = $out_line . $1 . "    WRITE(*,PIO_TF_TEST_RES_FMT) \"PIO_TF:Test $cur_test_case_num:\",&\n";
    $out_line = $out_line . $1 . "      pio_tf_tmp_log_str_,&\n";
    $out_line = $out_line . $1 . "      \"--------\", \"PASSED\"\n";
    $out_line = $out_line . $1 . "  ELSE\n";
    $out_line = $out_line . $1 . "    WRITE(*,PIO_TF_TEST_RES_FMT) \"PIO_TF:Test $cur_test_case_num:\",&\n";
    $out_line = $out_line . $1 . "      pio_tf_tmp_log_str_,&\n";
    $out_line = $out_line . $1 . "      \"--------\", \"FAILED\"\n";
    $out_line = $out_line . $1 . "  END IF\n";
    $out_line = $out_line . $1 . "END IF";
    $cur_test_case_num += 1;
}
  elsif(/^(\s*)PIO_TF_PASSERT\((.+),([^,]+),([^)]+)\)(.*)$/s){
    $out_line = $1 . $5 . "\n";
    $out_line = $out_line . $1 . "IF (.NOT. (PIO_TF_Passert_($2, $3))) THEN\n";
    $out_line = $out_line . $1 . "  call MPI_COMM_RANK($3, pio_tf_tmp_comm_rank_, pio_tf_retval_utest_)\n";
    $out_line = $out_line . $1 . "  pio_tf_retval_utest_ = -1\n";
    $out_line = $out_line . $1 . "  IF (pio_tf_tmp_comm_rank_ == 0) THEN\n";
    $out_line = $out_line . $1 . "    PRINT *, \"PIO_TF: Assertion failed :\",&\n";
    $out_line = $out_line . $1 . "      " . $4 . ",&\n";
    $out_line = $out_line . $1 . "       \":\", __FILE__, \":\", __LINE__,&\n";
    $out_line = $out_line . $1 . "      " . "\"($template_fname:$template_line_no)\"\n";
    $out_line = $out_line . $1 . "  END IF\n";
    $out_line = $out_line . $1 . "  RETURN\n";
    $out_line = $out_line . $1 . "END IF";
  }
  elsif(/^(\s*)PIO_TF_PASSERT\((.+),([^)]+)\)(.*)$/s){
    $out_line = $1 . $4 . "\n";
    $out_line = $out_line . $1 . "IF (.NOT. (PIO_TF_Passert_($2, pio_tf_comm_))) THEN\n";
    $out_line = $out_line . $1 . "  pio_tf_retval_utest_ = -1\n";
    $out_line = $out_line . $1 . "  IF (pio_tf_world_rank_ == 0) THEN\n";
    $out_line = $out_line . $1 . "    PRINT *, \"PIO_TF: Assertion failed :\",&\n";
    $out_line = $out_line . $1 . "      " . $3 . ",&\n";
    $out_line = $out_line . $1 . "       \":\", __FILE__, \":\", __LINE__,&\n";
    $out_line = $out_line . $1 . "      " . "\"($template_fname:$template_line_no)\"\n";
    $out_line = $out_line . $1 . "  END IF\n";
    $out_line = $out_line . $1 . "  RETURN\n";
    $out_line = $out_line . $1 . "END IF";
  }
  elsif(/^(\s*)PIO_TF_ASSERT\((.+),([^)]+)\)(.*)$/s){
    $out_line = $1 . $4 . "\n";
    $out_line = $out_line . $1 . "IF (.NOT. ($2)) THEN\n";
    $out_line = $out_line . $1 . "  pio_tf_retval_utest_ = -1\n";
    $out_line = $out_line . $1 . "  PRINT *, \"PIO_TF: Assertion failed :\",&\n";
    $out_line = $out_line . $1 . "    " . $3 . ",&\n";
    $out_line = $out_line . $1 . "     \":\", __FILE__, \":\", __LINE__,&\n";
    $out_line = $out_line . $1 . "    " . "\"($template_fname:$template_line_no)\"\n";
    $out_line = $out_line . $1 . "  RETURN\n";
    $out_line = $out_line . $1 . "END IF";
  }
  elsif(/^(\s*)PIO_TF_CHECK_ERR\(([^,]+),([^,]+),(.+)\)(\s*)$/s){
    $out_line = $1 . $5 . "\n";
    $out_line = $out_line . $1 . "IF (.NOT. (PIO_TF_Passert_(($2) == PIO_NOERR, $3))) THEN\n";
    $out_line = $out_line . $1 . "  call MPI_COMM_RANK($3, pio_tf_tmp_comm_rank_, pio_tf_retval_utest_)\n";
    $out_line = $out_line . $1 . "  pio_tf_retval_utest_ = -1\n";
    $out_line = $out_line . $1 . "  IF (pio_tf_tmp_comm_rank_ == 0) THEN\n";
    $out_line = $out_line . $1 . "    PRINT *, \"PIO_TF: PIO Function failed:\",&\n";
    $out_line = $out_line . $1 . "      " . $4 . ",&\n";
    $out_line = $out_line . $1 . "      \":\", __FILE__, \":\", __LINE__,&\n";
    $out_line = $out_line . $1 . "      " . "\"($template_fname:$template_line_no)\"\n";
    $out_line = $out_line . $1 . "  END IF\n";
    $out_line = $out_line . $1 . "  RETURN\n";
    $out_line = $out_line . $1 . "END IF";
  }
  elsif(/^(\s*)PIO_TF_CHECK_ERR\(([^,]+),(.+)\)(\s*)$/s){
    $out_line = $1 . $4 . "\n";
    $out_line = $out_line . $1 . "IF (.NOT. (PIO_TF_Passert_(($2) == PIO_NOERR, pio_tf_comm_))) THEN\n";
    $out_line = $out_line . $1 . "  pio_tf_retval_utest_ = -1\n";
    $out_line = $out_line . $1 . "  IF (pio_tf_world_rank_ == 0) THEN\n";
    $out_line = $out_line . $1 . "    PRINT *, \"PIO_TF: PIO Function failed:\",&\n";
    $out_line = $out_line . $1 . "      " . $3 . ",&\n";
    $out_line = $out_line . $1 . "      \":\", __FILE__, \":\", __LINE__,&\n";
    $out_line = $out_line . $1 . "      " . "\"($template_fname:$template_line_no)\"\n";
    $out_line = $out_line . $1 . "  END IF\n";
    $out_line = $out_line . $1 . "  RETURN\n";
    $out_line = $out_line . $1 . "END IF";
  }
  elsif(/^(\s*)PIO_TF_CHECK_VAL\(\s*\((.*)\)\s*,(.+)\)(\s*)$/s){
    $out_line = $1 . $4 . "\n";
    $out_line = $out_line . $1 . "IF (.NOT. PIO_TF_Check_val_($2)) THEN\n";
    $out_line = $out_line . $1 . "  pio_tf_retval_utest_ = -1\n";
    $out_line = $out_line . $1 . "  IF (pio_tf_world_rank_ == 0) THEN\n";
    $out_line = $out_line . $1 . "    PRINT *, \"PIO_TF: PIO Check failed:\",&\n";
    $out_line = $out_line . $1 . "      " . $3 . ",&\n";
    $out_line = $out_line . $1 . "      \":\", __FILE__, \":\", __LINE__,&\n";
    $out_line = $out_line . $1 . "      " . "\"($template_fname:$template_line_no)\"\n";
    $out_line = $out_line . $1 . "  END IF\n";
    $out_line = $out_line . $1 . "  RETURN\n";
    $out_line = $out_line . $1 . "END IF";
  }
  elsif(/^(\s*)PIO_TF_ERROR\(([^)]+)\)(.*)$/s){
    $out_line = $1 . $3 . "\n";
    $out_line = $out_line . $1 . "pio_tf_retval_utest_ = -1\n";
    $out_line = $out_line . $1 . "IF (pio_tf_world_rank_ == 0) THEN\n";
    $out_line = $out_line . $1 . "  PRINT *, \"PIO_TF: Fatal Error:\",&\n";
    $out_line = $out_line . $1 . "    " . $2 . ",&\n";
    $out_line = $out_line . $1 . "     \":\", __FILE__, \":\", __LINE__,&\n";
    $out_line = $out_line . $1 . "    " . "\"($template_fname:$template_line_no)\"\n";
    $out_line = $out_line . $1 . "END IF\n";
    $out_line = $out_line . $1 . "RETURN";
  }
  elsif(/^(\s*)PIO_TF_LOG\(([0-9]+),([^)]+)\)(.*)$/s){
    $out_line = "\n";
    $out_line = $out_line . $1 . "IF (pio_tf_world_rank_ == 0) THEN\n";
    $out_line = $out_line . $1 . "  IF (pio_tf_log_level_ >= " . $2 . ") THEN\n";
    $out_line = $out_line . $1 . "    WRITE(*,\"(A)\",ADVANCE=\"NO\") \"PIO_TF: \"\n";
    $out_line = $out_line . $1 . "    WRITE(*," . $3 . ") " . $4 . "\n";
    $out_line = $out_line . $1 . "  END IF\n";
    $out_line = $out_line . $1 . "END IF";
  }
  else{
    $out_line = $_;
    # The line is modified
    $$ref_modif = 0;
  }
  return $out_line;
}

# Find the signature of generic template functions
# Get the template typenames here, if we find a generic templ func
# Returns 1 => if a generic template func is found, 0 otherwise
sub find_gen_templ_funcs
{
  my($str, $ref_templ_typenames) = @_;
  if($str =~ /^\s*PIO_TF_TEMPLATE\s*<(.*)>.*$/s){
    if($1 eq ''){
      print "Error parsing template code, Check syntax of PIO_TF_TEMPLATE...\n";
      return 0;
    }
    my(@types) = split(/,/, $1);
    if(scalar(@types) == 0){
      print "Error parsing template code, Check syntax of PIO_TF_TEMPLATE...\n";
      return 0;
    }
    my($type);
    foreach $type (@types){
      $type =~ s/^\s*//;
      $type =~ s/\s*$//;
      my(@type_typename) = split(/\s+/,$type);
      if(scalar(@type_typename) != 2){
        print "Error parsing template code, Check syntax of PIO_TF_TEMPLATE...\n";
        return 0;
      }
      if($type_typename[0] ne "PIO_TF_PREDEF_TYPENAME"){
        print "Error parsing template code. Only predefined typenames are supported\n";
        return 0;
      }
      if($verbose){print "Found type : $type_typename[1] \n";}
      push(@{$ref_templ_typenames}, $type_typename[1]);
    }
    return 1;
  }
  else{
    return 0;
  }
}

# Parse and store the generic template function body
# The generic template function body is parsed, transformed and stored
sub parse_and_store_gen_templ_funcs
{
  my ($is_in_templ_func) = 1;
  my($line, $ref_templ_funcname, $ref_templ_typenames,
      $ref_gen_templ_func_list, $base_file_name, $ifline_num) = @_;
  my ($out_line);

  $out_line = "";
  $_ = $line;
  if(/^(\s*)(PIO_TF_TEST_SUB_BEGIN)(\s*)(.*)$/s){
    ${$ref_templ_funcname} = $4;
    $out_line = $1 . "SUBROUTINE" . $3 . $4 . "\n";
    $out_line = $out_line . $1 . "USE pio_tutil\n";
  }
  elsif(/^(\s*)(PIO_TF_TEST_SUB_END)(.*)$/s){
    $is_in_templ_func = 0;
    $out_line = $1 . "END SUBROUTINE". $3;
  }
  elsif(/^(\s*)(PIO_TF_AUTO_TEST_SUB_BEGIN)(\s*)(.*)$/s){
    ${$ref_templ_funcname} = $4;
    push(@{$ref_gen_templ_func_list}, ${$ref_templ_funcname});
    # Adding typenames to the function_name->typename map
    $template_func_typenames{${$ref_templ_funcname}} = [];
    my ($typename);
    foreach $typename (@{$ref_templ_typenames}){
      push(@{$template_func_typenames{${$ref_templ_funcname}}}, $typename);
    }
    $out_line = $1 . "SUBROUTINE" . $3 . $4 . "\n";
    $out_line = $out_line . $1 . "USE pio_tutil\n";
  }
  elsif(/^(\s*)(PIO_TF_AUTO_TEST_SUB_END)(.*)$/s){
    $is_in_templ_func = 0;
    $out_line = $1 . "END SUBROUTINE". $3;
  }
  elsif(/^(\s*[!].*)$/){
    $out_line = $1;
  }
  else{
    my(@tmp_auto_funcs_list);
    my($is_transformed);
    $out_line = &transform_src(\@tmp_auto_funcs_list, $_, $base_file_name,
                        $ifline_num, \$is_transformed);
  }
  if($annotate_source){
      if($out_line =~ /[^#]/){
          $out_line .= "\n";
      }else{
          $out_line = $out_line . "   ! $base_file_name:$ifline_num" . "\n";
      }
  }
  if($verbose) { print "Adding \"$out_line\" to ${$ref_templ_funcname}\n"; }
  if(exists $template_funcs{${$ref_templ_funcname}}){
    $template_funcs{${$ref_templ_funcname}} .= $out_line;
  }
  else{
    $template_funcs{${$ref_templ_funcname}} = $out_line;
  }
  return $is_in_templ_func;
}

# Add generic auto template functions to the auto test function list
sub update_auto_func_list_with_gen_templ
{
  my($ref_auto_funcs_list, $ref_gen_templ_funcs_list,
      $base_file_name, $ifline_num) = @_;
  my ($gen_templ_func_name);
  my (@modif_gen_templ_func_names);
  foreach $gen_templ_func_name (@{$ref_gen_templ_funcs_list}){
    # Get the general template function names
    &generate_gen_templates($gen_templ_func_name, \@modif_gen_templ_func_names,
        $base_file_name, $ifline_num);
    my ($func_name);
    foreach $func_name (@modif_gen_templ_func_names){
      push(@{$ref_auto_funcs_list}, $func_name);
    }
  }
}

# Returns the default test main code
sub get_default_test_main
{
  my($out_line);
  $out_line = "\n\n";
  $out_line = $out_line . "  PROGRAM PIO_TF_Test_main_\n";
  $out_line = $out_line . "    USE pio_tutil\n";
  $out_line = $out_line . "    IMPLICIT NONE\n";
  $out_line = $out_line . "    INTEGER, PARAMETER :: NREARRS = 2\n";
  $out_line = $out_line . "    INTEGER :: rearrs(NREARRS) = (/pio_rearr_subset,pio_rearr_box/)\n";
  $out_line = $out_line . "    CHARACTER(LEN=PIO_TF_MAX_STR_LEN) :: rearrs_info(NREARRS) = (/\"PIO_REARR_SUBSET\",\"PIO_REARR_BOX   \"/)\n";
  $out_line = $out_line . "    INTEGER i, ierr\n";
  $out_line = $out_line . "\n";
  $out_line = $out_line . "    pio_tf_nerrs_total_=0\n";
  $out_line = $out_line . "    pio_tf_retval_utest_=0\n";
  $out_line = $out_line . "    CALL MPI_Init(ierr)\n";
  $out_line = $out_line . "    DO i=1,SIZE(rearrs)\n";
  $out_line = $out_line . "      CALL PIO_TF_Init_(rearrs(i))\n";
  $out_line = $out_line . "      IF (pio_tf_world_rank_ == 0) THEN\n";
  $out_line = $out_line . "        WRITE(*,*) \"PIO_TF: Testing : \", trim(rearrs_info(i))\n";
  $out_line = $out_line . "      END IF\n";
  $out_line = $out_line . "      CALL PIO_TF_Test_driver_()\n";
  $out_line = $out_line . "      CALL PIO_TF_Finalize_()\n";
  $out_line = $out_line . "    END DO\n";
  $out_line = $out_line . "    IF (pio_tf_world_rank_ == 0) THEN\n";
  $out_line = $out_line . "      IF (pio_tf_nerrs_total_ == 0) THEN\n";
  $out_line = $out_line . "        IF (pio_tf_retval_utest_ == 0) THEN\n";
  $out_line = $out_line . "          WRITE(*,PIO_TF_TEST_RES_FMT) \"PIO_TF: \",&\n";
  $out_line = $out_line . "           \"All tests\", \"---------\", \"PASSED\"\n";
  $out_line = $out_line . "        ELSE\n";
  $out_line = $out_line . "          pio_tf_nerrs_total_ = pio_tf_nerrs_total_ + 1\n";
  $out_line = $out_line . "          WRITE(*,PIO_TF_TEST_RES_FMT) \"PIO_TF: \",&\n";
  $out_line = $out_line . "           \"Test driver\", \"---------\", \"FAILED\"\n";
  $out_line = $out_line . "        END IF\n";
  $out_line = $out_line . "      ELSE\n";
  $out_line = $out_line . "        WRITE(*,PIO_TF_TEST_RES_FMT2) \"PIO_TF:[\",&\n";
  $out_line = $out_line . "          pio_tf_nerrs_total_,\"] Tests\",&\n";
  $out_line = $out_line . "          \"----- FAILED\"\n";
  $out_line = $out_line . "      END IF\n";
  $out_line = $out_line . "    END IF\n";
  $out_line = $out_line . "    CALL MPI_Finalize(ierr)\n";
  $out_line = $out_line . "    IF (pio_tf_nerrs_total_ /= 0) THEN\n";
  $out_line = $out_line . "      STOP 99\n";
  $out_line = $out_line . "    END IF\n";
  $out_line = $out_line . "  END PROGRAM\n";

  return $out_line;
}

# Returns the default test driver
sub get_default_test_driver
{
  my($ref_auto_funcs_list) = @_;
  my($out_line);

  $out_line = "\n\n";
  $out_line = $out_line . "  SUBROUTINE PIO_TF_Test_driver_\n";
  $out_line = $out_line . "    USE pio_tutil\n";
  $out_line = $out_line . "    USE mpi, only : mpi_abort, mpi_comm_world\n";
  $out_line = $out_line . "    IMPLICIT NONE\n";
  $out_line = $out_line . "    integer :: mpierr\n";
  if($template_auto_funcs_inserted == 1){
    print "Error parsing template file, auto tests can only be inserted (PIO_TF_AUTO_TESTS_RUN) in a test driver\n";
    exit;
  }
  foreach(@{$ref_auto_funcs_list}){
    $out_line = $out_line . "    pio_tf_retval_utest_ = 0\n";
    $out_line = $out_line . "    IF (pio_tf_world_rank_ == 0) THEN\n";
    $out_line = $out_line . "      PRINT *, \"PIO_TF: Starting $_\"\n";
    $out_line = $out_line . "    END IF\n";
    $out_line = $out_line . "    CALL $_()\n";
    $out_line = $out_line . "    IF (pio_tf_retval_utest_ /= 0) THEN\n";
    $out_line = $out_line . "      pio_tf_nerrs_total_ = pio_tf_nerrs_total_ + 1\n";
    $out_line = $out_line . "    END IF\n";
    $out_line = $out_line . "    IF (pio_tf_world_rank_ == 0) THEN\n";
    $out_line = $out_line . "      IF (pio_tf_retval_utest_ == 0) THEN\n";
    $out_line = $out_line . "        WRITE(*,PIO_TF_TEST_RES_FMT) \"PIO_TF:Test $cur_test_case_num:\",&\n";
    $out_line = $out_line . "          \"$_\",\"-----------\", \"PASSED\"\n";
    $out_line = $out_line . "      ELSE\n";
    $out_line = $out_line . "        WRITE(*,PIO_TF_TEST_RES_FMT) \"PIO_TF:Test $cur_test_case_num:\",&\n";
    $out_line = $out_line . "          \"$_\",\"-----------\", \"FAILED\"\n";
# The following line if uncommented will cause the framework to stop at the first failure

#    $out_line = $out_line . "        call mpi_abort(MPI_COMM_WORLD, 0, mpierr)\n";
    $out_line = $out_line . "      END IF\n";
    $out_line = $out_line . "    END IF\n";
    $cur_test_case_num += 1;
  }
  $out_line = $out_line . "  END SUBROUTINE PIO_TF_Test_driver_\n";
  return $out_line;
}

# Header is just a disclaimer for the generated code
sub get_header
{
  my ($template_fname) = @_;
  my ($out_line);
  $out_line = "! DON'T MODIFY THIS FILE, ALL YOUR CHANGES WILL BE LOST\n";
  $out_line = $out_line . "! This file is generated by $0\n";
  $out_line = $out_line . "! from $template_fname\n\n";

  return $out_line;
}

# The footer always contains the default test main code
# The footer can contain the default test driver code is none is specified
# - The default test driver code will contain all the auto test subs
# If a test driver code is specified the list of auto test funcs has already
# been appended the driver
sub get_footer
{
  my($ref_auto_funcs_list) = @_;
  my($out_line);
  if($template_has_test_driver == 0){
    # Add default test driver
    $out_line = &get_default_test_driver($ref_auto_funcs_list);
  }

  $out_line = $out_line . &get_default_test_main();
  return $out_line;
}

# This function processes the template file
# * Reads the template file and writes the transformed output
# * Also does some basic processing of inputs
sub process_template_file
{
  my($ifname, $ofname) = @_;
  # The var below keeps track of input file line number
  my($ifline_num);
  my($ifline);
  my($header,$footer);
  my(@auto_funcs_list);
  my(@gen_templ_funcs_list);
  my($TEMPLATE_FILE);
  my($base_file_name);
  my($in_line) = "";
  my($orig_line) = "";

  $base_file_name = basename($ifname);

  # Read template file
  open(TEMPLATE_FILE, "< $ifname") or die "Cannot open input template file: $ifname";

  # FIXME: Move common parsing code in first and second pass to another function

  ######################################################################
  # FIRST PASS - find generic template functions and the calling instances
  ######################################################################
  if($verbose){ print "First pass\n"; }
  my($is_in_template_func) = 0;
  my($templ_funcname) = "UNDEF";
  my(@templ_typenames) = ();
  $ifline_num = 1;
  while(<TEMPLATE_FILE>){
    chomp;
    if(/^(\s*[^!\s][^!]+)!(.*)$/s){
      # Strip comments
      $_ = $1;
    }
    if($is_in_template_func){
      $is_in_template_func = parse_and_store_gen_templ_funcs($_,
                              \$templ_funcname,
                              \@templ_typenames,
                              \@gen_templ_funcs_list,
                              $base_file_name,
                              $ifline_num);
      if($is_in_template_func == 0){
        if($verbose) { print "TEMPLATE_FUNCTION:\n$template_funcs{$templ_funcname}\n"; }
        $templ_funcname = "UNDEF";
        undef(@templ_typenames);
      }
    }
    else{
      $is_in_template_func = find_gen_templ_funcs($_, \@templ_typenames);
    }
    $ifline_num += 1;
  }
  # Add the appropriate generic template function names to the auto function list
  # "PIO_TF_TEMPLATE<PIO_TF_PREDEF_TYPENAME PIO_TF_DATA_TYPE>
  # PIO_TF_AUTO_TEST_SUB_BEGIN foo"
  #       transformed to
  # "Subroutine foo_PIO_int__" etc.
  &update_auto_func_list_with_gen_templ(\@auto_funcs_list, \@gen_templ_funcs_list,
    $base_file_name, -1);

  # Reset the file ptr
  seek(TEMPLATE_FILE, 0, 0);

  ######################################################################
  # SECOND PASS - process the template file and write the source file
  ######################################################################
  if($verbose){ print "Second pass\n"; }
  open(OUTPUT_FILE, "> $ofname") or die "Cannot open output file: $ofname";

  $header = get_header($ifname);
  print OUTPUT_FILE $header;

  $template_disable_wr = 0;
  $ifline_num = 1;
  $in_line = "";
  # Unmodified (orig) line
  $orig_line = "";
  while(<TEMPLATE_FILE>){
    my ($out_line);

    $orig_line = $orig_line . $_;
    chomp;
    $_ = $in_line . $_;
    if(/^\s*[!#].*$/s){
      # Line starting with comment & preproc directives - print it as it is
      if($verbose){ print "Reading comment/preproc-directive: $_\n"; }
      $out_line = $_;
    }
    else{
      # Strip off comments at the end of the line
      if(/^([^!]*)!(.*)$/s){
        if($verbose){ print "Stripping comment: $2\n"; }
        $_ = $1;
      }
      if(/^\s*PROGRAM.*/si){
        # Report error and exit if the template has a PROGRAM keyword
        print "Error: A PROGRAM keyword in statements is invalid in a template file, use PIO_TF_TEST_DRIVER instead\n";
        exit;
      }
      elsif(/^\s*$/s){
        # Print blank lines as "\n" - keep the template formatting as it is
        $out_line = "\n";
      }
      elsif(/^(.*)&$/s){
        # Fortran allows multi-line stmts with a & at the end
        # Collect all these parts of stmts into a single line before processing
        $in_line = $in_line . $1;
        $ifline_num += 1;
        next;
      }
      else{
        my ($is_transformed) = 0;
        $out_line = &transform_src(\@auto_funcs_list, $_, $base_file_name,
                        $ifline_num, \$is_transformed);
        if($is_transformed == 0){
          # If the line is not transformed, undo all changes done and
          # output the original line[s] read from the file
          chomp($orig_line);
          $out_line = $orig_line;
        }
        if($annotate_source){
          # Annotate source with template file name and line number
          # Add it after the line
          $out_line = $out_line . "   ! $base_file_name:$ifline_num";
        }
      }
    }
    # Note: template_disable_wr is being set in transform_src()
    if($template_disable_wr == 0){
      print OUTPUT_FILE "$out_line\n";
    }
    $in_line = "";
    $orig_line = "";
    $ifline_num += 1;
  }

  $footer = &get_footer(\@auto_funcs_list);
  print OUTPUT_FILE $footer;
}

sub print_usage_and_exit()
{
  print "\n\nUsage: ./pio_tf_f90gen.pl --annotate-source --out=<OUTPUT_FILE_NAME> <INPUT_TEMPLATE_FILE_NAME> \n\n";
  print "eg: ./pio_tf_f90gen.pl --annotate-source --out=pio_init_finalize.F90 pio_init_finalize.F90.in\n";
  exit;
}

# Main program

# Read input args
GetOptions(
  # Annotate generated source with template line numbers etc
  "annotate-source"             =>      \$annotate_source,
  "out=s"                                     =>        \$output_fname,
  "verbose"           =>  \$verbose
);

$nargs = @ARGV;
if($nargs == 0){
  &print_usage_and_exit();
}

if($output_fname eq ""){
  &print_usage_and_exit();
}

$template_fname = shift;
if(!stat($template_fname)){
  print "Error: Cannot find input template file\n";
  &print_usage_and_exit();
}

&init_predef_types();

if($verbose){ print "Reading input args complete\n" }
&process_template_file($template_fname, $output_fname);
