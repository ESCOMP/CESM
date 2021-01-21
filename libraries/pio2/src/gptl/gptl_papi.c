/*
** $Id: gptl_papi.c,v 1.79 2011-03-28 20:55:19 rosinski Exp $
**
** Author: Jim Rosinski
**
** Contains routines which interface to PAPI library
*/
 
#include "private.h"
#include "gptl.h"

#ifdef HAVE_PAPI

#include <papi.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#if ( defined THREADED_OMP )
#include <omp.h>
#elif ( defined THREADED_PTHREADS )
#include <pthread.h>
#endif

/* Mapping of PAPI counters to short and long printed strings */

static const Entry papitable [] = {
  {PAPI_L1_DCM, "PAPI_L1_DCM", "L1_DCM  ", "L1_Dcache_miss  ", "Level 1 data cache misses"},
  {PAPI_L1_ICM, "PAPI_L1_ICM", "L1_ICM  ", "L1_Icache_miss  ", "Level 1 instruction cache misses"},
  {PAPI_L2_DCM, "PAPI_L2_DCM", "L2_DCM  ", "L2_Dcache_miss  ", "Level 2 data cache misses"},
  {PAPI_L2_ICM, "PAPI_L2_ICM", "L2_ICM  ", "L2_Icache_miss  ", "Level 2 instruction cache misses"},
  {PAPI_L3_DCM, "PAPI_L3_DCM", "L3_DCM  ", "L3_Dcache_miss  ", "Level 3 data cache misses"},
  {PAPI_L3_ICM, "PAPI_L3_ICM", "L3_ICM  ", "L3_Icache_miss  ", "Level 3 instruction cache misses"},
  {PAPI_L1_TCM, "PAPI_L1_TCM", "L1_TCM  ", "L1_cache_miss   ", "Level 1 total cache misses"},
  {PAPI_L2_TCM, "PAPI_L2_TCM", "L2_TCM  ", "L2_cache_miss   ", "Level 2 total cache misses"},
  {PAPI_L3_TCM, "PAPI_L3_TCM", "L3_TCM  ", "L3_cache_miss   ", "Level 3 total cache misses"},
  {PAPI_CA_SNP, "PAPI_CA_SNP", "CA_SNP  ", "Snoops          ", "Snoops          "},
  {PAPI_CA_SHR, "PAPI_CA_SHR", "CA_SHR  ", "PAPI_CA_SHR     ", "Request for shared cache line (SMP)"},
  {PAPI_CA_CLN, "PAPI_CA_CLN", "CA_CLN  ", "PAPI_CA_CLN     ", "Request for clean cache line (SMP)"},
  {PAPI_CA_INV, "PAPI_CA_INV", "CA_INV  ", "PAPI_CA_INV     ", "Request for cache line Invalidation (SMP)"},
  {PAPI_CA_ITV, "PAPI_CA_ITV", "CA_ITV  ", "PAPI_CA_ITV     ", "Request for cache line Intervention (SMP)"},
  {PAPI_L3_LDM, "PAPI_L3_LDM", "L3_LDM  ", "L3_load_misses  ", "Level 3 load misses"},
  {PAPI_L3_STM, "PAPI_L3_STM", "L3_STM  ", "L3_store_misses ", "Level 3 store misses"},
  {PAPI_BRU_IDL,"PAPI_BRU_IDL","BRU_IDL ", "PAPI_BRU_IDL    ", "Cycles branch units are idle"},
  {PAPI_FXU_IDL,"PAPI_FXU_IDL","FXU_IDL ", "PAPI_FXU_IDL    ", "Cycles integer units are idle"},
  {PAPI_FPU_IDL,"PAPI_FPU_IDL","FPU_IDL ", "PAPI_FPU_IDL    ", "Cycles floating point units are idle"},
  {PAPI_LSU_IDL,"PAPI_LSU_IDL","LSU_IDL ", "PAPI_LSU_IDL    ", "Cycles load/store units are idle"},
  {PAPI_TLB_DM, "PAPI_TLB_DM"  "TLB_DM  ", "Data_TLB_misses ", "Data translation lookaside buffer misses"},
  {PAPI_TLB_IM, "PAPI_TLB_IM", "TLB_IM  ", "Inst_TLB_misses ", "Instr translation lookaside buffer misses"},
  {PAPI_TLB_TL, "PAPI_TLB_TL", "TLB_TL  ", "Tot_TLB_misses  ", "Total translation lookaside buffer misses"},
  {PAPI_L1_LDM, "PAPI_L1_LDM", "L1_LDM  ", "L1_load_misses  ", "Level 1 load misses"},
  {PAPI_L1_STM, "PAPI_L1_STM", "L1_STM  ", "L1_store_misses ", "Level 1 store misses"},
  {PAPI_L2_LDM, "PAPI_L2_LDM", "L2_LDM  ", "L2_load_misses  ", "Level 2 load misses"},
  {PAPI_L2_STM, "PAPI_L2_STM", "L2_STM  ", "L2_store_misses ", "Level 2 store misses"},
  {PAPI_BTAC_M, "PAPI_BTAC_M", "BTAC_M  ", "BTAC_miss       ", "BTAC miss"},
  {PAPI_PRF_DM, "PAPI_PRF_DM", "PRF_DM  ", "PAPI_PRF_DM     ", "Prefetch data instruction caused a miss"},
  {PAPI_L3_DCH, "PAPI_L3_DCH", "L3_DCH  ", "L3_DCache_Hit   ", "Level 3 Data Cache Hit"},
  {PAPI_TLB_SD, "PAPI_TLB_SD", "TLB_SD  ", "PAPI_TLB_SD     ", "Xlation lookaside buffer shootdowns (SMP)"},
  {PAPI_CSR_FAL,"PAPI_CSR_FAL","CSR_FAL ", "PAPI_CSR_FAL    ", "Failed store conditional instructions"},
  {PAPI_CSR_SUC,"PAPI_CSR_SUC","CSR_SUC ", "PAPI_CSR_SUC    ", "Successful store conditional instructions"},
  {PAPI_CSR_TOT,"PAPI_CSR_TOT","CSR_TOT ", "PAPI_CSR_TOT    ", "Total store conditional instructions"},
  {PAPI_MEM_SCY,"PAPI_MEM_SCY","MEM_SCY ", "Cyc_Stalled_Mem ", "Cycles Stalled Waiting for Memory Access"},
  {PAPI_MEM_RCY,"PAPI_MEM_RCY","MEM_RCY ", "Cyc_Stalled_MemR", "Cycles Stalled Waiting for Memory Read"},
  {PAPI_MEM_WCY,"PAPI_MEM_WCY","MEM_WCY ", "Cyc_Stalled_MemW", "Cycles Stalled Waiting for Memory Write"},
  {PAPI_STL_ICY,"PAPI_STL_ICY","STL_ICY ", "Cyc_no_InstrIss ", "Cycles with No Instruction Issue"},
  {PAPI_FUL_ICY,"PAPI_FUL_ICY","FUL_ICY ", "Cyc_Max_InstrIss", "Cycles with Maximum Instruction Issue"},
  {PAPI_STL_CCY,"PAPI_STL_CCY","STL_CCY ", "Cyc_No_InstrComp", "Cycles with No Instruction Completion"},
  {PAPI_FUL_CCY,"PAPI_FUL_CCY","FUL_CCY ", "Cyc_Max_InstComp", "Cycles with Maximum Instruction Completion"},
  {PAPI_HW_INT, "PAPI_HW_INT", "HW_INT  ", "HW_interrupts   ", "Hardware interrupts"},
  {PAPI_BR_UCN, "PAPI_BR_UCN", "BR_UCN  ", "Uncond_br_instr ", "Unconditional branch instructions executed"},
  {PAPI_BR_CN,  "PAPI_BR_CN",  "BR_CN   ", "Cond_br_instr_ex", "Conditional branch instructions executed"},
  {PAPI_BR_TKN, "PAPI_BR_TKN", "BR_TKN  ", "Cond_br_instr_tk", "Conditional branch instructions taken"},
  {PAPI_BR_NTK, "PAPI_BR_NTK", "BR_NTK  ", "Cond_br_instrNtk", "Conditional branch instructions not taken"},
  {PAPI_BR_MSP, "PAPI_BR_MSP", "BR_MSP  ", "Cond_br_instrMPR", "Conditional branch instructions mispred"},
  {PAPI_BR_PRC, "PAPI_BR_PRC", "BR_PRC  ", "Cond_br_instrCPR", "Conditional branch instructions corr. pred"},
  {PAPI_FMA_INS,"PAPI_FMA_INS","FMA_INS ", "FMA_instr_comp  ", "FMA instructions completed"},
  {PAPI_TOT_IIS,"PAPI_TOT_IIS","TOT_IIS ", "Total_instr_iss ", "Total instructions issued"},
  {PAPI_TOT_INS,"PAPI_TOT_INS","TOT_INS ", "Total_instr_ex  ", "Total instructions executed"},
  {PAPI_INT_INS,"PAPI_INT_INS","INT_INS ", "Int_instr_ex    ", "Integer instructions executed"},
  {PAPI_FP_INS, "PAPI_FP_INS", "FP_INS  ", "FP_instr_ex     ", "Floating point instructions executed"},
  {PAPI_LD_INS, "PAPI_LD_INS", "LD_INS  ", "Load_instr_ex   ", "Load instructions executed"},
  {PAPI_SR_INS, "PAPI_SR_INS", "SR_INS  ", "Store_instr_ex  ", "Store instructions executed"},
  {PAPI_BR_INS, "PAPI_BR_INS", "BR_INS  ", "br_instr_ex     ", "Total branch instructions executed"},
  {PAPI_VEC_INS,"PAPI_VEC_INS","VEC_INS ", "Vec/SIMD_instrEx", "Vector/SIMD instructions executed"},
  {PAPI_RES_STL,"PAPI_RES_STL","RES_STL ", "Cyc_proc_stalled", "Cycles processor is stalled on resource"},
  {PAPI_FP_STAL,"PAPI_FP_STAL","FP_STAL ", "Cyc_any_FP_stall", "Cycles any FP units are stalled"},
  {PAPI_TOT_CYC,"PAPI_TOT_CYC","TOT_CYC ", "Total_cycles    ", "Total cycles"},
  {PAPI_LST_INS,"PAPI_LST_INS","LST_INS ", "Tot_L/S_inst_ex ", "Total load/store inst. executed"},
  {PAPI_SYC_INS,"PAPI_SYC_INS","SYC_INS ", "Sync._inst._ex  ", "Sync. inst. executed"},
  {PAPI_L1_DCH, "PAPI_L1_DCH", "L1_DCH  ", "L1_D_Cache_Hit  ", "L1 D Cache Hit"},
  {PAPI_L2_DCH, "PAPI_L2_DCH", "L2_DCH  ", "L2_D_Cache_Hit  ", "L2 D Cache Hit"},
  {PAPI_L1_DCA, "PAPI_L1_DCA", "L1_DCA  ", "L1_D_Cache_Acc  ", "L1 D Cache Access"},
  {PAPI_L2_DCA, "PAPI_L2_DCA", "L2_DCA  ", "L2_D_Cache_Acc  ", "L2 D Cache Access"},
  {PAPI_L3_DCA, "PAPI_L3_DCA", "L3_DCA  ", "L3_D_Cache_Acc  ", "L3 D Cache Access"},
  {PAPI_L1_DCR, "PAPI_L1_DCR", "L1_DCR  ", "L1_D_Cache_Read ", "L1 D Cache Read"},
  {PAPI_L2_DCR, "PAPI_L2_DCR", "L2_DCR  ", "L2_D_Cache_Read ", "L2 D Cache Read"},
  {PAPI_L3_DCR, "PAPI_L3_DCR", "L3_DCR  ", "L3_D_Cache_Read ", "L3 D Cache Read"},
  {PAPI_L1_DCW, "PAPI_L1_DCW", "L1_DCW  ", "L1_D_Cache_Write", "L1 D Cache Write"},
  {PAPI_L2_DCW, "PAPI_L2_DCW", "L2_DCW  ", "L2_D_Cache_Write", "L2 D Cache Write"},
  {PAPI_L3_DCW, "PAPI_L3_DCW", "L3_DCW  ", "L3_D_Cache_Write", "L3 D Cache Write"},
  {PAPI_L1_ICH, "PAPI_L1_ICH", "L1_ICH  ", "L1_I_cache_hits ", "L1 instruction cache hits"},
  {PAPI_L2_ICH, "PAPI_L2_ICH", "L2_ICH  ", "L2_I_cache_hits ", "L2 instruction cache hits"},
  {PAPI_L3_ICH, "PAPI_L3_ICH", "L3_ICH  ", "L3_I_cache_hits ", "L3 instruction cache hits"},
  {PAPI_L1_ICA, "PAPI_L1_ICA", "L1_ICA  ", "L1_I_cache_acc  ", "L1 instruction cache accesses"},
  {PAPI_L2_ICA, "PAPI_L2_ICA", "L2_ICA  ", "L2_I_cache_acc  ", "L2 instruction cache accesses"},
  {PAPI_L3_ICA, "PAPI_L3_ICA", "L3_ICA  ", "L3_I_cache_acc  ", "L3 instruction cache accesses"},
  {PAPI_L1_ICR, "PAPI_L1_ICR", "L1_ICR  ", "L1_I_cache_reads", "L1 instruction cache reads"},
  {PAPI_L2_ICR, "PAPI_L2_ICR", "L2_ICR  ", "L2_I_cache_reads", "L2 instruction cache reads"},
  {PAPI_L3_ICR, "PAPI_L3_ICR", "L3_ICR  ", "L3_I_cache_reads", "L3 instruction cache reads"},
  {PAPI_L1_ICW, "PAPI_L1_ICW", "L1_ICW  ", "L1_I_cache_write", "L1 instruction cache writes"},
  {PAPI_L2_ICW, "PAPI_L2_ICW", "L2_ICW  ", "L2_I_cache_write", "L2 instruction cache writes"},
  {PAPI_L3_ICW, "PAPI_L3_ICW", "L3_ICW  ", "L3_I_cache_write", "L3 instruction cache writes"},
  {PAPI_L1_TCH, "PAPI_L1_TCH", "L1_TCH  ", "L1_cache_hits   ", "L1 total cache hits"},
  {PAPI_L2_TCH, "PAPI_L2_TCH", "L2_TCH  ", "L2_cache_hits   ", "L2 total cache hits"},
  {PAPI_L3_TCH, "PAPI_L3_TCH", "L3_TCH  ", "L3_cache_hits   ", "L3 total cache hits"},
  {PAPI_L1_TCA, "PAPI_L1_TCA", "L1_TCA  ", "L1_cache_access ", "L1 total cache accesses"},
  {PAPI_L2_TCA, "PAPI_L2_TCA", "L2_TCA  ", "L2_cache_access ", "L2 total cache accesses"},
  {PAPI_L3_TCA, "PAPI_L3_TCA", "L3_TCA  ", "L3_cache_access ", "L3 total cache accesses"},
  {PAPI_L1_TCR, "PAPI_L1_TCR", "L1_TCR  ", "L1_cache_reads  ", "L1 total cache reads"},
  {PAPI_L2_TCR, "PAPI_L2_TCR", "L2_TCR  ", "L2_cache_reads  ", "L2 total cache reads"},
  {PAPI_L3_TCR, "PAPI_L3_TCR", "L3_TCR  ", "L3_cache_reads  ", "L3 total cache reads"},
  {PAPI_L1_TCW, "PAPI_L1_TCW", "L1_TCW  ", "L1_cache_writes ", "L1 total cache writes"},
  {PAPI_L2_TCW, "PAPI_L2_TCW", "L2_TCW  ", "L2_cache_writes ", "L2 total cache writes"},
  {PAPI_L3_TCW, "PAPI_L3_TCW", "L3_TCW  ", "L3_cache_writes ", "L3 total cache writes"},
  {PAPI_FML_INS,"PAPI_FML_INS","FML_INS ", "FM_ins          ", "FM ins"},
  {PAPI_FAD_INS,"PAPI_FAD_INS","FAD_INS ", "FA_ins          ", "FA ins"},
  {PAPI_FDV_INS,"PAPI_FDV_INS","FDV_INS ", "FD_ins          ", "FD ins"},
  {PAPI_FSQ_INS,"PAPI_FSQ_INS","FSQ_INS ", "FSq_ins         ", "FSq ins"},
  {PAPI_FNV_INS,"PAPI_FNV_INS","FNV_INS ", "Finv_ins        ", "Finv ins"},
  {PAPI_FP_OPS, "PAPI_FP_OPS", "FP_OPS  ", "FP_ops_executed ", "Floating point operations executed"}
};

