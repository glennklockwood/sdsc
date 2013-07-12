#!/usr/bin/env python
#
#  Calculate the ION/compute node distribution and torus topology for SDSC 
#  Gordon and optionally determine hop distribution for a given list of nodes
#
#  Glenn K. Lockwood, San Diego Supercomputer Center                June 2013

import sys

def main(argv):

    if len(argv) > 1 and (argv[1] == '--help' or argv[1] == '-h'):
        print_help(argv)
        sys.exit(0)
    if len(argv) == 2:
        sys.stderr.write('You must provide at least two nodes to calculate '
            + 'hop distances.\n')
        sys.exit(1)

    # define key parameters describing Gordon's layout
    topo_params = {
        'torus_size':           ( 4, 4, 4 ),
        'ion_racks':            [ 1, 10, 12, 21 ],
        # ions per IO rack, NOT ions per compute rack
        'ion_per_rack':         16,
        'compute_racks':        [  2,  3,  4,  5,  6,  7,  8,  9, 
                                  13, 14, 15, 16, 17, 18, 19, 20 ],
        'compute_per_row':      8,
        'compute_per_ion':      16
    }
    topo_params['compute_per_subrack'] = topo_params['compute_per_row'] * 2
    topo_params['compute_per_rack']    = topo_params['compute_per_subrack'] * 4

    # the following are purely derived quantities expressed for clarity.  
    # total_ions and total_subracks are identical quantities
    topo_params['total_ions'] = ( topo_params['torus_size'][0] 
                                * topo_params['torus_size'][1] 
                                * topo_params['torus_size'][2] )
    topo_params['total_computes'] = ( topo_params['total_ions']
                                    * topo_params['compute_per_ion'] )
    topo_params['total_subracks'] = ( topo_params['total_computes']
                                    / topo_params['compute_per_subrack'] )
    topo_params['subracks_per_rack']  = ( topo_params['total_subracks']
                                        / len(topo_params['compute_racks']) )

    topo_data = get_gordon_topology(topo_params)
    if len(argv) > 3:
        calculate_hop_distribution(argv[1:], topo_data)
    elif len(argv) == 3:
        calculate_hop_pair( argv[1:], topo_data )
    else:
        print_gordon_nodes(topo_data, topo_params)

### print_gordon_nodes: generate pretty printout of all Gordon compute nodes
###   grouped by their associated IO node
def print_gordon_nodes(topo_data, topo_params):
    for abs_ion, ion in enumerate(topo_data['ion_list']):
        # extra blank line separating compute racks
        if (abs_ion % topo_params['subracks_per_rack']) == 0:
            sys.stdout.write("\n")
        # print io node name
        sys.stdout.write( '== %s at (%d, %d, %d) ==' % (ion, 
            topo_data['ion2torus'][ion][0],
            topo_data['ion2torus'][ion][1],
            topo_data['ion2torus'][ion][2]) )
        # print all compute nodes arranged according to subrack
        for index, node in enumerate(topo_data['ion2compute'][ion]):
            if (index % topo_params['compute_per_ion']) == 0:
                sys.stdout.write("\n");
            sys.stdout.write("%10s" % node)
            if ((index+1) % topo_params['compute_per_row']) == 0:
                sys.stdout.write("\n");

### print_gordon_graph: generate graph connectivity data in the 'dot' format
###   amenable to being plugged into graphviz
def print_gordon_graph(topo_data, topo_params):
    n_ions = len(topo_data['ion_list'])
    neighbor_count = {}

    # Print torus nodes
    for i in range(0, n_ions-1):
        for j in range(i+1, n_ions):
            ion1, ion2 = ( topo_data['ion_list'][i], topo_data['ion_list'][j] )
            hops = get_hops( topo_data['ion2torus'][ion1], 
                             topo_data['ion2torus'][ion2],
                             topo_data['torus_size'] )
            if hops == 1:
                print( '"%s" -- "%s";' % (ion1, ion2) )
                try:
                    neighbor_count[ion1]
                except KeyError:
                    neighbor_count[ion1] = 1
                else:
                    neighbor_count[ion1] += 1
                try:
                    neighbor_count[ion2]
                except KeyError:
                    neighbor_count[ion2] = 1
                else:
                    neighbor_count[ion2] += 1

    for ion in topo_data['ion_list']:
        for compute in topo_data['ion2compute'][ion]:
            print( '"%s" -- "%s";' % ( ion, compute ) )

    # print number of neighbors to check validity
#   for index,ion in enumerate(topo_data['ion_list']):
#       try: neighbor_count[ion]
#       except KeyError:
#           print( "%s (%d) had no neighbors???" % (ion, index) )
#       else:
#           print( "%s (%d) had %d neighbors" % ( ion, index, neighbor_count[ion] ) )

def calculate_hop_pair( node_list, topo_data ):
    ion1 = topo_data['compute2ion'][node_list[0]]
    ion2 = topo_data['compute2ion'][node_list[1]]
    hops = get_hops( topo_data['ion2torus'][ion1], topo_data['ion2torus'][ion2],
            topo_data['torus_size'] )
    print "%10s at ( %d, %d, %d )" % (node_list[0], 
        topo_data['ion2torus'][ion1][0],
        topo_data['ion2torus'][ion1][1],
        topo_data['ion2torus'][ion1][2])
    print "%10s at ( %d, %d, %d )" % (node_list[1], 
        topo_data['ion2torus'][ion2][0],
        topo_data['ion2torus'][ion2][1],
        topo_data['ion2torus'][ion2][2])
    print "%d hops" % hops

