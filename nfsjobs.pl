#!/usr/bin/env perl
#
# nfsjobs  15-March-2013 gkl
#

use strict;
use warnings;
BEGIN {
  use lib '/home/glock/perl/lib/perl5/site_perl/5.8.8';
  unshift @INC, '/home/glock/perl/lib/perl5/site_perl';
}

use XML::Simple;

die unless $ARGV[0];
my $nfs_ip = $ARGV[0];
my @users;

open ( AUTOFS, "</etc/auto.home" ) or die "Supply a nfs host ip";
while ( my $line = <AUTOFS> )
{
    next unless $line =~ m{(\d+\.\d+\.\d+\.\d+):/export/home\d*/([^/]*)$};
    my ($nfs_host, $user) = ($1, $2);
    if ($1 eq $nfs_ip) {
        push( @users, $2 );
    }
}
close(AUTOFS);
printf( "Got %d users on %s\n", scalar(@users), $nfs_ip );

my $xml_in = `qstat -fx`;

my $xml = new XML::Simple;
my $job_list = $xml->XMLin($xml_in)->{Job};

foreach ( @$job_list )
{
    next unless defined($_->{Output_Path});
    next unless $_->{job_state} eq "R";
    my $path = $_->{Output_Path};
    $path =~ s/^[^:]*://;
#   next if $path =~ m{^/oasis};
    next unless $path =~ m{^/home};

    printf( "User %12s running job %d out of %s\n",
        (split(m/@/, $_->{Job_Owner}))[0], 
        (split(m/\./, $_->{Job_Id}))[0], 
        $path );
}
