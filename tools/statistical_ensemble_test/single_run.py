#! /usr/bin/env python
from __future__ import print_function
import sys, getopt, os

#
# Command options
#
def disp_usage(callType):
    if callType == "ensemble.py":
        print(
            "\nSets up multiple CESM cases for either an ensemble of runs or a small (CAM-ECT = 3, POP-ECT = 1)"
        )
        print("test set (default). Then use pyCECT utilities to create an ensemble")
        print(
            "summary file or to evaluate the small test set of runs against the ensemble."
        )
        print("  ")
        print("----------------------------")
        print("ensemble.py :")
    else:
        print("\nSets up a single CESM case. ")
        print("  ")
        print("----------------------------")
        print("single_run.py :")
    print("----------------------------")
    print(" ")
    print("Required flags:")
    if callType == "single_run.py":
        print(
            "  --case <name>    Case name passed on to create_newcase (incl. full path AND same)"
        )
    else:
        print(
            '  --case <name>    Case name passed on to create_newcase (incl. full path AND must end in ".0000")'
        )
    print("  --mach <name>    Machine name passed on to create_newcase")
    print(" ")
    print('Optional flags (+ all "--" options to create_newcase): ')
    print("  --project <num>     Project number to charge in job scripts")
    print(
        "  --ect <cam,pop>     Specify whether ensemble is for CAM-ECT or POP-ECT (default = cam)"
    )
    if callType == "single_run.py":
        print("  --pertlim <num>     Run (CAM or POP) with specified non-zero pertlim")
    print(
        "  --walltime <hr:mn>  Amount of walltime requested (default = 4:30 (CAM-ECT) 2:00 (POP-ECT), or 0:10 with --uf enabled)"
    )
    print("  --compiler <name>   Compiler to use (default = same as Machine default) ")
    print(
        "  --compset <name>    Compset to use (default = F2000climo (CAM-ECT) or G (POP-ECT))"
    )
    print(
        "  --res <name>        Resolution to run (default = f19_f19 (CAM-ECT) or T62_g17 (POP-ECT))"
    )
    print(
        "  --uf                Enable ninth time step runs (ultra-fast mode for CAM-ECT) - otherwise the default is 12-month runs"
    )
    if callType == "ensemble.py":
        print(
            "  --nb                Disables auto building the root case of the ensemble"
        )
        print(
            "  --ns                Disables auto submitting any members of the ensemble"
        )
        print(
            "  --ens_start <start> Start ensemble creation at this number (default is 0)"
        )
        print(
            "  --ensemble <size>   Build the ensemble (instead of building case(s) with random pertlim values for verification),"
        )
        print(
            "                      and specify the number of ensemble members to generate (e.g.: 151 for CAM-ECT annual averages "
        )
        print(
            "                      or 350 for ultra-fast CAM-ECT mode or 40 for POP-ECT)"
        )
    else:
        print("  --nb                Disables building (and submitting) the single case")
        print("  --ns                Disables submitting the single case")
    print("  --help, -h          Prints out this usage message")