static const int npapientries = sizeof (papitable) / sizeof (Entry);
static int papieventlist[MAX_AUX];        /* list of PAPI events to be counted */
static Pr_event pr_event[MAX_AUX];        /* list of events (PAPI or derived) */

/* Derived events */
static const Entry derivedtable [] = {
  {GPTL_IPC,    "GPTL_IPC",     "IPC     ", "Instr_per_cycle ", "Instructions per cycle"},
  {GPTL_CI,     "GPTL_CI",      "CI      ", "Comp_Intensity  ", "Computational intensity"},
  {GPTL_FPC,    "GPTL_FPC",     "Flop/Cyc", "FP_Ops_per_cycle", "Floating point ops per cycle"},
  {GPTL_FPI,    "GPTL_FPI",     "Flop/Ins", "FP_Ops_per_instr", "Floating point ops per instruction"},
  {GPTL_LSTPI,  "GPTL_LSTPI",   "LST_frac", "LST_fraction    ", "Load-store instruction fraction"},
  {GPTL_DCMRT,  "GPTL_DCMRT",   "DCMISRAT", "L1_Miss_Rate    ", "L1 miss rate (fraction)"},
  {GPTL_LSTPDCM,"GPTL_LSTPDCM", "LSTPDCM ", "LST_per_L1_miss ", "Load-store instructions per L1 miss"},
  {GPTL_L2MRT,  "GPTL_L2MRT",   "L2MISRAT", "L2_Miss_Rate    ", "L2 miss rate (fraction)"},
  {GPTL_LSTPL2M,"GPTL_LSTPL2M", "LSTPL2M ", "LST_per_L2_miss ", "Load-store instructions per L2 miss"},
  {GPTL_L3MRT,  "GPTL_L3MRT",   "L3MISRAT", "L3_Miss_Rate    ", "L3 read miss rate (fraction)"}
};
static const int nderivedentries = sizeof (derivedtable) / sizeof (Entry);

