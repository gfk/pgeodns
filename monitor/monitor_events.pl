#!/usr/bin/perl
use strict;
use warnings;

use Time::HiRes qw(time);

use DBI;
use Data::Dumper;
use lib 'lib';
use ParaDNS; # Patched version of http://search.cpan.org/~msergeant/ParaDNS-2.0/
use Monitor qw(read_config dbh);

my $dbh = dbh();

my $config = read_config();
prepare_danga();
collect_query_counts();

sub collect_query_counts {
    my $sth_insert = $dbh->prepare
        (q[insert into measurements
           (ip, measurement_time, queries, query_time)
           values (?,?,?,?)]
        );

    my $time = time();
    foreach my $ns (keys %{$config->{servers}}) {
      ParaDNS->new(
        callback => sub {
            if ($_[0] =~ m/q: (\d+)/) {
              my $queries = $1;
              my $elapsed = time - $time;
              #print "$ns: Q:$queries E:$elapsed\n";
              my $c = $config->{servers}->{$ns};
              my $ip24 = $c->{ip24};
              $sth_insert->execute($ip24, int $time, $queries, $elapsed);
            }
            #print STDERR "$ns: $_[0]\n";
        },
        type => 'TXT',
        host => 'status.pool.ntp.org',
        nameservers => [$ns]
      );
    }
    Danga::Socket->EventLoop();
}

sub prepare_danga {
  Danga::Socket->SetPostLoopCallback(
    sub {
        my $dmap = shift;
        for my $fd (keys %$dmap) {
            my $pob = $dmap->{$fd};
            if ($pob->isa('ParaDNS::Resolver')) {
                return 1 if $pob->pending;
            }
        }
        return 0; # causes EventLoop to exit
    }
  );
}

1;
