use strict;
use warnings;
use Path::Tiny;

sub x ($) {
  system ($_[0]) == 0 or die $?;
} # x

my $path = path (shift or die "Usage: $0 path key-label1 key-label2 ...");
$path->mkpath;

my $ca_key_path = $path->child ('ca-key.pem');
x "openssl genrsa -out \Q$ca_key_path\E 2048";

my $ca_cert_path = $path->child ('ca-cert.pem');
my $ca_subj = '/CN=ca.test';
x "openssl req -new -x509 -nodes -days 1 -key \Q$ca_key_path\E -out \Q$ca_cert_path\E -subj \Q$ca_subj\E";

for my $prefix (@ARGV) {
  my $server_key_path = $path->child ($prefix.'-key.pem');
  my $server_req_path = $path->child ($prefix.'-req.pem');
  my $server_subj = '/CN='.$prefix.'.test';
  x "openssl req -newkey rsa:2048 -days 1 -nodes -keyout \Q$server_key_path\E -out \Q$server_req_path\E -subj \Q$server_subj\E";

  my $server_key1_path = $path->child ($prefix.'-key-pkcs1.pem');
  x "openssl rsa -in \Q$server_key_path\E -out \Q$server_key1_path\E";

  my $server_cert_path = $path->child ($prefix.'-cert.pem');
  x "openssl x509 -req -in \Q$server_req_path\E -days 1 -CA \Q$ca_cert_path\E -CAkey \Q$ca_key_path\E -out \Q$server_cert_path\E -set_serial 01";
}

## License: Public Domain.