static int npapievents = 0;              /* number of PAPI events: initialize to 0 */ 
static int nevents = 0;                  /* number of events: initialize to 0 */ 
static int *EventSet;                    /* list of events to be counted by PAPI */
static long_long **papicounters;         /* counters returned from PAPI */

static const int BADCOUNT = -999999;     /* Set counters to this when they are bad */
static bool is_multiplexed = false;      /* whether multiplexed (always start false)*/
static bool narrowprint = true;          /* only use 8 digits not 16 for counter prints */
static bool persec = true;               /* print PAPI stats per second */
static bool enable_multiplexing = false; /* whether to try multiplexing */
static bool verbose = false;             /* output verbosity */

/* Function prototypes */

static int canenable (int);
static int canenable2 (int, int);
static int papievent_is_enabled (int);
static int already_enabled (int);
static int enable (int);
static int getderivedidx (int);

/*
** GPTL_PAPIsetoption: enable or disable PAPI event defined by "counter". Called 
**   from GPTLsetoption.  Since all events are off by default, val=false degenerates
**   to a no-op.  Coded this way to be consistent with the rest of GPTL
**
** Input args: 
**   counter: PAPI counter
**   val:     true or false for enable or disable
**
** Return value: 0 (success) or GPTLerror (failure)
*/

