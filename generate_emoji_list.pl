#!/usr/bin/perl -w
use strict;

# USAGE - pipe https://unicode.org/Public/emoji/latest/emoji-test.txt through this and save to a file
# e.g. wget https://unicode.org/Public/emoji/latest/emoji-test.txt | ./generate_emoji_list.pl > ~/.emojis

my ($lines, $emojis, $saved, $unqualified, $minimally_qualified, $component, $skintones);

while (<>) {

	chomp;
	$lines++;

	/^#EOF/ and last;
	/^#/ and next;
	/^\s*$/ and next;

	$emojis++;

	if (/; unqualified/) {
		$unqualified++;
		next;
	}

	if (/; minimally-qualified/) {
		$minimally_qualified++;
		next;
	}

	if (/; component/) {
		$component++;
		next;
	}

	if (/skin tone$/) {
		$skintones++;
		next;
	}

#	/^([0123].*)\s+; fully-qualified\s+# (.) E\d+\.\d (.*)$/ or die "Invalid line - \"$_\"\n";
	/^([0123].*)\s+; fully-qualified\s+# (.+) E\d+\.\d+ (.*)$/u or die "Invalid line - \"$_\"\n";

	print "$2 $3\n";

	$saved++;
}

print STDERR "Processed $lines lines, $emojis emojis, of which $unqualified unqualified, $minimally_qualified minimally qualified, $component components, $skintones skin tones and $saved saved.\n";

