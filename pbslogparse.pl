#!/usr/bin/env perl
#
# pbslogparse.pl                       April 29, 2013 - Glenn K. Lockwood
#
# general-purpose PBS log parser.  turns logfile into hash structures for
# easy processing.
#
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;

my %options;
if ( @ARGV > 0 ) 
{
    GetOptions(
        "o=s@"    => \$options{fields}, 
    );
}

# if given -o, print out the given fields
my $job_list = load_job_list_from_logs();
if ( defined($options{fields}) )
{
    @{$options{fields}} = split(m/,/,join(',',@{$options{fields}}));
    print_fields();
}
# otherwise, print out something useful (like user expansion factors)
else
{
    expansion_factor_report();
}

################################################################################
# print fields
#
sub print_fields
{
    my (@job_lines, @max_field_length);
    my %filters;

    foreach my $i ( 0 .. $#{$options{fields}} )
    {
        my $field = $options{fields}->[$i];
        if ( $field =~ m/^([^=]+)=(.*)$/ )
        {
            $filters{$2} = $1;
            $options{fields}->[$i] = $2;
        }
    }

    # create an array with each job's fields.  don't print-as-we-go because we
    # need to know the max length of each printed field
    foreach my $job ( @$job_list )
    {
        my $found = 0;
        my @job_fields;
        foreach my $field (@{$options{fields}})
        {
            my $remaining = $field;
            my $hash = $job;
            my ($key, $path) = ($field, "job->");
            while ( $remaining =~ m/\./ )
            {
                ($key, $remaining) = split( m/\./, $remaining, 2 );
                $hash = $hash->{$key};
                $path .= "$key->";
            }
            $key = $remaining;
            $path .= $key;

            my $strout;
            if ( defined($hash->{$key}) )
            {
                if ( ref($hash->{$key}) eq 'ARRAY' )
                {
                    $strout = join(':', @{$hash->{$key}});
                }
                # can specify "-o ctime=end" to get a human-readable date
                # instead of the epoch
                elsif ( defined($filters{$field}) && $filters{$field} == "ctime" )
                {
                    $strout = scalar(localtime($hash->{$key}));
                }
                else
                {
                    $strout = $hash->{$key};
                }
            }

            push(@job_fields,$strout) if defined($strout);
        }
        foreach my $i ( 0 .. $#job_fields )
        {
            if ( length($job_fields[$i]) > $max_field_length[$i] )
            {
                $max_field_length[$i] = length($job_fields[$i]);
            }
        }
        push(@job_lines, \@job_fields);
    }

    # print out each job's line
    foreach my $job ( @job_lines )
    {
        foreach my $i ( 0 .. $#max_field_length )
        {
            my $fmt = sprintf("%%%ds ", $max_field_length[$i]);
            printf( $fmt, $job->[$i] );
        }
        print "\n";
    }
}

#
# calculate per-user expansion factors
#
sub expansion_factor_report
{
    my ($mean, $median, $usermean, $usermedian);
    foreach my $job ( @$job_list )
    {
        next if !defined($job->{exp_factor});
        next if $job->{resources_used}->{walltime} < 10;
    
        my $user = $job->{user};
        $mean->{sum} += $job->{exp_factor};
        $mean->{n}++;
        $mean->{walltime}->{sum} += $job->{resources_used}->{walltime};
        $mean->{walltime}->{n}++;
        push( @{$median->{list}}, $job->{exp_factor} );
    
        $usermean->{$user}->{sum} += $job->{exp_factor};
        $usermean->{$user}->{n}++;
        $usermean->{$user}->{walltime}->{sum} += 
            $job->{resources_used}->{walltime};
        $usermean->{$user}->{walltime}->{n}++;
    
        push( @{$usermedian->{$job->{user}}->{list}}, $job->{exp_factor} );
    #   printf "%.3f\n", $job->{exp_factor};
    }
    
    $mean->{mean} = $mean->{sum} / $mean->{n};
    $median->{median} = median($median->{list});
    
    my ( $usermeanmean, $usermeanmedian, $usermedianmean, $usermedianmedian);
    
    #
    #  calculate final per-user statistics
    #
    foreach my $user ( keys(%$usermean) )
    {
        $usermean->{$user}->{mean} = $usermean->{$user}->{sum} / 
            $usermean->{$user}->{n};
        $usermedian->{$user}->{median} = median($usermedian->{$user}->{list});
        $usermean->{$user}->{walltime}->{mean} = 
            $usermean->{$user}->{walltime}->{sum} / 
            $usermean->{$user}->{walltime}->{n};
    
        $usermeanmean->{sum} += $usermean->{$user}->{mean};
        $usermeanmean->{n}++;
    
        $usermedianmean->{sum} += $usermedian->{$user}->{median};
        $usermedianmean->{n}++;
    
        push(@{$usermeanmedian->{list}}, $usermean->{$user}->{mean});
        push(@{$usermedianmedian->{list}}, $usermedian->{$user}->{median});
    }
    $usermeanmean->{mean} = $usermeanmean->{sum} / $usermeanmean->{n};
    $usermedianmean->{mean} = $usermedianmean->{sum} / $usermedianmean->{n};
    $usermedianmedian->{median} = median($usermedianmedian->{list});
    $usermeanmedian->{median} = median($usermeanmedian->{list});
    
    #
    #  print final report
    #
    foreach my $user ( 
    #sort { $usermean->{$b}->{mean} <=> $usermean->{$a}->{mean} } 
    #   keys(%$usermean) 
    sort { $usermean->{$b}->{n} <=> $usermean->{$a}->{n} } keys(%$usermean) 
    )
    {
        printf( "%12s mean=%-10.3f median=%-10.3f njobs=%-6d meanwall=%-10s\n", $user, 
            $usermean->{$user}->{mean},
            $usermedian->{$user}->{median},
            $usermean->{$user}->{n},
            seconds_to_clock($usermean->{$user}->{walltime}->{mean})
            );
    }
    
    printf( "-- Mean --\n%12s %.3f\n%12s %.3f\n%12s %.3f\n\n",
        'Overall', $mean->{mean},
        'User Mean', $usermeanmean->{mean},
        'User Median', $usermedianmean->{mean} );
    printf( "-- Median --\n%12s %.3f\n%12s %.3f\n%12s %.3f\n\n",
        'Overall', $median->{median},
        'User Mean', $usermeanmedian->{median},
        'User Median', $usermedianmedian->{median} );
    return;
}

################################################################################
#
# variety of useful subroutines
#
################################################################################
#
# core subroutine to parse logfiles
#
sub load_job_list_from_logs
{
    my @job_list;
    while ( my $line = <> )
    {
        my %job;
        my ( $timestamp, $entry_type, $job_server );
        ( $timestamp, $line ) = split( m/;/, $line, 2 );
        ( $entry_type, $line ) = split( m/;/, $line, 2 );
        ( $job_server, $line ) = split( m/;/, $line, 2 );

        next unless $entry_type eq "E";     # only care about job ending

        $job{jobid} = $job_server;
        $job{jid} = (split( m/\./, $job_server ))[0];
        my @values = split( m/\s+/, $line );
        foreach ( @values )
        {
            my ($key, $val) = split( m/=/, $_, 2 );
            if ( $key =~ m/^([^.]+)\.([^.]+)$/ )
            {
                my ( $parent, $child ) = ( $1, $2 );
                $job{$parent}{$child} = $val;
            }
            else
            {
                $job{$key} = $val;
            }
        }

        $job{Resource_List}{neednodes} = 
            parse_nodelist($job{Resource_List}{neednodes});
        $job{exec_host} = parse_nodelist( $job{exec_host} );

        # convert 00:00:00 into number of seconds.  sometimes 
        # Resource_List.walltime is not defined (slipped through jobfilter?)
        $job{Resource_List}{walltime} = 
            clock_to_seconds( $job{Resource_List}{walltime} ) 
            if defined($job{Resource_List}{walltime});
        $job{resources_used}{walltime} = 
            clock_to_seconds( $job{resources_used}{walltime} );
        $job{resources_used}{cput} = 
            clock_to_seconds( $job{resources_used}{cput} );
        $job{exp_factor} = ($job{end} - $job{etime}) / 
                            $job{resources_used}->{walltime}
                            if $job{resources_used}->{walltime};

        push( @job_list, \%job );
#       printf( Dumper(\%job) );
    }
    return \@job_list;
}

#
# convert PBS "node1/01+node1/02+node2/01" into an array of node/core pairs
#
sub parse_nodelist
{
    my $input = shift;
    return( [ split( m/\+/, $input ) ] )
}

#
# convert 00:00:00 formatted strings into a number of seconds
#
sub clock_to_seconds
{
    my $clock = shift;
    if ( $clock =~ m/^(\d\d+):(\d\d):(\d\d)$/ )
    {
        return $1*3600 + $2*60 + $3;
    }
    else
    {
        return $clock;
    }
}
sub seconds_to_clock
{
    my $seconds = shift;
    my $hours   = int($seconds / 3600);
    my $minutes = int(($seconds % 3600) / 60);
    $seconds = $seconds % 60;
    return sprintf( "%02d:%02d:%02d", $hours, $minutes, $seconds );
}

#
# return the median value from an array
#
sub median
{
    my $unsorted = shift;
    my $list = [ sort {$a <=> $b} ( @$unsorted) ];
    my $nelements = scalar(@$list);

    if ( $nelements % 2 == 1 )
    {
        return $list->[int($nelements/2)];
    }
    else
    {
        return ($list->[int($nelements/2)] + $list->[int($nelements/2)-1])/2.0;
    }
}