int GPTL_PAPIsetoption (const int counter,  /* PAPI counter (or option) */
			const int val)      /* true or false for enable or disable */
{
  int n;       /* loop index */
  int ret;     /* return code */
  int numidx;  /* numerator index */
  int idx;     /* derived counter index */
  char eventname[PAPI_MAX_STR_LEN]; /* returned from PAPI_event_code_to_name */

  /*
  ** First, check for option which is not an actual counter
  */

  switch (counter) {
  case GPTLverbose:
  /* don't printf here--that'd duplicate what's in gptl.c */
    verbose = (bool) val;
    return 0;
  case GPTLmultiplex:
    enable_multiplexing = (bool) val;
    if (verbose)
      printf ("GPTL_PAPIsetoption: boolean enable_multiplexing = %d\n", val);
    return 0;
  case GPTLnarrowprint:
    narrowprint = (bool) val;
    if (verbose)
      printf ("GPTL_PAPIsetoption: boolean narrowprint = %d\n", val);
    return 0;
  case GPTLpersec:
    persec = (bool) val;
    if (verbose)
      printf ("GPTL_PAPIsetoption: boolean persec = %d\n", val);
    return 0;
  default:
    break;
  }

  /* 
  ** If val is false, return an error if the event has already been enabled.
  ** Otherwise just warn that attempting to disable a PAPI-based event
  ** that has already been enabled doesn't work--for now it's just a no-op
  */

  if (! val) {
    if (already_enabled (counter))
      return GPTLerror ("GPTL_PAPIsetoption: already enabled counter %d cannot be disabled\n",
			counter);
    else
      if (verbose)
	printf ("GPTL_PAPIsetoption: 'disable' %d currently is just a no-op\n", counter);
    return 0;
  }

  /* If the event has already been enabled for printing, exit */

  if (already_enabled (counter))
    return GPTLerror ("GPTL_PAPIsetoption: counter %d has already been enabled\n", 
		      counter);

  /* 
  ** Initialize PAPI if it hasn't already been done.
  ** From here on down we can assume the intent is to enable (not disable) an option
  */

  if (GPTL_PAPIlibraryinit () < 0)
    return GPTLerror ("GPTL_PAPIsetoption: PAPI library init error\n");

  /* Ensure max nevents won't be exceeded */

  if (nevents+1 > MAX_AUX)
    return GPTLerror ("GPTL_PAPIsetoption: %d is too many events. Can be increased in private.h\n",
		      nevents+1);

  /* Check derived events */

  switch (counter) {
  case GPTL_IPC:
    if ( ! canenable2 (PAPI_TOT_INS, PAPI_TOT_CYC))
      return GPTLerror ("GPTL_PAPIsetoption: GPTL_IPC unavailable\n");

    idx = getderivedidx (GPTL_IPC);
    pr_event[nevents].event    = derivedtable[idx];
    pr_event[nevents].numidx   = enable (PAPI_TOT_INS);
    pr_event[nevents].denomidx = enable (PAPI_TOT_CYC);
    if (verbose)
      printf ("GPTL_PAPIsetoption: enabling derived event %s = PAPI_TOT_INS / PAPI_TOT_CYC\n", 
	      pr_event[nevents].event.namestr);
    ++nevents;
    return 0;
  case GPTL_CI:
    idx = getderivedidx (GPTL_CI);
    if (canenable2 (PAPI_FP_OPS, PAPI_LST_INS)) {
      pr_event[nevents].event    = derivedtable[idx];
      pr_event[nevents].numidx   = enable (PAPI_FP_OPS);
      pr_event[nevents].denomidx = enable (PAPI_LST_INS);
      if (verbose)
	printf ("GPTL_PAPIsetoption: enabling derived event %s = PAPI_FP_OPS / PAPI_LST_INS\n", 
		pr_event[nevents].event.namestr);
    } else if (canenable2 (PAPI_FP_OPS, PAPI_L1_DCA)) {
      pr_event[nevents].event    = derivedtable[idx];
      pr_event[nevents].numidx   = enable (PAPI_FP_OPS);
      pr_event[nevents].denomidx = enable (PAPI_L1_DCA);
#ifdef DEBUG
      printf ("GPTL_PAPIsetoption: pr_event %d is derived and will be PAPI event %d / %d\n", 
	      nevents, pr_event[nevents].numidx, pr_event[nevents].denomidx);
#endif
      if (verbose)
	printf ("GPTL_PAPIsetoption: enabling derived event %s = PAPI_FP_OPS / PAPI_L1_DCA\n", 
		pr_event[nevents].event.namestr);
    } else {
      return GPTLerror ("GPTL_PAPIsetoption: GPTL_CI unavailable\n");
    }
    ++nevents;
    return 0;
  case GPTL_FPC:
    if ( ! canenable2 (PAPI_FP_OPS, PAPI_TOT_CYC))
      return GPTLerror ("GPTL_PAPIsetoption: GPTL_FPC unavailable\n");

    idx = getderivedidx (GPTL_FPC);
    pr_event[nevents].event    = derivedtable[idx];
    pr_event[nevents].numidx   = enable (PAPI_FP_OPS);
    pr_event[nevents].denomidx = enable (PAPI_TOT_CYC);
    if (verbose)
      printf ("GPTL_PAPIsetoption: enabling derived event %s = PAPI_FP_OPS / PAPI_TOT_CYC\n", 
	      pr_event[nevents].event.namestr);
    ++nevents;
    return 0;
  case GPTL_FPI:
    if ( ! canenable2 (PAPI_FP_OPS, PAPI_TOT_INS))
      return GPTLerror ("GPTL_PAPIsetoption: GPTL_FPI unavailable\n");

    idx = getderivedidx (GPTL_FPI);
    pr_event[nevents].event    = derivedtable[idx];
    pr_event[nevents].numidx   = enable (PAPI_FP_OPS);
    pr_event[nevents].denomidx = enable (PAPI_TOT_INS);
    if (verbose)
      printf ("GPTL_PAPIsetoption: enabling derived event %s = PAPI_FP_OPS / PAPI_TOT_INS\n", 
	      pr_event[nevents].event.namestr);
    ++nevents;
    return 0;
  case GPTL_LSTPI:
    idx = getderivedidx (GPTL_LSTPI);
    if (canenable2 (PAPI_LST_INS, PAPI_TOT_INS)) {
      pr_event[nevents].event    = derivedtable[idx];
      pr_event[nevents].numidx   = enable (PAPI_LST_INS);
      pr_event[nevents].denomidx = enable (PAPI_TOT_INS);
      if (verbose)
	printf ("GPTL_PAPIsetoption: enabling derived event %s = PAPI_LST_INS / PAPI_TOT_INS\n", 
		pr_event[nevents].event.namestr);
    } else if (canenable2 (PAPI_L1_DCA, PAPI_TOT_INS)) {
      pr_event[nevents].event    = derivedtable[idx];
      pr_event[nevents].numidx   = enable (PAPI_L1_DCA);
      pr_event[nevents].denomidx = enable (PAPI_TOT_INS);
      if (verbose)
	printf ("GPTL_PAPIsetoption: enabling derived event %s = PAPI_L1_DCA / PAPI_TOT_INS\n", 
		pr_event[nevents].event.namestr);
    } else {
      return GPTLerror ("GPTL_PAPIsetoption: GPTL_LSTPI unavailable\n");
    }
    ++nevents;
    return 0;
  case GPTL_DCMRT:
    if ( ! canenable2 (PAPI_L1_DCM, PAPI_L1_DCA))
      return GPTLerror ("GPTL_PAPIsetoption: GPTL_DCMRT unavailable\n");

    idx = getderivedidx (GPTL_DCMRT);
    pr_event[nevents].event    = derivedtable[idx];
    pr_event[nevents].numidx   = enable (PAPI_L1_DCM);
    pr_event[nevents].denomidx = enable (PAPI_L1_DCA);
    if (verbose)
      printf ("GPTL_PAPIsetoption: enabling derived event %s = PAPI_L1_DCM / PAPI_L1_DCA\n", 
	      pr_event[nevents].event.namestr);
    ++nevents;
    return 0;
  case GPTL_LSTPDCM:
    idx = getderivedidx (GPTL_LSTPDCM);
    if (canenable2 (PAPI_LST_INS, PAPI_L1_DCM)) {
      pr_event[nevents].event    = derivedtable[idx];
      pr_event[nevents].numidx   = enable (PAPI_LST_INS);
      pr_event[nevents].denomidx = enable (PAPI_L1_DCM);
      if (verbose)
	printf ("GPTL_PAPIsetoption: enabling derived event %s = PAPI_LST_INS / PAPI_L1_DCM\n", 
		pr_event[nevents].event.namestr);
    } else if (canenable2 (PAPI_L1_DCA, PAPI_L1_DCM)) {
      pr_event[nevents].event    = derivedtable[idx];
      pr_event[nevents].numidx   = enable (PAPI_L1_DCA);
      pr_event[nevents].denomidx = enable (PAPI_L1_DCM);
      if (verbose)
	printf ("GPTL_PAPIsetoption: enabling derived event %s = PAPI_L1_DCA / PAPI_L1_DCM\n", 
		pr_event[nevents].event.namestr);
    } else {
      return GPTLerror ("GPTL_PAPIsetoption: GPTL_LSTPDCM unavailable\n");
    }
    ++nevents;
    return 0;
    /*
    ** For L2 counts, use TC* instead of DC* to avoid PAPI derived events
    */
  case GPTL_L2MRT:
    if ( ! canenable2 (PAPI_L2_TCM, PAPI_L2_TCA))
      return GPTLerror ("GPTL_PAPIsetoption: GPTL_L2MRT unavailable\n");

    idx = getderivedidx (GPTL_L2MRT);
    pr_event[nevents].event    = derivedtable[idx];
    pr_event[nevents].numidx   = enable (PAPI_L2_TCM);
    pr_event[nevents].denomidx = enable (PAPI_L2_TCA);
    if (verbose)
      printf ("GPTL_PAPIsetoption: enabling derived event %s = PAPI_L2_TCM / PAPI_L2_TCA\n", 
	      pr_event[nevents].event.namestr);
    ++nevents;
    return 0;
  case GPTL_LSTPL2M:
    idx = getderivedidx (GPTL_LSTPL2M);
    if (canenable2 (PAPI_LST_INS, PAPI_L2_TCM)) {
      pr_event[nevents].event    = derivedtable[idx];
      pr_event[nevents].numidx   = enable (PAPI_LST_INS);
      pr_event[nevents].denomidx = enable (PAPI_L2_TCM);
      if (verbose)
	printf ("GPTL_PAPIsetoption: enabling derived event %s = PAPI_LST_INS / PAPI_L2_TCM\n", 
		pr_event[nevents].event.namestr);
    } else if (canenable2 (PAPI_L1_DCA, PAPI_L2_TCM)) {
      pr_event[nevents].event    = derivedtable[idx];
      pr_event[nevents].numidx   = enable (PAPI_L1_DCA);
      pr_event[nevents].denomidx = enable (PAPI_L2_TCM);
      if (verbose)
	printf ("GPTL_PAPIsetoption: enabling derived event %s = PAPI_L1_DCA / PAPI_L2_TCM\n", 
		pr_event[nevents].event.namestr);
    } else {
      return GPTLerror ("GPTL_PAPIsetoption: GPTL_LSTPL2M unavailable\n");
    }
    ++nevents;
    return 0;
  case GPTL_L3MRT:
    if ( ! canenable2 (PAPI_L3_TCM, PAPI_L3_TCR))
      return GPTLerror ("GPTL_PAPIsetoption: GPTL_L3MRT unavailable\n");

    idx = getderivedidx (GPTL_L3MRT);
    pr_event[nevents].event    = derivedtable[idx];
    pr_event[nevents].numidx   = enable (PAPI_L3_TCM);
    pr_event[nevents].denomidx = enable (PAPI_L3_TCR);
    if (verbose)
      printf ("GPTL_PAPIsetoption: enabling derived event %s = PAPI_L3_TCM / PAPI_L3_TCR\n", 
	      pr_event[nevents].event.namestr);
    ++nevents;
    return 0;
  default:
    break;
  }

  /* Check PAPI presets */

  for (n = 0; n < npapientries; n++) {
    if (counter == papitable[n].counter) {
      if ((numidx = papievent_is_enabled (counter)) >= 0) {
	pr_event[nevents].event  = papitable[n];
	pr_event[nevents].numidx = numidx;
	pr_event[nevents].denomidx = -1;     /* flag says not derived (no denominator) */
      } else if (canenable (counter)) {
	pr_event[nevents].event  = papitable[n];
	pr_event[nevents].numidx = enable (counter);
	pr_event[nevents].denomidx = -1;     /* flag says not derived (no denominator) */
      } else {
	return GPTLerror ("GPTL_PAPIsetoption: Can't enable event \n", 
			  papitable[n].longstr);
      }
      if (verbose)
	printf ("GPTL_PAPIsetoption: enabling PAPI preset event %s\n", 
		pr_event[nevents].event.namestr);
      ++nevents;
      return 0;
    }
  }

  /*
  ** Check native events last: If PAPI_event_code_to_name fails, give up
  */
  
  if ((ret = PAPI_event_code_to_name (counter, eventname)) != PAPI_OK)
    return GPTLerror ("GPTL_PAPIsetoption: name not found for counter %d: PAPI_strerror: %s\n", 
		      counter, PAPI_strerror (ret));

  /*
  ** A table with predefined names of various lengths does not exist for
  ** native events. Just truncate eventname.
  */

  if ((numidx = papievent_is_enabled (counter)) >= 0) {
    pr_event[nevents].event.counter = counter;

    pr_event[nevents].event.namestr = (char *) GPTLallocate (12+1);
    strncpy (pr_event[nevents].event.namestr, eventname, 12);
    pr_event[nevents].event.namestr[12] = '\0';

    pr_event[nevents].event.str16 = (char *) GPTLallocate (16+1);
    strncpy (pr_event[nevents].event.str16, eventname, 16);
    pr_event[nevents].event.str16[16] = '\0';

    pr_event[nevents].event.longstr = (char *) GPTLallocate (PAPI_MAX_STR_LEN);
    strncpy (pr_event[nevents].event.longstr, eventname, PAPI_MAX_STR_LEN);

    pr_event[nevents].numidx = numidx;
    pr_event[nevents].denomidx = -1;     /* flag says not derived (no denominator) */
  } else if (canenable (counter)) {
    pr_event[nevents].event.counter = counter;

    pr_event[nevents].event.namestr = (char *) GPTLallocate (12+1);
    strncpy (pr_event[nevents].event.namestr, eventname, 12);
    pr_event[nevents].event.namestr[12] = '\0';

    pr_event[nevents].event.str16 = (char *) GPTLallocate (16+1);
    strncpy (pr_event[nevents].event.str16, eventname, 16);
    pr_event[nevents].event.str16[16] = '\0';

    pr_event[nevents].event.longstr = (char *) GPTLallocate (PAPI_MAX_STR_LEN);
    strncpy (pr_event[nevents].event.longstr, eventname, PAPI_MAX_STR_LEN);

    pr_event[nevents].numidx = enable (counter);
    pr_event[nevents].denomidx = -1;     /* flag says not derived (no denominator) */
  } else {
    return GPTLerror ("GPTL_PAPIsetoption: Can't enable event %s\n", eventname);
  }

  if (verbose)
    printf ("GPTL_PAPIsetoption: enabling native event %s\n", pr_event[nevents].event.longstr);

  ++nevents;
  return 0;
}

