#!/usr/bin/perl
use strict;
use warnings;
use DBI;
use Encode qw(decode_utf8 encode_utf8);
use Getopt::Long;

# --- CONFIGURATION ---
my $db_file = "$ENV{HOME}/.emoji.db";

# Default Configs
my $mode = "rofi_grid";   # fzf, dmenu, rofi_list, rofi_grid
my $target = "clipboard"; # clipboard, primary, type (inject), stdout
my $clip_tool = "xclip -selection clipboard -i"; # standard xclip command

# Command Line Overrides
GetOptions(
    "mode=s"   => \$mode,
    "target=s" => \$target
);

# --- MODE DEFINITIONS ---
my %cmds = (
    'fzf'       => 'fzf --reverse --height=10 --header="Select Emoji"',
    'dmenu'     => 'dmenu -i -l 10 -p "Emoji:"',
    'rofi_list' => 'rofi -dmenu -i -p "Emoji" -markup-rows',
    'rofi_grid' => 'rofi -dmenu -i -p "Emoji" -markup-rows -columns 8 -lines 6 -width 40'
);

# Die if invalid mode
die "Unknown mode: $mode" unless exists $cmds{$mode};

# Connect DB
my $dbh = DBI->connect("dbi:SQLite:dbname=$db_file", "", "", {
    RaiseError => 1, AutoCommit => 1, sqlite_unicode => 1
});

# 1. FETCH DATA
# Logic: High weight items first (Favorites), then ordered by Original File Order (Categories)
my $sth = $dbh->prepare("SELECT char, description, category FROM emojis ORDER BY weight DESC, original_id ASC");
$sth->execute();

my $input_str = "";
my %lookup;

while (my $row = $sth->fetchrow_hashref) {
    my $line_display;
    
    if ($mode eq 'rofi_grid') {
        # THE MAGIC TRICK:
        # Show Emoji, but hide Description using Pango size='0'
        # Rofi still filters on the hidden text.
        my $sanitized_desc = $row->{description}; 
        $sanitized_desc =~ s/&/&amp;/g; # Escape for XML/Pango
        $sanitized_desc =~ s/</&lt;/g;
        
        $line_display = "$row->{char} <span size='0'>$sanitized_desc $row->{category}</span>";
    } elsif ($mode eq 'rofi_list') {
        # List mode: Show Emoji + Description + (Category in small gray text)
        my $sanitized_desc = $row->{description};
        $sanitized_desc =~ s/&/&amp;/g;
        
        $line_display = "$row->{char}  $sanitized_desc <span color='gray' size='small'>($row->{category})</span>";
    } else {
        # Plain text for dmenu / fzf
        $line_display = "$row->{char}  $row->{description}";
    }

    $input_str .= "$line_display\n";
    
    # Map the FULL display string back to the char for lookup
    $lookup{$line_display} = $row->{char};
}

# 2. EXECUTE PICKER
my $selection;
my $cmd = $cmds{$mode};

# Open pipe to picker
open(my $pipe, "|-", "$cmd > /tmp/emoji_sel_temp") or die "Cannot run $mode: $!";
binmode($pipe, ":utf8");
print $pipe $input_str;
close($pipe);

# Read Output
if (-e "/tmp/emoji_sel_temp") {
    open(my $fh, "<:encoding(UTF-8)", "/tmp/emoji_sel_temp");
    $selection = <$fh>;
    close($fh);
    chomp($selection) if $selection;
}

# 3. HANDLE SELECTION
if ($selection && exists $lookup{$selection}) {
    my $emoji_char = $lookup{$selection};

    # A. Update Stats (Weight Algorithm)
    # Weight = Usage Count + Recency Bonus
    # We bump usage by 1. We set last_used to NOW.
    # We set weight to a simple decaying boost metric.
    # (Updating strictly based on usage count is safest for now)
    my $now = time();
    $dbh->do("UPDATE emojis SET usage_count = usage_count + 1, last_used = ?, weight = usage_count + 100 WHERE char = ?", 
             undef, $now, $emoji_char);

    # B. Output
    my $out_bytes = encode_utf8($emoji_char);

    if ($target eq 'stdout') {
        print $out_bytes;
    } elsif ($target eq 'type') {
        # Simulate Typing
        system("xdotool", "type", "--delay", "50", $emoji_char);
    } else {
        # Clipboard / Primary
        my $clip_flag = ($target eq 'primary') ? "-selection primary" : "-selection clipboard";
        open(my $xclip, "|-", "xclip $clip_flag -i");
        print $xclip $out_bytes;
        close($xclip);
    }
}
