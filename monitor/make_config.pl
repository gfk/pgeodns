#!/usr/bin/perl
use strict;
use warnings;
use JSON;
use Net::DNS::Resolver ();
use Data::Dumper;

my @domains = ('pool.ntp.org');
my $config_file = 'servers.json';

write_config_file();

sub write_config_file {
	my %ns = find_dns_servers();
	
	my $json;
	$json->{zones} = \@domains;
	$json->{servers} = \%ns;
	
	open my $json_fh, '>', $config_file or die "Could not open $config_file: $!\n";
	print $json_fh JSON->new->pretty(1)->encode($json);
	close $json_fh;
}

sub find_dns_servers {
 
    my $res = Net::DNS::Resolver->new;
 
    my %servers;
    
    my $add_servers = sub {
        my $name = shift;
        my @ips = host_to_ips($name);
        for my $ip (@ips) {
            unless ($servers{$ip}) {
                $servers{$ip} = { names => [] };
            }
            push @{ $servers{$ip}->{names} }, $name;
        }
    };
 
    for my $domain (@domains) {
        if (my $query = $res->query($domain, "NS")) {
            for my $rr (grep { $_->type eq 'NS' } $query->answer) {
                my $name = $rr->nsdname;
                $add_servers->($name);
            }
        }
    }
 
    if (my $query = $res->query('all-dns.ntppool.net', "TXT")) {
        for my $rr (grep { $_->type eq 'TXT' } $query->answer) {
            my $names = $rr->txtdata;
            for my $name (split /\s+/, $names) {
                $name =~ m/\./ or $name = "$name.ntppool.net";
                $add_servers->($name);
            }
        }
    }
 
    #use Data::Dumper qw(Dumper);
    #print Dumper(\%servers);
    #exit;
 
    return %servers;
}

my $resolver;
sub _res {
    return $resolver = Net::DNS::Resolver->new;
}

sub host_to_ips {
    my $host = shift;
    my $res = _res();
    my $query = $res->search($host);
  
    my @ips;
 
    if ($query) {
        for my $rr ($query->answer) {
            next unless $rr->type eq "A";
            push @ips, $rr->address;
        }
    } else {
        warn "query failed: ", $res->errorstring, "\n";
    }
    return @ips;
}