/*
** canenable: determine whether a PAPI counter can be enabled
**
** Input args: 
**   counter: PAPI counter
**
** Return value: 0 (success) or non-zero (failure)
*/
 
int canenable (int counter)
{
  char eventname[PAPI_MAX_STR_LEN]; /* returned from PAPI_event_code_to_name */

  if (npapievents+1 > MAX_AUX)
    return false;

  if (PAPI_query_event (counter) != PAPI_OK) {
    (void) PAPI_event_code_to_name (counter, eventname);
    fprintf (stderr, "canenable: event %s not available on this arch\n", eventname);
    return false;
  }

  return true;
}

/*
** canenable2: determine whether 2 PAPI counters can be enabled
**
** Input args: 
**   counter1: PAPI counter
**   counter2: PAPI counter
**
** Return value: 0 (success) or non-zero (failure)
*/
 
int canenable2 (int counter1, int counter2)
{
  char eventname[PAPI_MAX_STR_LEN]; /* returned from PAPI_event_code_to_name */

  if (npapievents+2 > MAX_AUX)
    return false;

  if (PAPI_query_event (counter1) != PAPI_OK) {
    (void) PAPI_event_code_to_name (counter1, eventname);
    return false;
  }

  if (PAPI_query_event (counter2) != PAPI_OK) {
    (void) PAPI_event_code_to_name (counter2, eventname);
    return false;
  }

  return true;
}

/*
** papievent_is_enabled: determine whether a PAPI counter has already been
**   enabled. Used internally to keep track of PAPI counters enabled. A given
**   PAPI counter may occur in the computation of multiple derived events, as
**   well as output directly. E.g. PAPI_FP_OPS is used to compute
**   computational intensity, and floating point ops per instruction.
**
** Input args: 
**   counter: PAPI counter
**
** Return value: index into papieventlist (success) or negative (not found)
*/
 
int papievent_is_enabled (int counter)
{
  int n;

  for (n = 0; n < npapievents; ++n)
    if (papieventlist[n] == counter)
      return n;
  return -1;
}

/*
** already_enabled: determine whether a PAPI-based event has already been
**   enabled for printing. 
**
** Input args: 
**   counter: PAPI or derived counter
**
** Return value: 1 (true) or 0 (false)
*/
 
