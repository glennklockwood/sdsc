#!/usr/bin/env python
#
#  A silly little tool to generate a dotfile depicting the connectivity of a
#  network with the dragonfly topology.
#

_TILES_PER_ROUTER = 48 - 8 # 48 ports per router, but eight are used for NICs
_SLOTS_PER_CHASSIS = 16
_CHASSIS_PER_GROUP = 6
_GROUPS_PER_SYSTEM = 5 # Cori Phase I has five groups (ten cabinets)
_RANK1_LPC = 1 # links per connection
_RANK2_LPC = 3 # each rank2 connection has three links
_RANK3_LPC = 1 # rank3 network LPC depends on the total number of groups

print """
graph dragonfly {
overlap=false;
splines=true;
node [label="",width=0.05,height=0.05,style=filled,color=red];
"""
def slotname( group, chassis, slot ):
    return "%d-%d-%d" % ( group, chassis, slot )


### Initialize all aries router port counts
aries_ports = []
for group in range(_GROUPS_PER_SYSTEM):
    aries_ports.append({})
    for chassis in range(_CHASSIS_PER_GROUP):
        for slot in range(_SLOTS_PER_CHASSIS):
            aries_ports[-1][slotname(group,chassis,slot)] = 0

### link together the rank-1 and rank-2 networks
for group in range(_GROUPS_PER_SYSTEM):
    chassis_in_group = range(_CHASSIS_PER_GROUP)
    ### the rank 2 (intra-group) network - every slot is connected to the same
    ### slot in every other chassis
    for chassis in chassis_in_group[:-1]:
        for otherchassis in range(chassis+1, _CHASSIS_PER_GROUP):
            for slot in range(_SLOTS_PER_CHASSIS):
                end1 = slotname(group,chassis,slot)
                end2 = slotname(group, otherchassis, slot)
                print '"%s" -- "%s";' % ( end1, end2 )
                aries_ports[group][end1] += _RANK2_LPC
                aries_ports[group][end2] += _RANK2_LPC
    ### the rank 1 (intra-chassis) network - every slot is connected to every
    ### other slot
    for chassis in chassis_in_group:
        for slot in range(_SLOTS_PER_CHASSIS)[:-1]:
            for otherslot in range(slot+1, _SLOTS_PER_CHASSIS):
                end1 = slotname(group,chassis,slot)
                end2 = slotname(group, chassis, otherslot)
                print '"%s" -- "%s";' % ( end1, end2 )
                aries_ports[group][end1] += _RANK1_LPC
                aries_ports[group][end2] += _RANK1_LPC

### the rank 3 (inter-group) network - all-to-all and uses up whatever ports
### remain available on the routers
print "\n// Rank 3 network"
group_connectivity = {}
finished = False
while not finished:
    for group in range(_GROUPS_PER_SYSTEM)[:-1]:
        if finished: break
        for othergroup in range(group+1,_GROUPS_PER_SYSTEM):
            ### find a router with a free port
            end1 = min(aries_ports[group],      key=aries_ports[group].get)
            end2 = min(aries_ports[othergroup], key=aries_ports[othergroup].get)

            if ( aries_ports[group][end1]      >= _TILES_PER_ROUTER 
            or   aries_ports[othergroup][end2] >= _TILES_PER_ROUTER ):
                finished = True
                break

            aries_ports[group][end1] += _RANK3_LPC
            aries_ports[othergroup][end2] += _RANK3_LPC
            if end1 < end2:
                group_pair_key = "%s=%s" % ( end1, end2 )
            else:
                group_pair_key = "%s=%s" % ( end2, end1 )

            if group_pair_key not in group_connectivity:
                group_connectivity[group_pair_key] = 0
            group_connectivity[group_pair_key] += 1

            print '"%s" -- "%s";' % ( end1, end2 )

#for group_pairs, links in group_connectivity.iteritems():
#    end1, end2 = group_pairs.split('=')
#    group1 = int(end1.split('-',1)[0])
#    group2 = int(end2.split('-',1)[0])
#    print "%20s %d from %d and %d" % ( 
#        group_pairs, 
#        links,
#        aries_ports[group1][end1],
#        aries_ports[group2][end2]
#        )
        
print "}"
