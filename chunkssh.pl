#!/usr/bin/perl

use warnings;
use strict;
use IO::Socket;

my $debug = shift @ARGV if $ARGV[0] eq '-d';
my $ssh_server = shift @ARGV;

die "Usage: $0 ip.ad.dr.es\n" unless $ssh_server and not @ARGV;

my $ssh_socket = IO::Socket::INET->new(
    Proto    => "tcp",
    PeerAddr => $ssh_server,
    PeerPort => 22,
) or die "cannot connect to $ssh_server\n";

# The data 'chunk' sizes that are allowed by Charles' kernel
my @sendable = qw( 1331 1000 729 512 343 216 125 64 27 8 1 0);

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
	syswrite STDOUT, $data, $bytes_read;
    }

# Child will read from STDIN, the SSH client process, and
# send to the SSH server socket only in appropriately-sized
# chunks. Will write chunk sizes to STDERR to prove it's working.
} else {
    while ( 1 ) {
	my $data;

	# Read in as much as I can send in a chunk
	my $bytes_left = sysread STDIN, $data, 625;

	# Exit if the connection has closed.
	if ( not $bytes_left ) {
	    warn "No more data from client - exiting.\n" if $debug;
	    exit 0;
	}

	# Find biggest chunk we can send, send as many of them
	# as we can.
	for my $index ( 0..@sendable ) {
	    while ( 1 ) {
		if ( $bytes_left <= $sendable[$index] ) {
		    my $send_bytes = $sendable[$index];

		    warn "Sending $send_bytes bytes\n" if $debug;
		    syswrite $ssh_socket, $data, $send_bytes;

		    # Chop off our string
		    substr($data,0,$send_bytes,'');
		    $bytes_left -= $send_bytes;

		} else {
		    last; # Let's try a different chunk size
		}

	    }
	    last unless $bytes_left;
	}
    }
}