int already_enabled (int counter)
{
  int n;

  for (n = 0; n < nevents; ++n)
    if (pr_event[n].event.counter == counter)
      return 1;
  return 0;
}

/*
** enable: enable a PAPI event. ASSUMES that canenable() has already determined
**   that the event can be enabled.
**
** Input args: 
**   counter: PAPI counter
**
** Return value: index into papieventlist
*/
 
int enable (int counter)
{
  int n;

  /* If the event is already enabled, return its index */

  for (n = 0; n < npapievents; ++n) {
    if (papieventlist[n] == counter) {
#ifdef DEBUG
      printf ("enable: PAPI event %d is %d\n", n, counter);
#endif
      return n;
    }
  }

  /* New event */

  papieventlist[npapievents++] = counter;
  return npapievents-1;
}

/*
** getderivedidx: find the table index of a derived counter
**
** Input args: 
**   counter: derived counter
**
** Return value: index into derivedtable (success) or GPTLerror (failure)
*/

int getderivedidx (int dcounter)
{
  int n;

  for (n = 0; n < nderivedentries; ++n) {
    if (derivedtable[n].counter == dcounter)
      return n;
  }
  return GPTLerror ("getderivedidx: failed to find derived counter %d\n", dcounter);
}

/*
** GPTL_PAPIlibraryinit: Call PAPI_library_init if necessary
**
** Return value: 0 (success) or GPTLerror (failure)
*/

int GPTL_PAPIlibraryinit ()
{
  int ret;

  if ((ret = PAPI_is_initialized ()) == PAPI_NOT_INITED) {
    if ((ret = PAPI_library_init (PAPI_VER_CURRENT)) != PAPI_VER_CURRENT) {
      fprintf (stderr, "GPTL_PAPIlibraryinit: ret=%d PAPI_VER_CURRENT=%d\n", 
	       ret, (int) PAPI_VER_CURRENT);
      return GPTLerror ("GPTL_PAPIlibraryinit: PAPI_library_init failure:%s\n",
			PAPI_strerror (ret));
    }
  }
  return 0;
}

/*
** GPTL_PAPIinitialize(): Initialize the PAPI interface. Called from GPTLinitialize.
**   PAPI_library_init must be called before any other PAPI routines.  
**   PAPI_thread_init is called subsequently if threading is enabled.
**   Finally, allocate space for PAPI counters and start them.
**
** Input args: 
**   maxthreads: number of threads
**
** Return value: 0 (success) or GPTLerror or -1 (failure)
*/
 
int GPTL_PAPIinitialize (const int maxthreads,     /* number of threads */
			 const bool verbose_flag,  /* output verbosity */
			 int *nevents_out,         /* nevents needed by gptl.c */
			 Entry *pr_event_out)      /* events needed by gptl.c */
{
  int ret;       /* return code */
  int n;         /* loop index */
  int t;         /* thread index */

  verbose = verbose_flag;

  if (maxthreads < 1)
    return GPTLerror ("GPTL_PAPIinitialize: maxthreads = %d\n", maxthreads);

  /* Ensure that PAPI_library_init has already been called */

  if ((ret = GPTL_PAPIlibraryinit ()) < 0)
    return GPTLerror ("GPTL_PAPIinitialize: GPTL_PAPIlibraryinit failure\n");

  /* PAPI_thread_init needs to be called if threading enabled */

#if ( defined THREADED_OMP )
  if (PAPI_thread_init ((unsigned long (*)(void)) (omp_get_thread_num)) != PAPI_OK)
    return GPTLerror ("GPTL_PAPIinitialize: PAPI_thread_init failure\n");
#elif ( defined THREADED_PTHREADS )
  if (PAPI_thread_init ((unsigned long (*)(void)) (pthread_self)) != PAPI_OK)
    return GPTLerror ("GPTL_PAPIinitialize: PAPI_thread_init failure\n");
#endif

  /* allocate and initialize static local space */

  EventSet     = (int *)        GPTLallocate (maxthreads * sizeof (int));
  papicounters = (long_long **) GPTLallocate (maxthreads * sizeof (long_long *));

  for (t = 0; t < maxthreads; t++) {
    EventSet[t] = PAPI_NULL;
    papicounters[t] = (long_long *) GPTLallocate (MAX_AUX * sizeof (long_long));
  }

  *nevents_out = nevents;
  for (n = 0; n < nevents; ++n) {
    pr_event_out[n].counter = pr_event[n].event.counter;
    pr_event_out[n].namestr = pr_event[n].event.namestr;
    pr_event_out[n].str8    = pr_event[n].event.str8;
    pr_event_out[n].str16   = pr_event[n].event.str16;
    pr_event_out[n].longstr = pr_event[n].event.longstr;
  }
  return 0;
}

/*
** GPTLcreate_and_start_events: Create and start the PAPI eventset.
**   Threaded routine to create the "event set" (PAPI terminology) and start
**   the counters. This is only done once, and is called from get_thread_num
**   for the first time for the thread.
** 
** Input args: 
**   t: thread number
**
** Return value: 0 (success) or GPTLerror (failure)
*/

int GPTLcreate_and_start_events (const int t)  /* thread number */
{
  int ret; /* return code */
  int n;   /* loop index over events */
  char eventname[PAPI_MAX_STR_LEN]; /* returned from PAPI_event_code_to_name */

  /* Create the event set */

  if ((ret = PAPI_create_eventset (&EventSet[t])) != PAPI_OK)
    return GPTLerror ("GPTLcreate_and_start_events: thread %d failure creating eventset: %s\n", 
		      t, PAPI_strerror (ret));

  if (verbose)
    printf ("GPTLcreate_and_start_events: successfully created eventset for thread %d\n", t);

  /* Add requested events to the event set */

  for (n = 0; n < npapievents; n++) {
    if ((ret = PAPI_add_event (EventSet[t], papieventlist[n])) != PAPI_OK) {
      if (verbose) {
	fprintf (stderr, "%s\n", PAPI_strerror (ret));
	ret = PAPI_event_code_to_name (papieventlist[n], eventname);
	fprintf (stderr, "GPTLcreate_and_start_events: failure adding event:%s\n",
		 eventname);
      }

      if (enable_multiplexing) {
        if (verbose)
	  printf ("Trying multiplexing...\n");
	is_multiplexed = true;
	break;
      } else
	return GPTLerror ("enable_multiplexing is false: giving up\n");
    }
  }

  if (is_multiplexed) {

    /* Cleanup the eventset for multiplexing */

    if ((ret = PAPI_cleanup_eventset (EventSet[t])) != PAPI_OK)
      return GPTLerror ("GPTLcreate_and_start_events: %s\n", PAPI_strerror (ret));
    
    if ((ret = PAPI_destroy_eventset (&EventSet[t])) != PAPI_OK)
      return GPTLerror ("GPTLcreate_and_start_events: %s\n", PAPI_strerror (ret));

    if ((ret = PAPI_create_eventset (&EventSet[t])) != PAPI_OK)
      return GPTLerror ("GPTLcreate_and_start_events: failure creating eventset: %s\n", 
			PAPI_strerror (ret));

    if ((ret = PAPI_multiplex_init ()) != PAPI_OK)
      return GPTLerror ("GPTLcreate_and_start_events: failure from PAPI_multiplex_init%s\n", 
			PAPI_strerror (ret));

    if ((ret = PAPI_set_multiplex (EventSet[t])) != PAPI_OK)
      return GPTLerror ("GPTLcreate_and_start_events: failure from PAPI_set_multiplex: %s\n", 
			PAPI_strerror (ret));

    for (n = 0; n < npapievents; n++) {
      if ((ret = PAPI_add_event (EventSet[t], papieventlist[n])) != PAPI_OK) {
	ret = PAPI_event_code_to_name (papieventlist[n], eventname);
	return GPTLerror ("GPTLcreate_and_start_events: failure adding event:%s\n"
			  "  Error was: %s\n", eventname, PAPI_strerror (ret));
      }
    }
  }

  /* Start the event set.  It will only be read from now on--never stopped */

  if ((ret = PAPI_start (EventSet[t])) != PAPI_OK)
    return GPTLerror ("GPTLcreate_and_start_events: failed to start event set: %s\n", 
		      PAPI_strerror (ret));

  return 0;
}

