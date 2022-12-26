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

binmode STDOUT, ":encoding(UTF-8)";

my $usage_str = "Usage: $0 [--user-id-prefix <string>] [--comment-id-prefix <string>] "
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
  else {
    die "$usage_str\n\n"
      ."Download comments from a Guardian article into a CSV format (use output redirect\nto save).\n\n"
      ."Guardian-assigned user IDs and comment IDs are replaced with new numbers\nprovided by this "
      ."program.\n\n"
      ."\t--user-id-prefix P: use P as a prefix in front of user ID numbers\n\t\t(default \"$uid_pref\")\n"
      ."\t--comment-id-prefix P: use P as a prefix in front of comment ID numbers\n\t\t(default "
      ."\"$cid_pref\")\n"
      ."\t--discussion-id D: use D as a discussion ID rather than extracting it\n\t\tfrom the "
      ."article URL\n";
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
    my $n_resp = $json->{'discussion'}->{'comments'}->[$i]->{'metaData'}->{'responseCount'};

    $comments{$id} = [$id, $uid, $dt, $rec, $hi, $txt];
    $cids{$id} = ++$nxt_cid if !defined($cids{$id});
    $uids{$uid} = ++$nxt_uid if !defined($uids{$uid});

    for(my $j = 0; $j < $n_resp; $j++) {
      my $resp_id = $json->{'discussion'}->{'comments'}->[$i]->{'responses'}->[$j]->{'id'};
      my $resp_uid = $json->{'discussion'}->{'comments'}->[$i]->{'responses'}->[$j]->{'userProfile'}->{'userId'};
      my $resp_txt = $json->{'discussion'}->{'comments'}->[$i]->{'responses'}->[$j]->{'body'};
      my $resp_dt = $json->{'discussion'}->{'comments'}->[$i]->{'responses'}->[$j]->{'isoDateTime'};
      my $resp_hi = $json->{'discussion'}->{'comments'}->[$i]->{'responses'}->[$j]->{'isHighlighted'};
      my $resp_rec = $json->{'discussion'}->{'comments'}->[$i]->{'responses'}->[$j]->{'numRecommends'};

      $responses{$resp_id} = $id;
      $comments{$resp_id} = [$resp_id, $resp_uid, $resp_dt, $resp_rec, $resp_hi, $resp_txt];
      $cids{$resp_id} = ++$nxt_cid if !defined($cids{$resp_id});
      $uids{$resp_uid} = ++$nxt_uid if !defined($uids{$resp_uid});
    }
  }

  $pp++;
}

my $nc_dig = length(sprintf("%d", scalar(keys(%cids))));
my $nu_dig = length(sprintf("%d", scalar(keys(%uids))));

print "Comment ID,Comment ID Responding To,User ID,Date Time,Recommendations,Highlighted?,Comment Text\n";
foreach my $cid (sort(keys(%comments))) {
  my ($id, $uid, $dt, $rec, $hi, $txt) = @{$comments{$cid}};

  next if $id !~ /./;

  $txt =~ s/\n/ /g;
  $txt =~ s/\"/\"\"/g;
  $txt = "\"$txt\"";

  my $pcid = sprintf("${cid_pref}%0*d", $nc_dig, $cids{$id});
  my $puid = sprintf("${uid_pref}%0*d", $nu_dig, $uids{$uid});

  my $resp_to = (defined($responses{$id}) ? sprintf("${cid_pref}%0*d", $nc_dig, $cids{$responses{$id}}) : "NA");

  print "$pcid,$resp_to,$puid,$dt,$rec,$hi,$txt\n"
}

if(scalar(keys(%comments)) < $n_cmt) {
  warn "I only got ", scalar(keys(%comments)), " of $n_cmt comments after $pp pages\n";
}

exit 0;
