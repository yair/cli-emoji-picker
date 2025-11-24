#!/usr/bin/perl
use strict;
use warnings;
use DBI;
use Encode qw(decode_utf8 encode_utf8);

# --- CONFIGURATION ---
my $db_file = "$ENV{HOME}/.emoji.db";
# Options: rofi, dmenu, fzf
my $launcher = "rofi"; 

# Rofi-specific options for a 2D Grid
# -dmenu: run in menu mode
# -i: case insensitive
# -p: prompt
# -columns 6: 6 columns wide
# -lines 10: 10 rows high
my $rofi_cmd = "rofi -dmenu -i -p 'Emoji' -columns 8 -lines 10 -width 50";
# ---------------------

# connect to DB
my $dbh = DBI->connect("dbi:SQLite:dbname=$db_file", "", "", {
    RaiseError => 1, AutoCommit => 1, sqlite_unicode => 1
});

# 1. SELECT emojis, sorted by Favorites first, then Alphabetical
my $sth = $dbh->prepare("SELECT char, description FROM emojis ORDER BY usage_count DESC, last_used DESC, description ASC");
$sth->execute();

# 2. Prepare input for the launcher
my %lookup;
my $list_str = "";

while (my $row = $sth->fetchrow_hashref) {
    # Format: "😀  Grinning Face"
    # We use a double space or a pipe as visual separator
    my $line = "$row->{char}  $row->{description}";
    $lookup{$line} = $row->{char};
    $list_str .= "$line\n";
}

# 3. Launch the picker
my $selection;
if ($launcher eq "rofi") {
    open(my $pipe, "|-", "$rofi_cmd > /tmp/emoji_selection") or die "Cannot run rofi: $!";
    binmode($pipe, ":utf8");
    print $pipe $list_str;
    close($pipe);
    
    # Rofi output handling is tricky via pipe in Perl, reading temp file is safer for encoding
    if (-e "/tmp/emoji_selection") {
        local $/;
        open(my $fh, "<:encoding(UTF-8)", "/tmp/emoji_selection");
        $selection = <$fh>;
        close($fh);
        chomp($selection) if $selection;
    }
} elsif ($launcher eq "fzf") {
    # Simple fzf fallback
    open(my $pipe, "|-", "fzf --reverse --height=10 > /tmp/emoji_selection") or die "Cannot run fzf";
    binmode($pipe, ":utf8");
    print $pipe $list_str;
    close($pipe);
    # Read result similarly...
}

# 4. Process Selection
if ($selection && exists $lookup{$selection}) {
    my $emoji = $lookup{$selection};
    
    # UPDATE STATISTICS
    # Increment count and set current timestamp
    $dbh->do("UPDATE emojis SET usage_count = usage_count + 1, last_used = ? WHERE char = ?", 
             undef, time(), $emoji);

    # Output to STDOUT (for script piping) and Clipboard
    # We explicitly encode to UTF-8 bytes for external commands
    my $utf8_emoji = encode_utf8($emoji);
    
    # Pipe to xclip
    open(my $xclip, "|-", "xclip -selection clipboard");
    print $xclip $utf8_emoji;
    close($xclip);
    
    # Also print to STDOUT in case you call this from vim
    print $utf8_emoji; 
}
