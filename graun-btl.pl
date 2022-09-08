#!/usr/bin/perl
#
# Download comments on an article on the Guardian website

use strict;
use WWW::Mechanize ();
use JSON ();

if(scalar(@ARGV) == 0) {
  die "Usage: $0 <Guardian Article URL>\n";
}

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

my @p_id;
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

my @pages;
my $api = "http://discussion.theguardian.com/discussion-api/discussion//p/$p_id[0]?pageSize=50";
my $pp = 1;
my $n_cmt = 1000;
my %comments;
my %responses;
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
    my $n_resp = $json->{'discussion'}->{'comments'}->[$i]->{'metaData'}->{'responseCount'};

    $comments{$id} = [$id, $uid, $txt];

    for(my $j = 0; $j < $n_resp; $j++) {
      my $resp_id = $json->{'discussion'}->{'comments'}->[$i]->{'responses'}->[$j]->{'id'};
      my $resp_uid = $json->{'discussion'}->{'comments'}->[$i]->{'responses'}->[$j]->{'userProfile'}->{'userId'};
      my $resp_txt = $json->{'discussion'}->{'comments'}->[$i]->{'responses'}->[$j]->{'body'};
      $responses{$resp_id} = $id;
      $comments{$id} = [$resp_id, $resp_uid, $resp_txt];
    }
  }

  $pp++;
}

foreach my $cid (sort(keys(%comments))) {
  my ($id, $uid, $txt) = @{$comments{$cid}};

  $txt =~ s/\n/ /g;
  $txt =~ s/\"/\"\"/g;
  $txt = "\"$txt\"";

  my $resp_to = (defined($responses{$id}) ? $responses{$id} : "NA");

  print "$id,$resp_to,$uid,$txt\n"
}

if(scalar(keys(%comments)) < $n_cmt) {
  warn "I only got ", scalar(keys(%comments)), " of $n_cmt comments\n";
}

exit 0;
