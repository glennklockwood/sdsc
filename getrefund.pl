#!/usr/bin/env perl
#
#  generate a refund report for given jobids
#
#  looks for a file in $HOME/.xdcdbconf that contains AT LEAST
#    dbname=postgresdbname
#    host=somedbserver.xsede.org
#    port=12345
#    user=mydbusername
#    password=mydbpassword
#    xdhome=someusername
#    mappath=path/to/mapfile
#
use strict;
use warnings;
use DBI;
use Data::Dumper;

my @jobids;
foreach my $jobid ( @ARGV )
{
    die "Invalid jobid: $jobid" unless $jobid =~ m/^\s*(\d+)/;
    push(@jobids, $jobid);
}
die "Must specify at least one jobid" unless scalar(@jobids) > 0;

### Read in XDCDB credentials
our $config;
open CONF, "<" . $ENV{'HOME'} . "/.xdcdbconf" or die;
while ( my $line = <CONF> )
{
    next if $line =~ m/^#/;
    next unless $line =~ m/^\s*(.*?)\s*=\s*(.*)\s*$/;
    $config->{$1} = $2;
}
close CONF;

### Set system-specific information if not provided
use Sys::Hostname;
my $host = hostname();
if ( ! $config->{'system'} ) {
    if ( $host =~ m/^trestles-/ )
    {
        $config->{'system'} = 'trestles';
        $config->{pbs_suffix} = '.trestles-fe1.local';
        $config->{res_id} = 2792;
    }
    elsif ( $host =~ m/^(gordon|gcn)-/ )
    {
        $config->{'system'} = 'gordon';
        $config->{pbs_suffix} = '.gordon-fe2.local';
        $config->{res_id} = 2796;
    }
}
die "Unknown system" if !$config->{'system'};
die "Unknown system res_id" if !$config->{'res_id'};
die "Unknown system pbs_suffix" if !$config->{'pbs_suffix'};

### Find mapfile to convert TG accounts to local accounts
if ( !$config->{mapfile} ) 
{
    $config->{mapfile} = sprintf("/home/%s/%s/%s",
        $config->{xdhome},
        $config->{'system'},
        $config->{mappath});
}
die "Cannot find mapfile at " . $config->{mapfile} if ! -e $config->{mapfile};

### Connect to XDCDB
my $dbh;
my $connector = sprintf( "dbi:Pg:dbname=%s;host=%s;port=%d;sslmode=require",
    $config->{dbname},
    $config->{host},
    $config->{port} );

$dbh = DBI->connect( $connector, 
                     $config->{user}, 
                     $config->{password},
                     {RaiseError => 1, PrintError => 0} ) or die;

### Build query to find job info
my ($query, $row, @rows);
eval {
    my $sql = sprintf("
SELECT
    jobs.username,
    accounts.charge_number,
    jobs.local_charge,
    resources.resource_name,
    jobs.local_jobid
FROM
    acct.jobs
    inner join acct.accounts on jobs.account_id = accounts.account_id
    inner join acct.resources on jobs.resource_id = resources.resource_id
WHERE
    jobs.resource_id = %d
AND ", $config->{res_id} );
    if ( scalar(@ARGV) > 1 ) {
        $sql .= "( ";
        $sql .= sprintf( "jobs.local_jobid = '%d%s' OR ",
            $_, $config->{pbs_suffix} ) foreach @ARGV;
        $sql =~ s/OR\s*$/\)/;
    }
    else {
        $sql .= sprintf( "jobs.local_jobid = '%d%s'",
            $ARGV[0],
            $config->{pbs_suffix} );
    }

#   print("Running query:\n$sql\n");

    $query = $dbh->prepare($sql);
    $query->execute();
}; 

if ( $@ ) 
{
    warn "Error detected during query; doing a clean disconnect before dying";
    $query->finish();
    $dbh->disconnect();
    die $@;
}

### Read in all results
while ( my $record = $query->fetchrow_hashref() )
{
    push(@rows, $record);
}
$query->finish();
$dbh->disconnect();

### Loop through results and output a refund form for each one
my $running;
foreach my $record ( @rows )
{
    ### Retrieve local/TG account info
    die "Bungled db return line" if !$record->{charge_number};
    my ($acct_local, $acct_xd) = get_map( $record->{charge_number} );
    my $jid;

    ### if user/acct is the same for all, keep a running total of refunds
    if ( !$running ) {
        $running->{user} = $record->{username};
        $running->{acct_local} = $acct_local;
        $running->{acct_xd} = $acct_xd;
    }
    elsif ( $running->{user} ne $record->{username} 
    ||      $running->{acct_local} ne $running->{acct_local} )
    {
        $running->{bad} = 1;
    }
    $running->{local_charge} += $record->{local_charge};
    $jid = (split(m/\./, $record->{local_jobid}))[0];
    push (@{$running->{jobids}}, $jid);

    printf( "user=%s\naccount=%s/%s\namount=%d\nsystem=%s\nreason=Job %d\n\n",
        $record->{username},
        $acct_local, $acct_xd,
        $record->{local_charge},
        $config->{'system'},
        $jid );
}

### Print summary if multiple jobs specified and they all belong to one person
if ( scalar(@rows) > 1 && !$running->{bad} )
{
    print("===== Summary =====\n");
    printf( "user=%s\naccount=%s/%s\namount=%d\nsystem=%s\nreason=",
        $running->{user},
        $running->{acct_local},
        $running->{acct_xd},
        $running->{local_charge},
        $config->{'system'} );
    printf( "Jobs %s", join( ", ", @{$running->{jobids}}) );
    print "\n";
}

### Function to associate a local account with a TG- project number
sub get_map {
    my $account = shift;
    open MAPFILE, "<".$config->{mapfile}  or return;
    while ( my $line = <MAPFILE> )
    {
        next unless $line =~ m/^(\S+)\s+(\S+)/;
        $line =~ s/(^\s*|\s*$)//;
        my ($tgname, $localname) = split( m/\s+/, $line );
        if ( $account =~ m/^$tgname$/i
        ||   $account =~ m/^$localname$/i )
        {
            close MAPFILE;
            return( lc($localname), $tgname );
        }
    }
    close MAPFILE;
    return;
}
