#!/usr/bin/env python
import fileinput
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import re

ppn = 16

def hinton(matrix, rack, ax, cpugrid):
    # how wide/tall do our nodes appear in the plot?
    size_x = 0.50
    size_y = 1.00

    # coordinates in rack space
    rack_x = float(rack%10)
    rack_y = float(int(rack / 10))

    # coordinates in node space
    node_x = float(rack_x * (10*size_x))
    node_y = float(rack_y * (10*size_y))

    # add text label for this rack
    #plt.text(node_x, node_y+size_y*9, "rack%d" % rack)
    plt.text(node_x, node_y-0.1, "rack %d" % rack)

    supernodes = list()

    for (y,x),w in np.ndenumerate(matrix):

        if w < -1.5:
            color = 'grey'
        elif w < -0.5:
            color = 'red'
        elif w > (1.1 * float(ppn)):
            color = 'yellow'
        else:
            color = cm((0.50 + w/float(cpugrid[y,x]))/1.25)

        # coordinates on the actual plot
        plot_x = x*size_x + node_x
        plot_y = y*size_y + node_y

        # if this is the last node in a vsmp supernode, go back and
        # draw the supernode
        if cpugrid[y, x] > ppn:
            my_size_x = size_x * 8
            my_size_y = size_y * 2
        else:
            my_size_x = size_x
            my_size_y = size_y
        
        rect = plt.Rectangle([plot_x, plot_y], 
            my_size_x, 
            my_size_y,
            facecolor=color,
            edgecolor='black')

        if cpugrid[y, x] > ppn:
            supernodes.append(rect)
        else:
            ax.add_patch(rect)

    # draw supernodes last so they are on top of the compute nodes
    for rect in supernodes:
        ax.add_patch(rect)

if __name__ == '__main__':
    ### initialize the plot
    ax = plt.gca()
#   ax.patch.set_facecolor('white')
    ax.patch.set_facecolor((1,1,1,0.0))
    ax.axis('off')
    
    ax.set_aspect('equal', 'box')
    ax.xaxis.set_major_locator(plt.NullLocator())
    ax.yaxis.set_major_locator(plt.NullLocator())
    cm = plt.get_cmap('Blues')

    linerex = re.compile(r"""
        ^(\S+)-(\d+)-(\d+)\s+
        \d+\s+
        \d+\s+
        (\d+)\s+
        \d+/\d+\s+
        \S+\s+
        \S+\s+
        (\d+\.\d+)\s*
        (\S+)\s*$""", re.VERBOSE)
    staterex = re.compile("(offline|down)")

    cpugrid = np.empty([8,8])
    cpugrid[:] = ppn
    loadgrid = np.empty([8,8])
    loadgrid[:] = -2.0
    thisrack = -1
    ax = plt.gca()

    for line in fileinput.input():
        match = linerex.match(line)
        if not match:
            continue
        nodename = match.group(1)
        rack = int(match.group(2))
        slot = int(match.group(3))
        cpus = int(match.group(4))
        load = float(match.group(5))

        if rack != thisrack:
            if thisrack >= 0:
                hinton( loadgrid, thisrack, ax, cpugrid )

            loadgrid[:] = -2.0
            cpugrid[:] = ppn
            thisrack = rack

        if staterex.match(match.group(6)):
            load = -1.00

        y = slot % 10 - 1       # column
        x = int(slot/10) - 1    # row

        loadgrid[x, y] = load
        cpugrid[x, y] = cpus

    ax.autoscale_view()
    ax.invert_yaxis()
#   plt.show()
    plt.savefig('gordon-load.png', bbox_inches='tight')