/*
** GPTL_PAPIstart: Start the PAPI counters (actually they are just read).  
**   Called from GPTLstart.
**
** Input args:  
**   t: thread number
**
** Output args: 
**   aux: struct containing the counters
**
** Return value: 0 (success) or GPTLerror (failure)
*/

int GPTL_PAPIstart (const int t,          /* thread number */
		    Papistats *aux)       /* struct containing PAPI stats */
{
  int ret;  /* return code from PAPI lib calls */
  int n;    /* loop index */
  
  /* If no events are to be counted just return */

  if (npapievents == 0)
    return 0;

  /* Read the counters */

  if ((ret = PAPI_read (EventSet[t], papicounters[t])) != PAPI_OK)
    return GPTLerror ("GPTL_PAPIstart: %s\n", PAPI_strerror (ret));

  /* 
  ** Store the counter values.  When GPTL_PAPIstop is called, the counters
  ** will again be read, and differenced with the values saved here.
  */

  for (n = 0; n < npapievents; n++)
    aux->last[n] = papicounters[t][n];
  
  return 0;
}

/*
** GPTL_PAPIstop: Stop the PAPI counters (actually they are just read).  
**   Called from GPTLstop.
**
** Input args:
**   t: thread number
**
** Input/output args: 
**   aux: struct containing the counters
**
** Return value: 0 (success) or GPTLerror (failure)
*/

int GPTL_PAPIstop (const int t,         /* thread number */
		   Papistats *aux)      /* struct containing PAPI stats */
{
  int ret;          /* return code from PAPI lib calls */
  int n;            /* loop index */
  long_long delta;  /* change in counters from previous read */

  /* If no events are to be counted just return */

  if (npapievents == 0)
    return 0;

  /* Read the counters */

  if ((ret = PAPI_read (EventSet[t], papicounters[t])) != PAPI_OK)
    return GPTLerror ("GPTL_PAPIstop: %s\n", PAPI_strerror (ret));
  
  /* 
  ** Accumulate the difference since timer start in aux.
  ** Negative accumulation can happen when multiplexing is enabled, so don't
  ** set count to BADCOUNT in that case.
  */

  for (n = 0; n < npapievents; n++) {
#ifdef DEBUG
    printf ("GPTL_PAPIstop: event %d counter value is %ld\n", n, (long) papicounters[t][n]);
#endif
    delta = papicounters[t][n] - aux->last[n];
    if ( ! is_multiplexed && delta < 0)
      aux->accum[n] = BADCOUNT;
    else
      aux->accum[n] += delta;
  }
  return 0;
}

/*
** GPTL_PAPIprstr: Print the descriptive string for all enabled PAPI events.
**   Called from GPTLpr.
**
** Input args: 
**   fp: file descriptor
*/

void GPTL_PAPIprstr (FILE *fp)
{
  int n;
  
  if (narrowprint) {
    for (n = 0; n < nevents; n++) {
      fprintf (fp, "%8.8s ", pr_event[n].event.str8);

      /* Test on < 0 says it's a PAPI preset */

      if (persec && pr_event[n].event.counter < 0)
	fprintf (fp, "e6_/_sec ");
    }
  } else {
    for (n = 0; n < nevents; n++) {
      fprintf (fp, "%16.16s ", pr_event[n].event.str16);

      /* Test on < 0 says it's a PAPI preset */

      if (persec && pr_event[n].event.counter < 0)
	fprintf (fp, "e6_/_sec ");
    }
  }
}

/*
** GPTL_PAPIpr: Print PAPI counter values for all enabled events, including
**   derived events. Called from GPTLpr.
**
** Input args: 
**   fp: file descriptor
**   aux: struct containing the counters
*/

void GPTL_PAPIpr (FILE *fp,                          /* file descriptor to write to */
		  const Papistats *aux,              /* stats to write */
		  const int t,                       /* thread number */
		  const int count,                   /* number of invocations */
		  const double wcsec)                /* wallclock time (sec) */
{
  const char *shortintfmt   = "%8ld ";
  const char *longintfmt    = "%16ld ";
  const char *shortfloatfmt = "%8.2e ";
  const char *longfloatfmt  = "%16.10e ";
  const char *intfmt;       /* integer format */
  const char *floatfmt;     /* floating point format */

  int n;              /* loop index */
  int numidx;         /* index pointer to appropriated (derived) numerator */
  int denomidx;       /* index pointer to appropriated (derived) denominator */
  double val;         /* value to be printed */

  intfmt   = narrowprint ? shortintfmt   : longintfmt;
  floatfmt = narrowprint ? shortfloatfmt : longfloatfmt;

  for (n = 0; n < nevents; n++) {
    numidx = pr_event[n].numidx;
    if (pr_event[n].denomidx > -1) {      /* derived event */
      denomidx = pr_event[n].denomidx;

#ifdef DEBUG
      printf ("GPTL_PAPIpr: derived event: numidx=%d denomidx=%d values = %ld %ld\n", 
	      numidx, denomidx, (long) aux->accum[numidx], (long) aux->accum[denomidx]);
#endif
      /* Protect against divide by zero */

      if (aux->accum[denomidx] > 0)
	val = (double) aux->accum[numidx] / (double) aux->accum[denomidx];
      else
	val = 0.;
      fprintf (fp, floatfmt, val);

    } else {                               /* Raw PAPI event */

#ifdef DEBUG
      printf ("GPTL_PAPIpr: raw event: numidx=%d value = %ld\n", 
	      numidx, (long) aux->accum[numidx]);
#endif
      if (aux->accum[numidx] < PRTHRESH)
	fprintf (fp, intfmt, (long) aux->accum[numidx]);
      else
	fprintf (fp, floatfmt, (double) aux->accum[numidx]);

      if (persec) {
	if (wcsec > 0.)
	  fprintf (fp, "%8.2f ", aux->accum[numidx] * 1.e-6 / wcsec);
	else
	  fprintf (fp, "%8.2f ", 0.);
      }
    }
  }
}

/*
** GPTL_PAPIprintenabled: Print list of enabled timers
**
** Input args:
**   fp: file descriptor
*/

void GPTL_PAPIprintenabled (FILE *fp)
{
  int n, nn;
  PAPI_event_info_t info;           /* returned from PAPI_get_event_info */
  char eventname[PAPI_MAX_STR_LEN]; /* returned from PAPI_event_code_to_name */

  if (nevents > 0) {
    fprintf (fp, "Description of printed events (PAPI and derived):\n");
    for (n = 0; n < nevents; n++) {
      if (strncmp (pr_event[n].event.namestr, "GPTL", 4) == 0) {
	fprintf (fp, "  %s: %s\n", pr_event[n].event.namestr, pr_event[n].event.longstr);
      } else {
	nn = pr_event[n].event.counter;
	if (PAPI_get_event_info (nn, &info) == PAPI_OK) {
	  fprintf (fp, "  %s\n", info.short_descr);
	  fprintf (fp, "  %s\n", info.note);
	}
      }
    }
    fprintf (fp, "\n");

    fprintf (fp, "PAPI events enabled (including those required for derived events):\n");
    for (n = 0; n < npapievents; n++)
      if (PAPI_event_code_to_name (papieventlist[n], eventname) == PAPI_OK)
	fprintf (fp, "  %s\n", eventname);
    fprintf (fp, "\n");
  }
}  

