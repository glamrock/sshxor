#!/usr/bin/perl


# this a modified version of chunkssh.pl from http://insecure.org/stc/sti.html
# original code from Brian Hatch, modification done by Susan Werner <heinousbutch@gmail.com>

# this does both the client and server ends. for the client end, add the lines:
# Host [host you want to xorssh to]
# ProxyCommand ~/sshxor.pl %h %p 
# at the end of your .ssh/config (so you only use xorssh for that host)


# on the server end, you can use inetd or xinetd


# for inetd, on the server end, put a line like 
# sshxor  stream  tcp     nowait  nobody  /usr/local/bin/sshxor.pl sshxor.pl 127.0.0.1 22
# in your inetd.conf
# and in your /etc/services put a line like
# sshxor          13107/tcp


# for xinetd.conf, look at the xinetd.conf.example file in this current
# directory

# then you just use ssh -p 13107 user@host and everything works ^_^

use warnings;
use strict;
use IO::Socket;

my $key = "\x19";

my $debug = shift @ARGV if $ARGV[0] eq '-d';
my $ssh_server = shift @ARGV;
my $port = shift @ARGV;

die "Usage: $0 ip.ad.dr.es port\n" unless $ssh_server and not @ARGV;
die "Usage: $0 ip.ad.dr.es port\n" unless $port and not @ARGV;

my $ssh_socket = IO::Socket::INET->new(
    Proto    => "tcp",
    PeerAddr => $ssh_server,
    PeerPort => $port,
) or die "cannot connect to $ssh_server\n";

# Parent will read from SSH server, and send to STDOUT,
# the SSH client process.
if ( fork ) {
    my $data;
    while ( 1 ) {
	my $bytes_read = sysread $ssh_socket, $data, 9999;
	if ( not $bytes_read ) {
	    warn "No more data from ssh server - exiting.\n";
	    exit 0;
	}
    $data = $data ^ ($key x length $data);
	syswrite STDOUT, $data, $bytes_read;
    }

} else {
    while ( 1 ) {
	my $data;

	my $bytes_left = sysread STDIN, $data, 625;

	# Exit if the connection has closed.
	if ( not $bytes_left ) {
	    warn "No more data from client - exiting.\n" if $debug;
	    exit 0;
	}
    $data = $data ^ ($key x length $data);
    syswrite $ssh_socket, $data, $bytes_left;

	}
}

