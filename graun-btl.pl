#!/usr/bin/perl
#
# Download comments on an article on the Guardian website

use strict;
use WWW::Mechanize ();
use JSON ();

my $uid_pref = "GUU";
my $cid_pref = "GUC";
my @p_id;
my $cmd_p_id = 0;
my @cols = ("CID", "RCID", "DPTH", "UID", "DT", "UP", "ED", "TXT");
my %headings = (
  "CID" => "Comment ID",
  "RCID" => "Comment ID Responding To",
  "LVL" => "Level",
  "DPTH" => "Depth",
  "UID" => "User ID",
  "AU" => "Author",
  "DT" => "Date Time",
  "UP" => "Recommendations",
  "ED" => "Highlighted?",
  "TXT" => "Comment Text",
  "MD" => "Comment Text without Markup");

binmode STDOUT, ":encoding(UTF-8)";

my $usage_str = "Usage: $0 [--user-id-prefix <string>] [--comment-id-prefix <string>] "
  ."[--remove-markup] [--columns <column codes>] [--column-as <column code> <heading>] "
  ."{[--discussion-id <string>]|<Guardian Article URL>}";

if(scalar(@ARGV) == 0) {
  die "$usage_str\n";
}

while($ARGV[0] =~ /^-/) {
  my $opt = shift(@ARGV);
  if($opt eq "--user-id-prefix" || $opt eq "-u") {
    $uid_pref = shift(@ARGV);
  }
  elsif($opt eq "--comment-id-prefix" || $opt eq "-c") {
    $cid_pref = shift(@ARGV);
  }
  elsif($opt eq "--discussion-id" || $opt eq "-D") {
    push(@p_id, shift(@ARGV));
    $cmd_p_id = 1;
  }
  elsif($opt eq "--remove-markup" || $opt eq "-m") {
    for(my $i = 0; $i <= $#cols; $i++) {
      if($cols[$i] eq "TXT") {
        $cols[$i] = "MD";
        last;
      }
    }
  }
  elsif($opt eq "--columns" || $opt eq "-C") {
    @cols = split(/,/, shift(@ARGV));
    foreach my $col (@cols) {
      if(!defined($headings{$col})) {
        warn "Column code \"$col\" not recognized; will add as heading with NA entries\n";
      }
    }
  }
  elsif($opt eq "--column-as" || $opt eq "-a") {
    my $col = shift(@ARGV);
    my $as = shift(@ARGV);
    if(defined($headings{$col})) {
      $headings{$col} = $as;
    }
    else {
      die "Column code \"$col\" not recognized; use --columns for a column with NAs\n";
    }
  }
  elsif($opt eq "--all" || $opt eq "-A") {
    @cols = ("CID", "RCID", "DPTH", "AU", "UID", "DT", "UP", "ED", "TXT", "MD");
  }
  else {
    die "$usage_str\n\n"
      ."Download comments from a Guardian article into a CSV format (use output redirect\nto save).\n\n"
      ."Guardian-assigned user IDs and comment IDs are replaced with new numbers\nprovided by this "
      ."program.\n\n"
      ."\t--user-id-prefix P: use P as a prefix in front of user ID numbers\n\t\t(default \"$uid_pref\")\n"
      ."\t--comment-id-prefix P: use P as a prefix in front of comment ID numbers\n\t\t(default "
      ."\"$cid_pref\")\n"
      ."\t--discussion-id D: use D as a discussion ID rather than extracting it\n\t\tfrom the "
      ."article URL\n"
      ."\t--remove-markup: replace the TXT column with the MD column\n"
      ."\t--columns L: print the column codes in comma-separated list L; if any\n\t\tof the "
      ."codes are not recognized, the entry is used as a column-\n\t\theading with NA entries. "
      ."Column codes are:\n\t\t\tCID -- comment ID\n\t\t\tRCID -- ID of comment being responded to"
      ."\n\t\t\tDPTH -- 'depth' of the comment\n\t\t\tAU -- commenter's displayed name\n\t\t\t"
      ."UID -- pseudonymized user identification number\n\t\t\tDT -- date-time of comment\n\t\t\t"
      ."UP -- number of comment recommendations\n\t\t\tED -- comment highlighted by moderator"
      ."\n\t\t\tTXT -- comment text with any HTML markup\n\t\t\tMD -- comment text with HTML tags"
      ."removed\n\t\t\tLVL -- as RCID, but \"Reply to ID\" or empty\n"
      ."\t--column-as C H: use H as the heading for column code C instead of the\n\t\tdefault. "
      ."You can repeat this as often as you want. Defaults:\n\t\t\tCID -- \"$headings{'CID'}\"\n"
      ."\t\t\tRCID -- \"$headings{'RCID'}\"\n\t\t\tDPTH -- \"$headings{'DPTH'}\"\n\t\t\tAU -- \""
      ."$headings{'AU'}\"\n\t\t\tUID -- \"$headings{'UID'}\n\t\t\tDT -- \"$headings{'DT'}\"\n\t\t\tUP "
      ."-- \"$headings{'UP'}\"\n\t\t\tED -- \"$headings{'ED'}\"\n\t\t\tTXT -- \"$headings{'TXT'}\"\n\t\t\t"
      ."MD -- \"$headings{'MD'}\"\n\t\t\tLVL -- \"$headings{'LVL'}\"\n"
      ."\t--all: put all columns in the output, as opposed to the default:\n\t\t\""
      .(join(",", @cols))."\"\n";
  }
}