/*
** GPTL_PAPIadd: Accumulate PAPI counters. Called from add.
**
** Input/Output args: 
**   auxout: auxout = auxout + auxin
**
** Input args:
**   auxin: counters to be summed into auxout
*/

void GPTL_PAPIadd (Papistats *auxout,      /* output struct */
		   const Papistats *auxin) /* input struct */
{
  int n;
  
  for (n = 0; n < npapievents; n++)
    if (auxin->accum[n] == BADCOUNT || auxout->accum[n] == BADCOUNT)
      auxout->accum[n] = BADCOUNT;
    else
      auxout->accum[n] += auxin->accum[n];
}

/*
** GPTL_PAPIfinalize: finalization routine must be called from single-threaded
**   region. Free all malloc'd space
*/

void GPTL_PAPIfinalize (int maxthreads)
{
  int t;   /* thread index */
  int ret; /* return code */

  for (t = 0; t < maxthreads; t++) {
    ret = PAPI_stop (EventSet[t], papicounters[t]);
    free (papicounters[t]);
    ret = PAPI_cleanup_eventset (EventSet[t]);
    ret = PAPI_destroy_eventset (&EventSet[t]);
  }

  free (EventSet);
  free (papicounters);

  /* Reset initial values */

  npapievents = 0;
  nevents = 0;
  is_multiplexed = false;
  narrowprint = true;
  persec = true;
  enable_multiplexing = false;
  verbose = false;
}

/*
** GPTL_PAPIquery: return current PAPI counter info. Return into a long for best
**   compatibility possibilities with Fortran.
**
** Input args:
**   aux:       struct containing the counters
**   ncounters: max number of counters to return
**
** Output args:
**   papicounters_out: current value of PAPI counters
*/

void GPTL_PAPIquery (const Papistats *aux,
		     long long *papicounters_out,
		     int ncounters)
{
  int n;

  if (ncounters > 0) {
    for (n = 0; n < ncounters && n < npapievents; n++) {
      papicounters_out[n] = (long long) aux->accum[n];
    }
  }
}

/*
** GPTL_PAPIget_eventvalue: return current value for an enabled event.
**
** Input args:
**   eventname: event name to check (whether derived or raw PAPI counter)
**   aux:       struct containing the counter(s) for the event
**
** Output args:
**   value: current value of the event
**
** Return value: 0 (success) or GPTLerror (failure)
*/

int GPTL_PAPIget_eventvalue (const char *eventname,
			     const Papistats *aux,
			     double *value)
{
  int n;        /* loop index through enabled events */
  int numidx;   /* numerator index into papicounters */
  int denomidx; /* denominator index into papicounters */

  for (n = 0; n < nevents; ++n) {
    if (STRMATCH (eventname, pr_event[n].event.namestr)) {
      numidx = pr_event[n].numidx;
      if (pr_event[n].denomidx > -1) {  /* derived event */
	denomidx = pr_event[n].denomidx;
	if (aux->accum[denomidx] > 0)   /* protect against divide by zero */
	  *value = (double) aux->accum[numidx] / (double) aux->accum[denomidx];
	else
	  *value = 0.;
      } else {        /* Raw PAPI event */
	*value = (double) aux->accum[numidx];
      }
      break;
    }
  }
  if (n == nevents)
    return GPTLerror ("GPTL_PAPIget_eventvalue: event %s not enabled\n", eventname);
  return 0;
}

/*
** GPTL_PAPIis_multiplexed: return status of whether events are being multiplexed
*/

bool GPTL_PAPIis_multiplexed ()
{
  return is_multiplexed;
}

/*
** The following functions are publicly available
*/

void read_counters100 ()
{
  int i;
  int ret;
  long_long counters[MAX_AUX];

  for (i = 0; i < 10; ++i) {
    ret = PAPI_read (EventSet[0], counters);
    ret = PAPI_read (EventSet[0], counters);
    ret = PAPI_read (EventSet[0], counters);
    ret = PAPI_read (EventSet[0], counters);
    ret = PAPI_read (EventSet[0], counters);
    ret = PAPI_read (EventSet[0], counters);
    ret = PAPI_read (EventSet[0], counters);
    ret = PAPI_read (EventSet[0], counters);
    ret = PAPI_read (EventSet[0], counters);
    ret = PAPI_read (EventSet[0], counters);
  }
  return;
}

/*
** GPTLevent_name_to_code: convert a string to a PAPI code
** or derived event code.
**
** Input arguments:
**   arg: string to convert
**
** Output arguments:
**   code: PAPI or GPTL derived code
**
** Return value: 0 (success) or GPTLerror (failure)
*/

int GPTLevent_name_to_code (const char *name, int *code)
{
  int ret;   /* return code */
  int n;     /* loop over derived entries */

  /*
  ** First check derived events 
  */

  for (n = 0; n < nderivedentries; ++n) {
    if (STRMATCH (name, derivedtable[n].namestr)) {
      *code = derivedtable[n].counter;
      return 0;
    }
  }

  /*
  ** Next check PAPI events--note that PAPI must be initialized before the
  ** name_to_code function can be invoked.
  */

  if ((ret = GPTL_PAPIlibraryinit ()) < 0)
    return GPTLerror ("GPTL_event_name_to_code: GPTL_PAPIlibraryinit failure\n");

  if ((PAPI_event_name_to_code ((char *) name, code)) != PAPI_OK)
    return GPTLerror ("GPTL_event_name_to_code: PAPI_event_name_to_code failure\n");

  return 0;
}

/*
** GPTLevent_code_to_name: convert a string to a PAPI code
** or derived event code.
**
** Input arguments:
**   code: event code (PAPI or derived)
**
** Output arguments:
**   name: string corresponding to code
**
** Return value: 0 (success) or GPTLerror (failure)
*/

int GPTLevent_code_to_name (const int code, char *name)
{
  int ret;   /* return code */
  int n;     /* loop over derived entries */

  /*
  ** First check derived events 
  */

  for (n = 0; n < nderivedentries; ++n) {
    if (code == derivedtable[n].counter) {
      strcpy (name, derivedtable[n].namestr);
      return 0;
    }
  }

  /*
  ** Next check PAPI events--note that PAPI must be initialized before the
  ** code_to_name function can be invoked.
  */

  if ((ret = GPTL_PAPIlibraryinit ()) < 0)
    return GPTLerror ("GPTL_event_code_to_name: GPTL_PAPIlibraryinit failure\n");

  if (PAPI_event_code_to_name (code, name) != PAPI_OK)
    return GPTLerror ("GPTL_event_code_to_name: PAPI_event_code_to_name failure\n");

  return 0;
}

int GPTLget_npapievents (void)
{
  return npapievents;
}

#else

/*
** HAVE_PAPI not defined branch: "Should not be called" entry points for public routines
*/

int GPTL_PAPIlibraryinit ()
{
  return GPTLerror ("GPTL_PAPIlibraryinit: PAPI not enabled\n");
}

int GPTLevent_name_to_code (const char *name, int *code)
{
  return GPTLerror ("GPTLevent_name_to_code: PAPI not enabled\n");
}

int GPTLevent_code_to_name (int code, char *name)
{
  return GPTLerror ("GPTLevent_code_to_name: PAPI not enabled\n");
}

#endif  /* HAVE_PAPI */

