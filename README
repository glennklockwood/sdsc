===============================================================================
This repository contains various tools I've made to assist me with my work at 
the San Diego Supercomputer Center.  They are all mostly independent scripts
that function on their own.

Here are brief descriptions of the more useful tools:

For users:
* nodeview - parses pbsnodes and qstat and presents an overview of the state
  of the cluster.  Lots of options to refine the output to a subset of nodes,
  view a cluster-wide summary, and more.
* getfreesocket - returns a list of CPU sockets on the Linux system that aren't
  occupied by a process or thread using a lot of CPU.  Designed to provide
  input for an application like numactl to bind jobs to a single socket on a
  shared compute node
* gordon-topology.py - calculate the layout of compute and IO nodes across the
  racks of SDSC Gordon, and calculate the torus connectivity of all nodes.
  Optionally return hop distance between two nodes, or distribution of hop 
  distances for a list of given nodes

For administrators:
* nfsjobs.pl - scans the queue and finds all jobs running out of a directory
  mounted via the specified NFS server.  Good for quickly finding out who might
  be hammering NFS.
* pbslogparse.pl - a generic log parser for PBS/Torque logs.  Turns the end-
  of-job lines into hashes, then prints formatted output of your choosing
  (e.g., pbslogparse.pl 20130414 -o jobid,user,end,ctime=end).  In addition to
  the verbatim fields listed in Torque logs, you can request 'exp_factor' for
  the job's user expansion factor and 'jid' for the job id's number (sans
  frontend host part)
Parsers for PBS Torque's tracejob command:
* torque/splunk_from_trace - a simple script that takes the output of PBS/Torque's
  tracejob command and generates a Splunk query that returns the logs from
  all nodes participating in the job for the duration the job was being
  tracked by the resource manager
* torque/momlogs_from_trace - pulls momlogs from compute nodes that participated
  in a given tracejob's output
* torque/same_nodes_from_trace - loops through *.trace or a given list of 
  tracejob outputs and returns nodes that participated in all traces (used to
  find faulty nodes that break a large number of jobs)
