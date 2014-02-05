#!/usr/bin/env perl
################################################################################
#  tally-outage.pl: go through a bunch of readdb from nodeviews and tally up 
#    "something."  In this incarnation it calculates an average rate of each 
#    node being down/offline.  This simple script can be fed into vis-load.py.
#
#  Glenn K. Lockwood, San Diego Supercomputer Center            February 2014
################################################################################

my (%tot, %offline);

foreach my $dbfile ( @ARGV ) {
    my $mynod;
    foreach my $line ( `nodeview --nocolor --readdb=$dbfile` ) {
        if ( $line =~ m/^\s*((gcn|trestles)-\d+-\d+)/ ) {
            my $node = $1;
            if ( $line =~ m/(down|offline)/ ) { 
                $offline{$node}++;
            }
            $tot{$node}++
        }
    }
}

foreach my $node ( keys(%tot) )
{
    printf( "%s %.10f\n", $node, $offline{$node}/$tot{$node} );
}
