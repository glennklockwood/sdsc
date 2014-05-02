#!/bin/bash
################################################################################
#  whoscloggin.sh - Figure out who's clogging up the system on an SU-, node-,
#     job-, or core-basis.  Depends on the 'nodeview' command for now
#
#  Glenn K. Lockwood, San Diego Supercomputer Center             January 2014
################################################################################
#
# This script produces two stages of output
#
# Stage 1 is the output of the first awk and prints out the following columns:
#    jobid       userid nnodes ppn wallhrs sus_req
#  1899114       cipres      1   8     100     800
#
# Stage 2 is the output of the second awk and prints out the following columns:
#       userid  tot_sus tot_jobs    tot_nodes   tot_cores
#       cipres   267664      119          131        1816
#
# It is probably helpful to pipe the output to 'sort -n -k 2' or something
# similar.  You may also pass in a --readdb=... as a command line argument.

cluster=$(uname -n)
if [[ $cluster =~ ^(gordon|gcn|tscc) ]]; then
  ppn=16
elif [[ $cluster =~ ^trestles ]]; then
  ppn=32
else
  echo "ERROR: Unknown cluster!  Please specify ppn manually within the script." >&2
  exit 1
fi

printf "%12s %5s %5s %5s %5s %7s %7s\n" "user" "jobs" "nodes" "cores" "hours" "SUs" "SUs.q"
nodeview $1 --jobview 2>/dev/null\
    | sed -e 's/:/ /g' \
    | awk '/(Running|Queued)/ { printf( "%12s %8d %12s %2d %2d %4d %6d\n", $2, $1, $5, $3, $4, $7, $3*$4*($7+$8/60.0+$9/3600.0) ) }' \
    | awk '{ 
        user=$3;
        njob[user]++; 
        if ( $1 == "Running" ) {
          sus_r[user] += $7; 
          njob_r[user]++; 
          nnod_r[user] += $4 * $5 / '$ppn';
          ncores_r[user] += $4*$5;
          nhrs_r[user] += $6;
        }
        else if ( $1 == "Queued" ) { 
          sus_q[user] += $7;
        }
    } END { 
        for (i in njob) { 
            if ( i != "" ) { 
                printf("%12s %5d %5d %5d %5d %7d %7d\n", 
                    i, 
                    njob_r[i],
                    nnod_r[i],
                    ncores_r[i], 
                    nhrs_r[i],
                    sus_r[i],
                    sus_q[i] );
            } 
        } 
    }'
