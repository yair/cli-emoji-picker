#!/usr/bin/perl
use strict;
use warnings;
use DBI;

# Config
my $db_file = "$ENV{HOME}/.emoji.db";
my $source_url = "https://unicode.org/Public/emoji/latest/emoji-test.txt";

# Connect to SQLite
my $dbh = DBI->connect("dbi:SQLite:dbname=$db_file", "", "", {
    RaiseError => 1, AutoCommit => 1
});

# Create Table
$dbh->do(<<EOF);
CREATE TABLE IF NOT EXISTS emojis (
    char TEXT PRIMARY KEY,
    description TEXT,
    usage_count INTEGER DEFAULT 0,
    last_used INTEGER DEFAULT 0
)
EOF

print "Downloading and parsing fresh emoji list...\n";

# Fetch data (using curl to keep perl deps low)
open(my $fh, "-|", "curl -s '$source_url'") or die "Cannot fetch emojis: $!";

my $count = 0;
$dbh->begin_work;

while (<$fh>) {
    chomp;
    # Filter logic (same as before)
    next if /^#/;
    next if /^\s*$/;
    next if /minimally-qualified/; 
    
    # Parse standard line: code ; fully-qualified # char description
    if (/^[0-9A-F].+;\s+fully-qualified\s+#\s(\S+)\s(.+)$/) {
        my $char = $1;
        my $desc = $2;
        
        # Insert or Ignore (preserves usage stats if re-running)
        $dbh->do("INSERT OR IGNORE INTO emojis (char, description) VALUES (?, ?)", undef, $char, $desc);
        $count++;
    }
}
$dbh->commit;

print "Database initialized with $count emojis at $db_file\n";
