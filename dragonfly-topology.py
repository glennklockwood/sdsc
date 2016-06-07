#!/usr/bin/env python
#
#  A silly little tool to generate a dotfile depicting the connectivity of a
#  network with the dragonfly topology.
#

_TILES_PER_ROUTER  = 48 - 8 # 48 ports per router, but eight are used for NICs
_SLOTS_PER_CHASSIS = 16     # each slot always has one router
_CHASSIS_PER_GROUP = 6      # a group is two cabinets (three chassis each)
_GROUPS_PER_SYSTEM = 2      # Cori Phase I has five groups (ten cabinets)
_RANK1_LPC = 1              # links per connection
_RANK2_LPC = 3              # each rank2 connection has three links
_RANK3_LPC = 1              # rank3 depends on the total number of groups


def build_dragonfly():
    """
    Builds a three-rank dragonfly network and returns a list of tuples 
    describing the connectivity
    """
    connections = [] # ( end1, end2, rank )

    ### Initialize all Aries router port counts
    router_ports = []
    for group in range(_GROUPS_PER_SYSTEM):
        router_ports.append({})
        for chassis in range(_CHASSIS_PER_GROUP):
            for slot in range(_SLOTS_PER_CHASSIS):
                router_ports[-1][slotname(group,chassis,slot)] = 0

    ### Link together the rank-1 and rank-2 networks (intra-group) network
    for group in range(_GROUPS_PER_SYSTEM):
        chassis_in_group = range(_CHASSIS_PER_GROUP)
        ### Rank 1 (intra-chassis) network - every slot's router is connected
        ### to every other router within the chassis
        for chassis in chassis_in_group:
            for slot in range(_SLOTS_PER_CHASSIS)[:-1]:
                for otherslot in range(slot+1, _SLOTS_PER_CHASSIS):
                    end1 = slotname(group,chassis,slot)
                    end2 = slotname(group, chassis, otherslot)
                    for i in range(_RANK1_LPC):
                        connections.append( (end1, end2, 1) )
                    router_ports[group][end1] += _RANK1_LPC
                    router_ports[group][end2] += _RANK1_LPC
        ### Rank 2 (intra-group) network - every router is connected to a router
        ## in the same slot in every other chassis within the group
        for chassis in chassis_in_group[:-1]:
            for otherchassis in range(chassis+1, _CHASSIS_PER_GROUP):
                for slot in range(_SLOTS_PER_CHASSIS):
                    end1 = slotname(group,chassis,slot)
                    end2 = slotname(group, otherchassis, slot)
                    for i in range(_RANK2_LPC):
                        connections.append( (end1, end2, 2) )
                    router_ports[group][end1] += _RANK2_LPC
                    router_ports[group][end2] += _RANK2_LPC

    ### Rank 3 (inter-group) network - Every group connects to every other
    ### group.  These connections use up whatever ports remain available on the
    ### groups' routers.
    group_connectivity = {}
    finished = False
    while not finished:
        if _GROUPS_PER_SYSTEM < 2: ### no rank-3 network at all
            break
        for group in range(_GROUPS_PER_SYSTEM)[:-1]:
            if finished: break
            for othergroup in range(group+1,_GROUPS_PER_SYSTEM):
                ### Find a router with a free port.  Use min() to balance the
                ### connectivity of each router within each group.
                end1 = min(router_ports[group],      key=router_ports[group].get)
                end2 = min(router_ports[othergroup], key=router_ports[othergroup].get)

                ### If any router runs out of ports, we can't expand the Rank 3
                ### network any further
                if ( router_ports[group][end1]      >= _TILES_PER_ROUTER 
                or   router_ports[othergroup][end2] >= _TILES_PER_ROUTER ):
                    finished = True
                    break

                router_ports[group][end1] += _RANK3_LPC
                router_ports[othergroup][end2] += _RANK3_LPC
                if end1 < end2:
                    group_pair_key = "%s=%s" % ( end1, end2 )
                else:
                    group_pair_key = "%s=%s" % ( end2, end1 )

                group_connectivity[group_pair_key] = group_connectivity.get(group_pair_key, 0) + 1

                for i in range(_RANK3_LPC):
                    connections.append( (end1, end2, 3) )

    return connections

def slotname( group, chassis, slot ):
    return "%d-%d-%d" % ( group, chassis, slot )


def print_router_population():
    for group_pairs, links in group_connectivity.iteritems():
        end1, end2 = group_pairs.split('=')
        group1 = int(end1.split('-',1)[0])
        group2 = int(end2.split('-',1)[0])
        print "%20s %d from %d and %d" % ( 
            group_pairs, 
            links,
            router_ports[group1][end1],
            router_ports[group2][end2]
        )
        
def print_dotfile( connections ):
    print """graph dragonfly {
    overlap=false;
    splines=true;
    node [label="",width=0.05,height=0.05,style=filled,color=red];
    subgraph rank1 {
        edge [color=green];"""
    for connection in connections:
        if connection[2] == 1:
            print '        "%s" -- "%s";' % ( connection[0], connection[1] )
    print """    }
    subgraph rank2 {
        edge [color=black];"""
    for connection in connections:
        if connection[2] == 2:
            print '        "%s" -- "%s";' % ( connection[0], connection[1] )
    print """    }
    subgraph rank3 {
        edge [color=blue];"""
    for connection in connections:
        if connection[2] == 3:
            print '        "%s" -- "%s";' % ( connection[0], connection[1] )
    print "    }"
    print "}"

if __name__ == '__main__':
    print_dotfile( build_dragonfly() )