### calculate_hop_distribution: Given a list of nodes (gcn-XX-YY), calculate 
###   the hop distances between all possible node pairs and print some basic 
###   statistics
def calculate_hop_distribution(node_list, topo_data):
    node_pair_list = []
   
    # build a list of all non-redundant node pairs
    for i in range(len(node_list)-1):
        for j in range(i+1, len(node_list)):
            try:
                node_data = {
                    'pairs':    ( node_list[i], node_list[j] ),
                    'ions':     ( topo_data['compute2ion'][node_list[i]],
                                topo_data['compute2ion'][node_list[j]] )
                }
            except KeyError:
                sys.stderr.write('Invalid node pair: %s,%s\n' 
                    % ( node_list[i], node_list[j] ))
                sys.exit(1)

            node_data['pos'] =( topo_data['ion2torus'][node_data['ions'][0]],
                                topo_data['ion2torus'][node_data['ions'][1]] )

            node_pair_list.append( node_data )

    # calculate hop distance between each node pair
    hop_count = [0] * len(node_pair_list)
    for index, value in enumerate(node_pair_list):
        hops = get_hops( value['pos'][0], value['pos'][1], 
            topo_data['torus_size'] )
        hop_count[index] = hops

    val, idx = ( max(hop_count), hop_count.index(max(hop_count)) )
    n1, n2 = ( node_pair_list[idx]['pairs'][0], node_pair_list[idx]['pairs'][1] )
    print "Max hops: %d"  % ( val )

    histogram = [0] * (val + 1)

    for hop in hop_count:
        histogram[hop] += 1

    for index, value in enumerate(histogram):
        print "%2d hops: %d pairs" % ( index, histogram[index] )

    print "Sum:      %d pairs between %d nodes" \
        % ( sum(histogram), len(node_list) )

### get_gordon_topology: generate maps linking compute nodes to IO nodes and
###   IO nodes to positions in the torus interconnect
def get_gordon_topology(topo_params):
    node_torus_position = {}

    # unpack the input parameters
    ion_racks = topo_params['ion_racks']
    ion_per_rack = topo_params['ion_per_rack']
    compute_per_ion = topo_params['compute_per_ion']
    torus_size = topo_params['torus_size']
    compute_racks = topo_params['compute_racks']
    compute_per_rack = topo_params['compute_per_rack']
    compute_per_row = topo_params['compute_per_row']
    compute_per_subrack = topo_params['compute_per_subrack']
    num_nodes   = topo_params['total_computes']

    ion2compute = {}
    compute2ion = {}
    ion2torus   = {}
    ion_list    = []

    # begin constructing maps of compute nodes, IO nodes, and torus positions
    this_ions_computes = []
    for abs_node in range(0, num_nodes):

        if (abs_node % compute_per_ion == 0):
            abs_ion = int(abs_node / compute_per_ion)
            ion_x = int(abs_ion / torus_size[2]) % torus_size[0]
            ion_y = int(abs_ion / torus_size[2] / torus_size[0] )
            ion_z = abs_ion % torus_size[2]
            my_ion_rack = ion_racks[int(abs_ion/compute_per_ion)]
            my_ion_row = abs_ion % ion_per_rack + 1
            my_ion_string = "ion-%d-%d" % ( my_ion_rack, my_ion_row )
            ion_list.append(my_ion_string)

        my_rack = compute_racks[int(abs_node / compute_per_rack)]
        node_within_rack = abs_node % compute_per_rack
        my_row = int(node_within_rack / compute_per_row) + 1
        my_subrack = int(abs_node / compute_per_subrack)
        my_col = node_within_rack % 8  + 1
        my_slot = 10*my_row + my_col
        my_node_string = "gcn-%d-%d" % ( my_rack, my_slot )
        node_torus_position[my_node_string] = ( ion_x, ion_y, ion_z )

        this_ions_computes.append(my_node_string)
        compute2ion[my_node_string] = my_ion_string

        # finalize this ion and prepare for the next one
        if ((abs_node + 1) % compute_per_ion == 0):
            ion2compute[my_ion_string] = this_ions_computes
            ion2torus[my_ion_string] = ( ion_x, ion_y, ion_z )
            this_ions_computes = []

    # return a dictionary containing all of the calculated data
    return { 'ion2compute':  ion2compute,
             'compute2ion':  compute2ion,
             'ion2torus':    ion2torus,
             'ion_list':     ion_list,
             'torus_size':   torus_size }

### get_hops:  calculate hop distance between two tuples containing torus 
###   coordinates of arbitrary dimensionality
def get_hops(node1, node2, torus_size):
    hops = 0 
    for i in range(0, len(torus_size)):
        hops_in_dir = abs(node1[i] - node2[i])
        if hops_in_dir > (torus_size[i] / 2):
            hops_in_dir = torus_size[i] - hops_in_dir
        hops += hops_in_dir

    return hops

def print_help(argv):
        print r"""  Syntax:
    %20s                         Prints rack layout for system
    %20s gcn-XX-YY gcn-AA-BB ... Prints stats on hop distances 
                                                 between all pairs in given list
                                                 of nodes

   You can get hop distances for all nodes in a given job using something
   like this too (e.g., for job 12345):

    %20s $(qstat 12345 -f -x \
        | grep -o '<exec_host>.*</exec_host>' \
        | grep -Eo 'gcn-[^-]*-[^/]*' \
        | uniq)
""" % ( argv[0], argv[0], argv[0] )

if __name__ == "__main__":
    main(sys.argv)