########
def process_args_dict(caller, caller_argv):

    # Pull in and analyze the command line arguements
    s = "case= mach= project= compiler= compset= res= uf nb ns ensemble= verbose silent test multi-driver pecount= nist= mpilib= pesfile= gridfile= srcroot= output-root= script-root= queue= user-modes-dir= input-dir= pertlim= walltime= h ens_start= ect= ngpus-per-node= gpu-type= gpu-offload="

    optkeys = s.split()

    try:
        opts, args = getopt.getopt(caller_argv, "hf:", optkeys)

    except getopt.GetoptError:
        print("\nERROR: unrecognized command line argument")
        disp_usage(caller)
        sys.exit(2)

    # check for help
    for opt, arg in opts:
        if opt == "-h":
            disp_usage(caller)
            sys.exit()

    # opts_dict and defaults
    opts_dict = {}
    opts_dict["walltime"] = "00:00"
    opts_dict["pertlim"] = "0"
    opts_dict["nb"] = False
    opts_dict["ns"] = False
    opts_dict["uf"] = False
    opts_dict["ensemble"] = 0
    opts_dict["ect"] = "cam"
    opts_dict["ens_start"] = 0
    # for create newcase
    opts_dict["verbose"] = False
    opts_dict["silent"] = False
    opts_dict["test"] = False
    opts_dict["multi-driver"] = False
    opts_dict["case"] = "NONE"
    opts_dict["mach"] = "NONE"
    opts_dict["compset"] = "NONE"
    opts_dict["res"] = "NONE"
    opts_dict["ngpus-per-node"] = 0
    opts_dict["gpu-type"] = "NONE"
    opts_dict["gpu-offload"] = "NONE"

    s_case_flags = ""

    # opts_dict = utility.getopt_parseconfig(opts, optkeys, caller, opts_dict)
    for opt, arg in opts:
        if opt == "--case":
            opts_dict["case"] = arg
            s_case_flags += " " + opt + " " + arg
        elif opt == "--mach":
            opts_dict["mach"] = arg
            s_case_flags += " " + opt + " " + arg
        elif opt == "--project":
            opts_dict["project"] = arg
            s_case_flags += " " + opt + " " + arg
        elif opt == "--compset":
            opts_dict["compset"] = arg
            # required - add to flags later
        elif opt == "--res":
            opts_dict["res"] = arg
            # required - add to flags later
        elif opt == "--ens_start":
            opts_dict["ens_start"] = int(arg)
        elif opt == "--ect":
            opts_dict["ect"] = arg
        elif opt == "--ensemble":
            opts_dict["ensemble"] = int(arg)
        elif opt == "--compiler":
            opts_dict["compiler"] = arg
            s_case_flags += " " + opt + " " + arg
        elif opt == "--pertlim":
            if caller == "ensemble.py":
                print("WARNING: pertlim ignored for ensemble.py.")
                opts_dict["pertlim"] = "0"
            else:
                opts_dict["pertlim"] = arg
        elif opt == "--project":
            opts_dict["project"] = arg
            s_case_flags += " " + opt + " " + arg
        elif opt == "--uf":
            opts_dict["uf"] = True
        elif opt == "--nb":
            opts_dict["nb"] = True
        elif opt == "--ns":
            opts_dict["ns"] = True
        elif opt == "--verbose":
            opts_dict["verbose"] = True
            s_case_flags += " " + opt
        elif opt == "--silent":
            opts_dict["silent"] = True
            s_case_flags += " " + opt
        elif opt == "--test":
            opts_dict["test"] = True
            s_case_flags += " " + opt
        elif opt == "--multi-driver":
            opts_dict["multi-driver"] = True
            s_case_flags += " " + opt
        elif opt == "--nist":
            opts_dict["nist"] = arg
            s_case_flags += " " + opt + " " + arg
        elif opt == "--pecount":
            opts_dict["pecount"] = arg
            s_case_flags += " " + opt + " " + arg
        elif opt == "--mpilib":
            opts_dict["mpilib"] = arg
            s_case_flags += " " + opt + " " + arg
        elif opt == "--pesfile":
            opts_dict["pesfile"] = arg
            s_case_flags += " " + opt + " " + arg
        elif opt == "--srcroot":
            opts_dict["srcroot"] = arg
            s_case_flags += " " + opt + " " + arg
        elif opt == "--output-root":
            opts_dict["output-root"] = arg
            s_case_flags += " " + opt + " " + arg
        elif opt == "--script-root":
            opts_dict["script-root"] = arg
            s_case_flags += " " + opt + " " + arg
        elif opt == "--queue":
            opts_dict["queue"] = arg
            s_case_flags += " " + opt + " " + arg
        elif opt == "--input-dir":
            opts_dict["input-dir"] = arg
            s_case_flags += " " + opt + " " + arg
        elif opt == "--user-modes-dir":
            opts_dict["user-modes-dir"] = arg
            s_case_flags += " " + opt + " " + arg
        elif opt == "--walltime":
            opts_dict["walltime"] = arg
        elif opt == "--ngpus-per-node":
            opts_dict["ngpus-per-node"] = arg
            s_case_flags += " " + opt + " " + arg
        elif opt == "--gpu-type":
            opts_dict["gpu-type"] = arg
            s_case_flags += " " + opt + " " + arg
        elif opt == "--gpu-offload":
            opts_dict["gpu-offload"] = arg
            s_case_flags += " " + opt + " " + arg
            # add below

    # check required things: case, machine
    if opts_dict["mach"] == "NONE":
        print("Error: Must specify machine (--mach)")
        sys.exit()
    if opts_dict["case"] == "NONE":
        print("Error: Must specify case (--case)")
        sys.exit()
    else:
        case = opts_dict["case"]
        if caller == "ensemble.py":
            if case[-5:] != ".0000":
                print(
                    'Error: when using ensemble.py, the case name (--case) must end in ".0000".'
                )
                sys.exit()
        case_dir = os.path.dirname(case)
        if os.path.isdir(case_dir) == False:
            print("Error: Need a valid full path with the case name (--case).")
            sys.exit()
    # defaults for resolution and case
    if opts_dict["ect"] == "pop":
        if opts_dict["compset"] == "NONE":
            opts_dict["compset"] = "G"
        if opts_dict["res"] == "NONE":
            opts_dict["res"] = "T62_g17"
    else:  # cam
        if opts_dict["compset"] == "NONE":
            opts_dict["compset"] = "F2000climo"
        if opts_dict["res"] == "NONE":
            opts_dict["res"] = "f19_f19"

    if opts_dict["walltime"] == "00:00":
        if opts_dict["uf"] == True:
            opts_dict["walltime"] = "00:10"
        else:
            if opts_dict["ect"] == "pop":
                opts_dict["walltime"] = "02:00"
            else:
                opts_dict["walltime"] = "04:30"
    s_case_flags += " --walltime " + opts_dict["walltime"]

    return opts_dict, s_case_flags


