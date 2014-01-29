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

printf "%12s %5s %5s %5s %7s\n" "user" "jobs" "nodes" "cores" "SUs"
nodeview $1 --jobview \
    | sed -e 's/:/ /g' \
    | awk '/Runn/ { printf( "%8d %12s %2d %2d %4d %6d\n", $1, $5, $3, $4, $7, $3*$4*($7+$8/60.0+$9/3600.0) ) }' \
    | awk '{ 
        sus[$2] += $6; 
        njob[$2]++; 
        nnod[$2] += $3 * $4 / '$ppn';
        ncores[$2] += $3*$4;
    } END { 
        for (i in sus) { 
            if ( i != "" ) { 
                printf("%12s %5d %5d %5d %7d\n", 
                    i, 
                    njob[i],
                    nnod[i],
                    ncores[i], 
                    sus[i] );
            } 
        } 
    }'
