#!/usr/bin/perl
use strict;
use warnings;

use Net::DNS::Resolver ();
use Time::HiRes qw(time);

use DBI;
use Data::Dumper;
use lib 'lib';
use Monitor qw(read_config dbh);

my $resolv = Net::DNS::Resolver->new();
$resolv->tcp_timeout(2);
$resolv->udp_timeout(2);

my $dbh = dbh();

my $config = read_config();
collect_query_counts();

sub collect_query_counts {
    my $sth_insert = $dbh->prepare
        (q[insert into measurements
           (ip, measurement_time, queries, query_time)
           values (?,?,?,?)]
        );

		my %sockets; my $time = time;
    for my $ns (keys %{$config->{servers}}) {
    	$resolv->nameservers($ns);
    	$sockets{$ns} = $resolv->bgsend('status.pool.ntp.org', 'TXT');
    }
    
    for my $i (1 .. 5) {
    	for my $ns (sort keys %sockets) {
    		my $socket = $sockets{$ns};
    		if ($socket && $resolv->bgisready($socket)) {
    			my $packet = $resolv->bgread($socket);
    			my $elapsed = time - $time; # Not that precise...
    			my ($txt) = $packet && grep { $_->type eq 'TXT' } $packet->answer;
    			delete $sockets{$ns};
    			
          #print $txt->rdatastr, "\n";
          my ($queries) = ($txt->rdatastr =~ m/q: (\d+)/)[0];
          #print "$ns: Q:$queries E:$elapsed\n";
          my $c = $config->{servers}->{$ns};
          my $ip24 = $c->{ip24};
          $sth_insert->execute($ip24, int $time, $queries, $elapsed);
    		}
      }
      
      last unless %sockets;
 
      sleep 1;
    }
}

1;