#######


def single_case(opts_dict, case_flags, stat_dir):

    # scripts dir
    ret = os.chdir(stat_dir)
    ret = os.chdir("../../cime/scripts")

    ##res and compset are required for create_newcase
    case_flags += (
        " --compset "
        + opts_dict["compset"]
        + " --res "
        + opts_dict["res"]
        + " --run-unsupported"
    )

    # create newcase
    print("STATUS: create_newcase flags = " + case_flags)
    command = "./create_newcase " + case_flags
    ret = os.system(command)

    if ret != 0:
        print("ERROR: create_newcase returned a non-zero exit code.")
        sys.exit()

    # modify namelist settings
    this_case = opts_dict["case"]
    print("STATUS: case  = " + this_case)
    ret = os.chdir(this_case)

    command = "chmod u+w *"
    ret = os.system(command)

    command = "cp env_run.xml env_run.xml.orig"
    ret = os.system(command)

    print("STATUS: Adjusting env_run.xml....")
    command = "./xmlchange --file env_run.xml --id BFBFLAG --val TRUE"
    ret = os.system(command)
    command = "./xmlchange --file env_run.xml --id DOUT_S --val FALSE"
    ret = os.system(command)
    command = "./xmlchange --file env_run.xml --id REST_OPTION --val never"
    ret = os.system(command)

    # time steps
    if opts_dict["ect"] == "pop":
        command = "./xmlchange --file env_run.xml --id STOP_OPTION --val nyears"
        ret = os.system(command)
        command = "  ./xmlchange --file env_run.xml --id STOP_N --val 1"
        ret = os.system(command)
    else:
        if opts_dict["uf"] == True:
            command = "./xmlchange --file env_run.xml --id STOP_OPTION --val nsteps"
            ret = os.system(command)
            command = "  ./xmlchange --file env_run.xml --id STOP_N --val 9"
            ret = os.system(command)
        else:
            command = "./xmlchange --file env_run.xml --id STOP_OPTION --val nmonths"
            ret = os.system(command)
            command = "./xmlchange --file env_run.xml --id STOP_N --val 12"
            ret = os.system(command)

    print("STATUS: updating ROF_NCPL...")
    command = "./xmlchange ROF_NCPL=48"
    ret = os.system(command)

    print("STATUS: running setup for single case...")
    command = "./case.setup"
    ret = os.system(command)

    print("STATUS: Adjusting user_nl_* files....")

    # POP-ECT
    if opts_dict["ect"] == "pop":
        if os.path.isfile("user_nl_pop") == True:
            with open("user_nl_pop", "a") as f:
                if opts_dict["pertlim"] != "0":
                    text = "\ninit_ts_perturb = {}".format(opts_dict["pertlim"])
                    f.write(text)
        else:
            print("Warning: no user_nl_pop found")
    else:
        # CAM-ECT
        # cam
        if os.path.isfile("user_nl_cam") == True:
            if opts_dict["uf"] == True:
                text1 = "\navgflag_pertape = 'I'"
                text2 = "\nnhtfrq  = 9"
            else:
                text1 = "\navgflag_pertape = 'A'"
                text2 = "\nnhtfrq  = -8760"

            text3 = "\ninithist = 'NONE'"

            with open("user_nl_cam", "a") as f:
                f.write(text1)
                f.write(text2)
                f.write(text3)
                if opts_dict["pertlim"] != "0":
                    text = "\npertlim = " + opts_dict["pertlim"]
                    f.write(text)
        else:
            print("Warning: no user_nl_cam found")

        # clm
        if os.path.isfile("user_nl_clm") == True:
            if opts_dict["uf"] == True:
                text1 = "\nhist_avgflag_pertape = 'I'"
                text2 = "\nhist_nhtfrq  = 9"
            else:
                text1 = "\nhist_avgflag_pertape = 'A'"
                text2 = "\nhist_nhtfrq  = -8760"

            with open("user_nl_clm", "a") as f:
                f.write(text1)
                f.write(text2)

        # disable ice output
        if os.path.isfile("user_nl_cice") == True:
            text = "\nhistfreq = 'x','x','x','x','x'"
            with open("user_nl_cice", "a") as f:
                f.write(text)

        # pop
        if os.path.isfile("user_nl_pop") == True:
            text = ["'\nn_tavg_streams = 1"]
            text.append("\nldiag_bsf = .false.")
            text.append("\nldiag_global_tracer_budgets = .false.")
            text.append("\nldiag_velocity = .false.")
            text.append("\ndiag_gm_bolus = .false.")
            text.append("\nltavg_nino_diags_requested = .false.")
            text.append("\nmoc_requested = .false.")
            text.append("\nn_heat_trans_requested = .false.")
            text.append("\nn_salt_trans_requested = .false.")
            test.append("\ntavg_freq_opt = 'once', 'never', 'never'")
            text.append("\ntavg_file_freq_opt = 'once', 'never', 'never'")
            text.append("\ndiag_cfl_freq_opt = 'never'")
            text.append("\ndiag_global_freq_opt = 'never'")
            text.append("\ndiag_transp_freq_opt = 'never'")

            with open("user_nl_pop", "a") as f:
                for i in range(len(text)):
                    f.write(text[i])

    # preview namelists
    print("STATUS: Updating namelists....")
    command = "./preview_namelists"
    ret = os.system(command)

    # Build executable
    nb = opts_dict["nb"]
    ns = opts_dict["ns"]
    print("STATUS: no-build = " + str(nb))
    print("STATUS: no-submit = " + str(ns))
    if nb == False:
        print("STATUS: building case ...")
        command = "./case.build"
        ret = os.system(command)
        if ret != 0:
            print("Error building...")
            sys.exit()
        if ns == False:
            command = "./case.submit"
            ret = os.system(command)


########
def main(argv):

    caller = "single_run.py"

    # directory with single_run.py and ensemble.py
    stat_dir = os.path.dirname(os.path.realpath(__file__))
    print("STATUS: stat_dir = " + stat_dir)

    opts_dict, case_flags = process_args_dict(caller, argv)

    single_case(opts_dict, case_flags, stat_dir)

    print("STATUS: completed single run setup.")


########
if __name__ == "__main__":
    main(sys.argv[1:])