if(!$cmd_p_id) {
  my $url = shift(@ARGV);
  my $mech = WWW::Mechanize->new();
  $mech->get($url);

  if(!$mech->success()) {
    die "Could not read from URL \"$url\": ", $mech->status(), "\n";
  }
  if(!$mech->is_html()) {
    die "URL \"$url\" is not HTML\n";
  }

  my $html = $mech->content();

  foreach my $word (split(" ", $html)) {
    if($word =~ /discussion\.theguardian\.com\/discussion-api/ && $word =~ /shortUrlId/) {
      if($word =~ /\/p\/([a-zA-Z0-9]+)/) {
        push(@p_id, $1);
      }
    }
  }
  if(scalar(@p_id) == 0) {
    die "Cannot find a comment reference number in Guardian article \"$url\"\n";
  }
  for(my $i = 1; $i <= $#p_id; $i++) {
    if($p_id[0] ne $p_id[$i]) {
      die "Non-unique comment reference numbers $p_id[0] and $p_id[$i] found in Guardian article \"$url\"\n";
    }
  }
}

my @pages;
my $api = "http://discussion.theguardian.com/discussion-api/discussion//p/$p_id[0]?pageSize=50";
my $pp = 1;
my $n_cmt = 1000;
my %comments;
my %responses;
my %cids;
my %uids;
my $nxt_cid = 0;
my $nxt_uid = 0;
while(scalar(keys(%comments)) < $n_cmt) {
  my $page = WWW::Mechanize->new();
  push(@pages, $page);
  eval {
    $page->get("$api&page=$pp");
    1;
  } or do {
    last;
  };

  if(!$page->success()) {
    last;
  }
  if($page->ct() ne "application/json") {
    die("Content type of API call $api&page=$pp is not JSON: ", $page->ct(), "\n");
  }

  my $json = JSON::decode_json($page->content());

  $n_cmt = $json->{'discussion'}->{'commentCount'};

  my $n_p_cmt = $json->{'pageSize'};

  for(my $i = 0; $i < $n_p_cmt; $i++) {
    my $id = $json->{'discussion'}->{'comments'}->[$i]->{'id'};
    my $uid = $json->{'discussion'}->{'comments'}->[$i]->{'userProfile'}->{'userId'};
    my $txt = $json->{'discussion'}->{'comments'}->[$i]->{'body'};
    my $dt = $json->{'discussion'}->{'comments'}->[$i]->{'isoDateTime'};
    my $hi = $json->{'discussion'}->{'comments'}->[$i]->{'isHighlighted'};
    my $rec = $json->{'discussion'}->{'comments'}->[$i]->{'numRecommends'};
    my $uname = $json->{'discussion'}->{'comments'}->[$i]->{'userProfile'}->{'displayName'};
    my $n_resp = $json->{'discussion'}->{'comments'}->[$i]->{'metaData'}->{'responseCount'};

    $comments{$id} = [$id, $uid, $dt, $rec, $hi, $txt, $uname];
    $cids{$id} = ++$nxt_cid if !defined($cids{$id});
    $uids{$uid} = ++$nxt_uid if !defined($uids{$uid});

    for(my $j = 0; $j < $n_resp; $j++) {
      my $resp_id = $json->{'discussion'}->{'comments'}->[$i]->{'responses'}->[$j]->{'id'};
      my $resp_uid = $json->{'discussion'}->{'comments'}->[$i]->{'responses'}->[$j]->{'userProfile'}->{'userId'};
      my $resp_txt = $json->{'discussion'}->{'comments'}->[$i]->{'responses'}->[$j]->{'body'};
      my $resp_dt = $json->{'discussion'}->{'comments'}->[$i]->{'responses'}->[$j]->{'isoDateTime'};
      my $resp_hi = $json->{'discussion'}->{'comments'}->[$i]->{'responses'}->[$j]->{'isHighlighted'};
      my $resp_rec = $json->{'discussion'}->{'comments'}->[$i]->{'responses'}->[$j]->{'numRecommends'};
      my $resp_un = $json->{'discussion'}->{'comments'}->[$i]->{'responses'}->[$j]->{'userProfile'}->{'displayName'};

      $responses{$resp_id} = $id;
      $comments{$resp_id} = [$resp_id, $resp_uid, $resp_dt, $resp_rec, $resp_hi, $resp_txt, $resp_un];
      $cids{$resp_id} = ++$nxt_cid if !defined($cids{$resp_id});
      $uids{$resp_uid} = ++$nxt_uid if !defined($uids{$resp_uid});
    }
  }

  $pp++;
}

