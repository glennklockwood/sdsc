#!/usr/bin/env python
import fileinput
import numpy as np
import matplotlib.pyplot as plt
import re

def hinton(matrix, rack, ax, vsmp ):

    max_load = 16.0

    for (x,y),w in np.ndenumerate(matrix):
        if w < -1.5:
            color = 'white'
        elif w < -0.5:
            color = 'red'
        elif w > (1.1 * max_load):
            color = 'yellow'
        else:
            color = cm(w/max_load)

        size_x = 0.50
        size_y = 1.00

        # base rack coordinates
        xpos = float(rack%10)
        ypos = float(int(rack / 10))

        # node coordinates
        xoffset = float(xpos * (9*size_x))
        yoffset = float(ypos * (9*size_y))

        # add text label
        plt.text(xoffset,yoffset, "rack%d" % rack)
        print rack, xpos, ypos, xoffset, yoffset

        rect = plt.Rectangle([x*size_x + xoffset, y*size_y + yoffset], 
            size_x, 
            size_y,
            facecolor=color,
            edgecolor='black')

        ax.add_patch(rect)

if __name__ == '__main__':
    ### initialize the plot
    ax = plt.gca()
    ax.patch.set_facecolor('white')
    ax.set_aspect('equal', 'box')
    ax.xaxis.set_major_locator(plt.NullLocator())
    ax.yaxis.set_major_locator(plt.NullLocator())
    cm = plt.get_cmap('Blues')

    linerex = re.compile(r"""
        ^(\S+)-(\d+)-(\d+)\s+
        \d+\s+
        \d+\s+
        \d+\s+
        \d+/\d+\s+
        \S+\s+
        \S+\s+
        (\d+\.\d+)\s*
        (\S+)\s*$""", re.VERBOSE)
    staterex = re.compile("(offline|down)")

    rackload = np.empty([8,8])
    rackload[:] = -2.0
    thisrack = -1
    ax = plt.gca()

    for line in fileinput.input():
        match = linerex.match(line)
        if not match:
            continue
        nodename = match.group(1)
        rack = int(match.group(2))
        slot = int(match.group(3))
        load = float(match.group(4))

        if rack != thisrack:
            if thisrack >= 0:
                #print rackload

                hinton( rackload, thisrack, ax, 0 )

            rackload[:] = -2.0
            thisrack = rack

        if staterex.match(match.group(5)):
            load = -1.00

        x = slot % 10 - 1
        y = int(slot/10) - 1
        rackload[x, y] = load
        #print x,y,load

    ax.autoscale_view()
    ax.invert_yaxis()
    plt.show()

