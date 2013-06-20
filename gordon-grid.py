#!/usr/bin/env python
#
#  Calculate the ION/compute node distribution and torus topologyfor SDSC Gordon
#
#  Glenn K. Lockwood, San Diego Supercomputer Center                June 2013
#

import sys

ion_racks = [ 1, 10, 12, 21 ]
ion_per_rack = 16       # ions per IO rack, NOT ions per compute rack

compute_racks = [ 2, 3, 4, 5, 6, 7, 8, 9, 13, 14, 15, 16, 17, 18, 19, 20, 21 ]
compute_per_row = 8
compute_per_subrack = compute_per_row * 2
compute_per_rack = compute_per_subrack * 4

torus_size = ( 4, 4, 4 )

compute_per_ion = 16

for abs_node in range(0, 1024):

    if (abs_node % compute_per_ion == 0):
        abs_ion = int(abs_node / compute_per_ion)
        ion_x = int(abs_ion / torus_size[2]) % torus_size[0]
        ion_y = int(abs_ion / torus_size[2] / torus_size[0] )
        ion_z = abs_ion % torus_size[2]
        my_ion_rack = ion_racks[int(abs_ion/compute_per_ion)]
        my_ion_row = abs_ion % ion_per_rack + 1
        my_ion_string = "ion-%d-%d" % ( my_ion_rack, my_ion_row )
        sys.stdout.write('=== %10s  %1d, %1d, %1d =======================================================\n'
         % (my_ion_string, ion_x, ion_y, ion_z ) )

    my_rack = compute_racks[int(abs_node / compute_per_rack)]
    node_within_rack = abs_node % compute_per_rack
    my_row = int(node_within_rack / compute_per_row) + 1
    my_subrack = int(abs_node / compute_per_subrack)
    my_col = node_within_rack % 8  + 1
    my_slot = 10*my_row + my_col
    my_node_string = "gcn-%d-%d " % ( my_rack, my_slot )
    sys.stdout.write("%10s" % my_node_string)

    if (my_col == 8):
        sys.stdout.write('\n')
