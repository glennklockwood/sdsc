#!/usr/bin/env perl
#
#  hotpids.pl                May 2013, Glenn K. Lockwood
#

use strict;
use warnings;
use Sys::Hostname;

# users who can run hot pids on the login nodes
my @exempt_users = qw/root catalina/;
# threshold for reporting a hot pid
my $min_pcpu = 10.0;

my @process_list;
for my $line ( `/bin/ps -e -o pid= -o user= -o pcpu= -o rss= -o vsz= -o etime= -o time= -o cmd=` )
{
    $line =~ s/(^\s+|\s+$)//;
    my @field = split( m/\s+/, $line );
    push( @process_list, {
        'pid'   => $field[0],
        'user'  => $field[1],
        'pcpu'  => $field[2],
        'rss'   => $field[3],
        'vsz'   => $field[4],
        'etime' => stamp_to_secs($field[5]),
        'time'  => stamp_to_secs($field[6]),
        'cmd'   => ($field[8] ? join(' ', @field[7,-1]) : $field[7]) });

}

my @print_processes;
foreach my $p ( @process_list )
{
    if ( $p->{pcpu} > $min_pcpu
    && !grep {$_ eq $p->{user}} @exempt_users ) 
    { 
        push( @print_processes, $p );
    }
}

if ( scalar(@print_processes) > 0 )
{
    printf( "Hot processes on %s:\n", hostname() );
    print_pid($_) foreach @print_processes;
}

#
#  convert a [dd-]hh:mm:ss timestamp from /bin/ps into seconds
#
sub stamp_to_secs
{
    my $stamp = shift;
    my ( $days, $hours, $minutes, $seconds );
    if ( $stamp =~ m/(\d+)-(\d+):(\d+):(\d+)/ )
    {
        ( $days, $hours, $minutes, $seconds ) = ( $1, $2, $3, $4 );
    }
    elsif ( $stamp =~ m/(\d+):(\d+):(\d+)/ )
    {
        ( $days, $hours, $minutes, $seconds ) = ( 0, $1, $2, $3 );
    }
    else
    {
        return -1;
    }
    $seconds += $minutes*60 + $hours*3600 + $days*86400;
    return $seconds;
}

#
#  format and print a process
#
sub print_pid
{
    my $p = shift;
    my $fmt = "%5d\t%s\t%.1f%%\t%.1f hr\t%s\n";

    printf( $fmt,
        $p->{pid},
        $p->{user},
        $p->{pcpu},
        $p->{etime}/3600.0,
        $p->{cmd} );
}
