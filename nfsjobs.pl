#!/usr/bin/env perl
#
# nfsjobs  15-March-2013 gkl
#

use strict;
use warnings;
use File::Basename;
BEGIN {
  use lib '/home/glock/perl/lib/perl5/site_perl/5.8.8';
  unshift @INC, '/home/glock/perl/lib/perl5/site_perl';
}

use XML::Simple;
use Cwd 'abs_path';

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

my @offenders;
foreach my $job ( @$job_list )
{
    next unless defined($job->{Output_Path});
    next unless $job->{job_state} eq "R";
    my $path = $job->{Output_Path};
    $path =~ s/^[^:]*://;
#   next if $path =~ m{^/oasis};
    next unless $path =~ m{^/home};

    # dereference symlinks in paths if possible.  most user home dirs aren't 
    # world-readable, so most paths cannot be dereferenced properly without
    # running this as root
    my $abs_path = abs_path($path); 

    my $owner = (split('@', $job->{Job_Owner}))[0];
    next unless grep(m/^$owner$/, @users);

    if ( $job->{Resource_List}->{nodes} =~ m/^(\d+):ppn=(\d+)/ )
    {
        $job->{ct_nodes} = $1;
        $job->{ct_ppn} = $2;
        $job->{ct_ranks} = $1 * $2;
    }
    $job->{path} = $path;
    $job->{abs_path} = $abs_path;

    push(@offenders, $job);
}

# print jobs sorted by severity
printf( "%12s   %7s   %5s   %s\n", 'user', 'jobid', '#ranks', '$PBS_O_WORKDIR' );
foreach my $job ( sort { $a->{ct_ranks} <=> $b->{ct_ranks} } @offenders )
{
    printf( "%12s   %7d   %5d   %s\n",
        (split(m/@/, $job->{Job_Owner}))[0], 
        (split(m/\./, $job->{Job_Id}))[0], 
        $job->{ct_ranks},
        ( $job->{abs_path} ? dirname($job->{abs_path}) : dirname($job->{path}) ) );
}