my %depths;
my $depth = 0;
my $n = 0;
do {
  $n = 0;
  foreach my $id (keys(%comments)) {
    if($depth > 0 && defined($responses{$id}) && defined($depths{$responses{$id}})) {
      $depths{$id} = 1 + $depths{$responses{$id}};
    }
    elsif($depth == 0 && !defined($responses{$id})) {
      $depths{$id} = $depth;
      $n++;
    }
  }
  $depth++;
} while($n > 0);

my $nc_dig = length(sprintf("%d", scalar(keys(%cids))));
my $nu_dig = length(sprintf("%d", scalar(keys(%uids))));

foreach my $col (@cols) {
  if(defined($headings{$col})) {
    print $headings{$col};
  }
  else {
    print $col;
  }
  print ($col eq $cols[$#cols] ? "\n" : ",");
}
foreach my $cid (sort(keys(%comments))) {
  my ($id, $uid, $dt, $rec, $hi, $txt, $au) = @{$comments{$cid}};

  next if $id !~ /./;

  $txt =~ s/\n/ /g;
  my $md = $txt;
  $md =~ s/\<[^\>]+\>/ /g;
  $txt =~ s/\"/\"\"/g;
  $txt = "\"$txt\"";
  $md =~ s/\"/\"\"/g;
  $md = "\"$md\"";

  my $pcid = sprintf("${cid_pref}%0*d", $nc_dig, $cids{$id});
  my $puid = sprintf("${uid_pref}%0*d", $nu_dig, $uids{$uid});

  my $resp_to = (defined($responses{$id}) ? sprintf("${cid_pref}%0*d", $nc_dig, $cids{$responses{$id}}) : "NA");

  foreach my $col (@cols) {
    if($col eq "CID") {
      print $pcid;
    }
    elsif($col eq "RCID") {
      print $resp_to;
    }
    elsif($col eq "LVL") {
      print ($resp_to eq "NA" ? "" : "Reply to $resp_to");
    }
    elsif($col eq "DPTH") {
      print $depths{$id};
    }
    elsif($col eq "UID") {
      print $puid;
    }
    elsif($col eq "AU") {
      print $au;
    }
    elsif($col eq "DT") {
      print $dt;
    }
    elsif($col eq "UP") {
      print $rec;
    }
    elsif($col eq "ED") {
      print $hi;
    }
    elsif($col eq "TXT") {
      print $txt;
    }
    elsif($col eq "MD") {
      print $md;
    }
    else {
      print "NA";
    }
    print ($col eq $cols[$#cols] ? "\n" : ",");
  }
}

if(scalar(keys(%comments)) < $n_cmt) {
  warn "I only got ", scalar(keys(%comments)), " of $n_cmt comments after $pp pages\n";
}

exit 0;
