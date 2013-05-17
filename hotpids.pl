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
my $min_time = 600;

my @process_list;
for my $line ( `/bin/ps -e -o pid= -o user= -o pcpu= -o rss= -o vsz= -o etime= -o time= -o cmd=` )
{
    $line =~ s/(^\s+|\s+$)//;
    my @field = split( m/\s+/, $line );

    my %hash;
    my $argument = $line;
    for my $key ( qw/ pid user pcpu rss vsz etime time/ )
    {
        my $word;
        ( $word, $argument ) = one_arg( $argument );
        $hash{$key} = $word;
    }
    
    $hash{etime} = stamp_to_secs($hash{etime});
    $hash{'time'}  = stamp_to_secs($hash{'time'});
    $hash{cmd}   = $argument;
    push( @process_list, \%hash );
}

my @print_processes;
my %user_load;
#
#   first pass - look for individual processes AND add up overall user load
#
foreach my $p ( @process_list )
{
    next if grep {$_ eq $p->{user}} @exempt_users;

    $user_load{$p->{user}} += $p->{pcpu};

    if ( $p->{pcpu} > $min_pcpu && $p->{etime} > $min_time )
    { 
        push( @print_processes, $p );
    }
}

#
#  second pass - print all processes from heavily loaded users regardless fo
#     runtime
#
my $buffer = "";
my $hot_users = 0;
foreach my $user ( keys(%user_load) )
{
    my $warning = 0;
    foreach my $p ( @process_list )
    {
        next unless $p->{user} eq $user;

        if ( $user_load{$user} > 100.0 
        &&   $p->{pcpu} > $min_pcpu/10
        &&   !grep { $_ == $p } @print_processes )
        {
            push(@print_processes, $p);
            $warning++;
        }
    }
    if ( $warning )
    {
        $buffer .= sprintf( "\t%s\t%.1f%%\n", $user, $user_load{$user});
        $hot_users++;
    }
}

#
#  print offending processes
#
if ( scalar(@print_processes) > 0 )
{
    if ( $hot_users ) {
        printf( "Hot users on %s:\n", hostname() );
        print $buffer;
    }
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
    elsif ( $stamp =~ m/(\d+):(\d+)/ )
    {
        ( $days, $hours, $minutes, $seconds ) = ( 0, 0, $1, $2 );
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
    my $fmt = "%5d\t%s\t%.1f%%\t%.1f hr\t%.45s\n";

    printf( $fmt,
        $p->{pid},
        $p->{user},
        $p->{pcpu},
        $p->{etime}/3600.0,
        $p->{cmd} );
}

sub one_arg
{
    my $string = shift;
    if ( $string =~ m/^\s*(\S+)\s*(.*)$/ )
    {
        return ( $1, $2 );
    }
}
