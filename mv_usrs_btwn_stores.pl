#!/usr/bin/perl -w
#

use strict;
use Getopt::Std;
use Data::Dumper;

sub move_and_purge(@);
sub print_usage();
sub calc_size($);

my @script_dir = split /\//, $0;
my $script_dir;
my $start = 1;
$start = 0 if ($script_dir[0]);
$script_dir = join '/', @script_dir[$start..$#script_dir-1];
$script_dir = '/' . $script_dir if ($0=~/^\//);


my %opts;
getopts('oec:a:d:np:', \%opts);

my $whoami = `whoami`;
chomp $whoami;
if ($whoami ne "zimbra") {
    print "run as zimbra!\n";
    exit;
}

if (!exists $opts{c} && !exists $opts{a}) {
    print "you must specify either -c or -a\n";
    print_usage();
}


if (exists $opts{n}) {
    print "-n used, no changes will be made\n";
}
my $count;

if (exists $opts{c} && ! exists $opts{a}) {
    $count = $opts{c};
    print "\nworking on $count records...\n";
} 

my $account_to_move;
if (exists $opts{a}) {
    $account_to_move = $opts{a};
    print "\naccount chosen by name: $account_to_move\n";

    move_and_purge($account_to_move);
    exit;
}

my $total_size = 0;

my $in;
open ($in, 'zmprov gqu `zmhostname`|');

while (<$in>) {
    last if ($count<=0);

    my ($account,$size) = (split /\s+/, $_)[0,2];
    my $n = (split /\@/, $account)[0];

    my $length = () = split //, $n, -1;
    my $d = (split //, $n)[$length-2];

    if (exists $opts{p} && $d =~ /[$opts{p}]{1}/ || !exists $opts{p}) {
	print "\n", $account, " ", calc_size($size), "gb\n";

	my $rc = move_and_purge($account);
	
	$total_size += $size
	  unless ($rc);
	print --$count, " accounts left\n";
    }

} 


sub move_and_purge(@) {
    my $account = shift;

    my $dest;
    if (exists $opts{d}) {
	$dest = $opts{d};
    } else {
	my $last_digit = `zmprov ga $account zimbraarchiveaccount`;
	$last_digit =~ /zimbraArchiveAccount: \d+(\d{1})/;
	$last_digit = $1;

	if (!defined $last_digit || $last_digit =~ /^\s*$/) {
	    print "no last digit found for ${account}'s archive account, skipping\n";
	    print "use -d <dest host> if you are moving account(s) that don't have an associated archive acct.\n";
	    print "\n";
	    return();
	}

	print "destination host: $dest\n";
    }

    print "moving files for ${account} at " . `date`;
    if (!exists $opts{n}) {
	if (system ("zmmboxmove -a $account --from `zmhostname` --to $dest --sync") != 0) {
	    die "zmmboxmove failed for $account";
	}
    }

    print "files moved, purging mailbox " . `date`;
    if (!exists $opts{n}) {
	if (system ("zmpurgeoldmbox -a $account") != 0) {
	    die "purging $account mailbox failed failed";
	}
    }
}

print "\ntotal size: ", calc_size($total_size), "gb\n";


sub print_usage() {
    print "\n";
    print "usage: $0 [-n] -d <destination host> -c <records to move>\n";
    print "\t -p pattern | -a <specific account to move>\n";
    print "\n";
    print "\t-d <destination host> host to which to move account(s)\n";
    print "\t-p pick host to which to move accounts based on \n";
    print "\t\tlast digit of archive account, this is a perl character class:\n";
    print "\t\tex: 123: move accounts ending in 1,2, or 3.\n";
    print "\t-c <record count to move | -a <account to move>\n";
    print "\t\teither move an individual account or take a specified\n";
    print "\t\tnumber off the top of zmprov gqu `zmhostname`\n";
    print "\t-n print but do not make changes\n";
    exit 1;
}


sub calc_size($) {
    my $size = shift;

    my $r = sprintf("%.2f",  $size/(1024**3));
    return $r;
}
