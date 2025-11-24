#!/usr/bin/perl
use strict;
use warnings;
use DBI;
use LWP::Simple; # Standard perl lib, usually installed
use Getopt::Long;

# --- CONFIG ---
my $db_file = "$ENV{HOME}/.emoji.db";
my $source_url = "https://unicode.org/Public/emoji/latest/emoji-test.txt";
my $input_file = '';

GetOptions ("file=s" => \$input_file);

# Connect to DB
my $dbh = DBI->connect("dbi:SQLite:dbname=$db_file", "", "", {
    RaiseError => 1, AutoCommit => 0, sqlite_unicode => 1
});

# Schema Definition
# original_id: keeps the sorting from the file (Categorized)
# weight: The decay metric
$dbh->do(<<EOF);
CREATE TABLE IF NOT EXISTS emojis (
    original_id INTEGER PRIMARY KEY AUTOINCREMENT,
    char TEXT UNIQUE,
    description TEXT,
    category TEXT,
    usage_count INTEGER DEFAULT 0,
    last_used INTEGER DEFAULT 0,
    weight REAL DEFAULT 0
);
EOF
# Create Indices for speed
$dbh->do("CREATE INDEX IF NOT EXISTS idx_weight ON emojis (weight DESC);");
$dbh->do("CREATE INDEX IF NOT EXISTS idx_orig ON emojis (original_id ASC);");

$dbh->commit;

# Input Source Logic
my $fh;
if ($input_file) {
    open($fh, "<:encoding(UTF-8)", $input_file) or die "Could not open file '$input_file': $!";
    print "Reading from local file: $input_file\n";
} else {
    print "Downloading from $source_url...\n";
    open($fh, "-|", "curl -s '$source_url'") or die "Curl failed: $!";
    binmode($fh, ":encoding(UTF-8)");
}

print "Parsing and Populating DB...\n";

$dbh->begin_work;
# Clear table to allow clean re-import (optional, remove if you want to keep old stats on re-import)
# To keep stats, we would need to use UPSERT logic, simplified here to INSERT OR IGNORE
# $dbh->do("DELETE FROM emojis"); 

my $current_group = "Uncategorized";
my $count = 0;

while (<$fh>) {
    chomp;
    next if /^\s*$/;

    # Capture Category (Group)
    if (/^# group: (.*)/) {
        $current_group = $1;
        next;
    }
    
    next if /^#/; # Skip other comments
    next if /minimally-qualified/; 

    # Parse Line: 1F600 ; fully-qualified # 😀 E1.0 grinning face
    if (/^[0-9A-F].+;\s+fully-qualified\s+#\s(\S+)\s(?:E\d+\.\d+\s)?(.+)$/) {
        my $char = $1;
        my $desc = $2;
        
        # Insert (Ignore duplicates to preserve usage stats if table exists)
        # We specificially do NOT update usage_count here.
        my $sth = $dbh->prepare("INSERT OR IGNORE INTO emojis (char, description, category) VALUES (?, ?, ?)");
        $sth->execute($char, $desc, $current_group);
        $count++;
    }
}

$dbh->commit;
close($fh);
print "Success! Database populated with $count emojis.\n";
