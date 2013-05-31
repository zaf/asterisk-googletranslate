#!/usr/bin/env perl

#
# Script that uses Google Translate API v2 for text translation.
#
# In order to use this script an Google API Key is needed.
#
# Copyright (C) 2012, Lefteris Zafiris <zaf.000@gmail.com>
#
# This program is free software, distributed under the terms of
# the GNU General Public License Version 2.
#

use warnings;
use strict;
use Getopt::Std;
use URI::Escape;
use JSON;
use LWP::UserAgent;

binmode(STDOUT, ":encoding(UTF-8)");

# ------------------------------------------- #
# Here you can assign your App ID from Google #
my $appid   = "";
# ------------------------------------------- #
my %options;
my $input;
my $in_lang;
my $out_lang;
my $timeout = 10;
my $url     = "https://www.googleapis.com/language/translate/v2";

VERSION_MESSAGE() if (!@ARGV);

getopts('o:l:t:f:i:hqv', \%options);

# Dislpay help messages #
VERSION_MESSAGE() if (defined $options{h});

$appid = $options{i} if (defined $options{i});
if (!$appid) {
	say_msg("You must have an App ID from Google to use this script.");
	exit 1;
}

lang_list() if (defined $options{v});

# check if language settings are valid #
if (defined $options{l}) {
	if ($options{l} =~ /[a-zA-Z\-]{2,}/) {
		$in_lang = $options{l};
	} else {
		say_msg("Invalid input language setting. Using auto-detect.");
	}
}

if (defined $options{o}) {
	if ($options{o} =~ /[a-zA-Z\-]{2,}/) {
		$out_lang = $options{o};
	} else {
		say_msg("Invalid output language setting. Aborting.");
		exit 1;
	}
} else {
	print "Performing language detection.\n" if (!defined $options{q});
}

# Get input text #
if (defined $options{t}) {
	$input = $options{t};
} elsif (defined $options{f}) {
	if (open(my $fh, "<", "$options{f}")) {
		$input = do { local $/; <$fh> };
		close($fh);
	} else {
		say_msg("Cant read file $options{f}");
		exit 1;
	}
} else {
	say_msg("No text passed for translation.");
	exit 1;
}

for ($input) {
	s/[\\|*~<>^\n\(\)\[\]\{\}[:cntrl:]]/ /g;
	s/\s+/ /g;
	s/^\s|\s$//g;
	if (!length) {
		say_msg("No text passed for translation.");
		exit 1;
	}
	$_ = uri_escape($_);
}

my $ua = LWP::UserAgent->new(ssl_opts => {verify_hostname => 1});
$ua->env_proxy;
$ua->timeout($timeout);

if ($in_lang && $out_lang) {
	$url .= "?key=$appid&q=$input&source=$in_lang&target=$out_lang";
} elsif (!$in_lang && $out_lang) {
	$url .= "?key=$appid&q=$input&target=$out_lang";
} elsif (!$out_lang) {
	$url .= "/detect?key=$appid&q=$input";
}

my $response = $ua->post("$url", "X-HTTP-Method-Override" => "GET");
if (!$response->is_success) {
	say_msg("Failed to fetch translation data.");
	exit 1;
} else {
	my $jdata = decode_json $response->content;
	print $$jdata{data}{translations}[0]{translatedText}, "\n" if ($out_lang);
	print $$jdata{data}{detections}[0][0]{language}, "\n" if (!$out_lang);
}
exit 0;

sub say_msg {
# Print messages to user if 'quiet' flag is not set #
	my @message = @_;
	warn @message if (!defined $options{q});
	return;
}

sub VERSION_MESSAGE {
# Help message #
	print "Text translation using Google Translate API.\n\n",
		 "Supported options:\n",
		 " -t <text>      text string for translation\n",
		 " -f <file>      text file to translate\n",
		 " -l <lang>      specify the input language (optional)\n",
		 " -o <lang>      specify the output language\n",
		 " -i <appID>     set the App ID from Google\n",
		 " -q             quiet (Don't print any messages or warnings)\n",
		 " -h             this help message\n",
		 " -v             suppoted languages list\n\n",
		 "Examples:\n",
		 "$0 -o fr -t \"Hello world\"\n\tTranslate \"Hello world\" in French.\n",
		 "$0 -t \"Salut tout le monde\"\n\tDetect the language of the text string.\n\n";
	exit 1;
}

sub lang_list {
# Display the list of supported languages, we can translate between any two of these languages #
	my $ua = LWP::UserAgent->new(ssl_opts => {verify_hostname => 1});
	$ua->timeout($timeout);
	my $request  = HTTP::Request->new('GET' => "$url/languages?key=$appid");
	my $response = $ua->request($request);
	if ($response->is_success) {
		print "Supported languages list:\n",
			join("\n", grep(!/language|data|[\{\}\[\]:,]/, split(/"([a-zA-Z\-]{2,})"/, $response->content))), "\n";
	} else {
		say_msg("Failed to fetch language list.");
	}
	exit 1;
}
