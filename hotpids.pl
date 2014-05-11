#!/usr/bin/env perl
#
#  hotpids.pl                May 2013, Glenn K. Lockwood
#
#  Report on user processes that have been consuming resources on a shared 
#  resource.  Intended to catch users running jobs on login nodes
#
use strict;
use warnings;
use Sys::Hostname;

### Configuration parameters ###################################################
# @exempt_users can run hot/fat pids on the login nodes
my @exempt_users = qw/root catalina kenneth/;
# $min_xxx is the threshold for per-process consumption, below which processes
#   are not reported.  processes running for less than $min_time are never
#   reported
my $min_pcpu = 10.0;
my $min_rss = 2 * 1024 * 1024;
# $max_xxx is the threshold for user-total consumption, above which processes
#   are reported even if they have been running for less than $min_time
my $max_pcpu = 100.0;
my $max_rss = 2 * 1024 * 1024;
my $min_time = 600;
# fields to retrieve from ps.  "cmd" is automatically appended to the end
my @fields = qw/ pid user pcpu rss vsz etime time /;
################################################################################

#
# Collect process data
#
my $ps_cmd = "/bin/ps -e";
   $ps_cmd .= " -o $_=" foreach ( @fields );
   $ps_cmd .= ' -o cmd=';
my @process_list;
for my $line ( `$ps_cmd` )
{
    $line =~ s/(^\s+|\s+$)//;
    my @field = split( m/\s+/, $line );

    my %hash;
    my $argument = $line;
    for my $key ( @fields )
    {
        my $word;
        ( $word, $argument ) = one_arg( $argument );
        $hash{$key} = $word;
    }
    
    $hash{etime} = stamp_to_secs($hash{etime});
    $hash{'time'}= stamp_to_secs($hash{'time'});
    $hash{cmd}   = $argument;
    $hash{host}  = (split(m/\./,hostname()))[0];
    push( @process_list, \%hash );
}

my @print_processes;
my (%user_load, %user_mem);
#
#   first pass - look for individual processes AND add up overall user load
#
foreach my $p ( @process_list )
{
    next if grep {$_ eq $p->{user}} @exempt_users;

    $user_load{$p->{user}} += $p->{pcpu};
    $user_mem{$p->{user}} += $p->{rss};

    if ($p->{pcpu} > $min_pcpu && $p->{etime} > $min_time)
    {
        $p->{type} = "hot pid";
    }
    elsif ($p->{rss} > $min_rss && $p->{etime} > $min_time)
    {
        $p->{type} = "fat pid";
    }
    push(@print_processes, $p) if $p->{type};
}

#
#  second pass - print all processes from heavily loaded users regardless of
#     runtime
#
foreach my $user ( keys(%user_load) )
{
    my ($hot_warning, $fat_warning) = (0, 0);
    foreach my $p ( @process_list )
    {
        next unless $p->{user} eq $user;

        # check cpu load
        if ( $user_load{$user} > $max_pcpu
        &&   $p->{pcpu} > $min_pcpu/10
        &&   !grep { $_ == $p } @print_processes )
        {
            $p->{type} = "hot tot";
            push(@print_processes, $p);
            $hot_warning++;
        }
        # check high memory use
        elsif ( $user_mem{$user} > $max_rss
        &&      $p->{rss} > $min_rss/10
        &&      !grep { $_ == $p } @print_processes )
        {
            $p->{type} = "fat tot";
            push(@print_processes, $p);
            $fat_warning++;
        }
    }
}

#
#  print offending processes
#
my $mail_msg = "";
if ( scalar(@print_processes) > 0 )
{
#   print_pid(0, 'header');    # print header
    print print_pid($_, 'tabs') foreach @print_processes;
#   $mail_msg .= print_pid($_, 'html') foreach @print_processes;
}

#
#  send report email
#
#{
#    use MIME::Lite;
#    my $mail = MIME::Lite->new (
#        Subject =>  "Hot processes",
#        From    =>  'glockwood@sdsc.edu',
#        To      =>  'glock@sdsc.edu',
#        Type    =>  'text/html',
#        Data    =>  $mail_msg
#    );
#    $mail->send();
#}

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
    my $type = shift;
    my $fmt   = "%-15s\t%7s\t%5d\t%s\t%.1f%%\t%.1f GB\t%.1f hr\t%s\n";
    my $h_fmt = "%-15s\t%7s\t%5s\t%s\t%s\t%s\t%s\t%s\n";

    if ( $type eq "header" )
    {
        return sprintf( $h_fmt,
            'host',
            'type',
            'pid',
            'user',
            'pcpu',
            'rss',
            'etime',
            'cmd' );
    }

    if ( $type eq "html" )
    {
        $fmt =~ s#\t#</td><td>#g;
        $fmt = "<tr><td>" . $fmt . "</td></tr>";
    }
    return sprintf( $fmt,
        $p->{host},
        $p->{type},
        $p->{pid},
        $p->{user},
        $p->{pcpu},
        $p->{rss}/1024/1024,
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
