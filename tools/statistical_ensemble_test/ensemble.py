#!/usr/bin/python
from __future__ import print_function
import os, sys, getopt
import random
from single_run import process_args_dict, single_case

# ==============================================================================
# set up and submit 12-month (original) or 9-time step (uf) run.  then create
# clones for a complete ensemble or a set of (3) test cases
# ==============================================================================

# generate <num_pick> positive random integers in [0, end-1]
# can't have any duplicates
def random_pick(num_pick, end):
    ar = range(0, end)
    rand_list = random.sample(ar, num_pick)
    # for i in rand_list:
    #    print i
    return rand_list


# get the pertlim corressponding to the random int
def get_pertlim_uf(rand_num):
    i = rand_num
    if i == 0:
        ptlim = 0
    else:
        j = 2 * int((i - 1) / 100) + 101
        k = (i - 1) % 100
        if i % 2 != 0:
            ll = j + int(k / 2) * 18
            ippt = str(ll).zfill(3)
            ptlim = "0." + ippt + "d-13"
        else:
            ll = j + int((k - 1) / 2) * 18
            ippt = str(ll).zfill(3)
            ptlim = "-0." + ippt + "d-13"
    return ptlim


def main(argv):

    caller = "ensemble.py"

    # directory with single_run.py and ensemble.py
    stat_dir = os.path.dirname(os.path.realpath(__file__))
    print("STATUS: stat_dir = " + stat_dir)

    opts_dict, case_flags = process_args_dict(caller, argv)

    # default is verification mode (3 runs)
    run_type = "verify"
    if opts_dict["ect"] == "pop":
        clone_count = 0
    else:
        clone_count = 2

    uf = opts_dict["uf"]

    # check for run_type change (i.e., if doing ensemble instead of verify)
    ens_size = opts_dict["ensemble"]
    if ens_size > 0:
        run_type = "ensemble"
        clone_count = ens_size - 1
        if ens_size > 999:
            print("Error: cannot have an ensemble size greater than 999.")
            sys.exit()
        print("STATUS: ensemble size = " + str(ens_size))

    # generate random pertlim(s) for verify
    if run_type == "verify":
        if opts_dict["ect"] == "pop":
            rand_ints = random_pick(1, 40)
        else:  # cam
            if uf:
                end_range = 350
            else:
                end_range = 150
            rand_ints = random_pick(3, end_range)

    # now create cases
    print("STATUS: creating first case ...")

    # create first case - then clone
    if run_type == "verify":
        opts_dict["pertlim"] = get_pertlim_uf(rand_ints[0])
    else:  # full ensemble
        opts_dict["pertlim"] = "0"

    # first case
    single_case(opts_dict, case_flags, stat_dir)

    # clone?
    if clone_count > 0:

        # now clone
        print("STATUS: cloning additional cases ...")

        # scripts dir
        print("STATUS: stat_dir = " + stat_dir)
        ret = os.chdir(stat_dir)
        ret = os.chdir("../../cime/scripts")
        scripts_dir = os.getcwd()
        print("STATUS: scripts dir = " + scripts_dir)

        # we know case name ends in '.000' (already checked)
        clone_case = opts_dict["case"]
        case_pfx = clone_case[:-4]

        for i in range(1, clone_count + 1):  # 1: clone_count
            if run_type == "verify":
                this_pertlim = get_pertlim_uf(rand_ints[i])
            else:  # full ensemble
                this_pertlim = get_pertlim_uf(i)

            iens = "{0:03d}".format(i)
            new_case = case_pfx + "." + iens

            os.chdir(scripts_dir)
            print("STATUS: creating new cloned case: " + new_case)

            clone_args = " --keepexe --case " + new_case + " --clone " + clone_case
            print("        with args: " + clone_args)

            command = scripts_dir + "/create_clone" + clone_args
            ret = os.system(command)

            print("STATUS: running setup for new cloned case: " + new_case)
            os.chdir(new_case)
            command = "./case.setup"
            ret = os.system(command)

            # adjust perturbation
            if opts_dict["ect"] == "pop":
                if run_type == "verify":  # remove old init_ts_perturb
                    f = open("user_nl_pop", "r+")
                    all_lines = f.readlines()
                    f.seek(0)
                    for line in all_lines:
                        if line.find("init_ts_perturb") == -1:
                            f.write(line)
                    f.truncate()
                    f.close()
                    text = "init_ts_perturb = " + this_pertlim
                else:
                    text = "\ninit_ts_perturb = " + this_pertlim

                # now append new pertlim
                with open("user_nl_pop", "a") as f:
                    f.write(text)

            else:
                if run_type == "verify":  # remove old pertlim first
                    f = open("user_nl_cam", "r+")
                    all_lines = f.readlines()
                    f.seek(0)
                    for line in all_lines:
                        if line.find("pertlim") == -1:
                            f.write(line)
                    f.truncate()
                    f.close()
                    text = "pertlim = " + this_pertlim
                else:
                    text = "\npertlim = " + this_pertlim

                # now append new pertlim
                with open("user_nl_cam", "a") as f:
                    f.write(text)

            # preview namelists
            command = "./preview_namelists"
            ret = os.system(command)

            # submit?
            if opts_dict["ns"] == False:
                command = "./case.submit"
                ret = os.system(command)

    # Final output
    if run_type == "verify":
        if opts_dict["ect"] == "pop":
            print("STATUS: ---POP-ECT VERIFICATION CASE COMPLETE---")
            print("Set up one case using the following init_ts_perturb value:")
            print(get_pertlim_uf(rand_ints[0]))
        else:
            print("STATUS: ---CAM-ECT VERIFICATION CASES COMPLETE---")
            print("Set up three cases using the following pertlim values:")
            print(
                get_pertlim_uf(rand_ints[0])
                + "   "
                + get_pertlim_uf(rand_ints[1])
                + "   "
                + get_pertlim_uf(rand_ints[2])
            )
    else:
        print("STATUS: --ENSEMBLE CASES COMPLETE---")


if __name__ == "__main__":
    main(sys.argv[1:])
