use Mojo::Base -strict;
use Test::More;
use Mojo::Redis;

my $args;
Mojo::Util::monkey_patch('Mojo::IOLoop::Client', 'connect' => sub { $args = $_[1] });

subtest 'tls disabled' => sub {
  $args = undef;
  my $redis = Mojo::Redis->new('redis://localhost:6379');
  $redis->db->connection->_connect;
  ok !exists $args->{tls}, 'no tls key in connect args';
};

subtest 'tls enabled with boolean' => sub {
  $args = undef;
  my $redis = Mojo::Redis->new('redis://localhost:6379', tls => 1);
  $redis->db->connection->_connect;
  is $args->{tls}, 1, 'tls enabled';
  ok !exists $args->{tls_ca},   'no tls_ca';
  ok !exists $args->{tls_cert}, 'no tls_cert';
  ok !exists $args->{tls_key},  'no tls_key';
};

subtest 'tls with hashref passes tls_ keys' => sub {
  $args = undef;
  my $redis = Mojo::Redis->new('redis://localhost:6379', tls => {
    tls_ca   => '/etc/tls/ca.crt',
    tls_cert => '/etc/tls/client.crt',
    tls_key  => '/etc/tls/client.key',
  });
  $redis->db->connection->_connect;
  is $args->{tls},      1,                     'tls enabled';
  is $args->{tls_ca},   '/etc/tls/ca.crt',     'tls_ca passed through';
  is $args->{tls_cert}, '/etc/tls/client.crt', 'tls_cert passed through';
  is $args->{tls_key},  '/etc/tls/client.key', 'tls_key passed through';
};

subtest 'tls hashref filters non-tls_ keys' => sub {
  $args = undef;
  my $redis = Mojo::Redis->new('redis://localhost:6379', tls => {
    tls_ca  => '/etc/tls/ca.crt',
    foo     => 'bar',
    address => 'evil',
    port    => 9999,
  });
  $redis->db->connection->_connect;
  is $args->{tls},     1,                  'tls enabled';
  is $args->{tls_ca},  '/etc/tls/ca.crt', 'tls_ca passed';
  ok !exists $args->{foo},                 'non-tls key "foo" filtered out';
  is $args->{address}, 'localhost',        'address not overridden by hashref';
  is $args->{port},    6379,               'port not overridden by hashref';
};

subtest 'tls hashref with tls_options and tls_verify' => sub {
  $args = undef;
  my $redis = Mojo::Redis->new('redis://localhost:6379', tls => {
    tls_verify  => 0x00,
    tls_version => 'TLSv1_2',
    tls_options => {SSL_verify_mode => 0x00},
  });
  $redis->db->connection->_connect;
  is $args->{tls},         1,          'tls enabled';
  is $args->{tls_verify},  0x00,       'tls_verify passed';
  is $args->{tls_version}, 'TLSv1_2', 'tls_version passed';
  is_deeply $args->{tls_options}, {SSL_verify_mode => 0x00}, 'tls_options hashref passed';
};

subtest 'tls attribute on Connection matches Redis' => sub {
  my $redis = Mojo::Redis->new('redis://localhost:6379', tls => {tls_ca => '/ca.crt'});
  my $conn  = $redis->db->connection;
  is_deeply $conn->tls, {tls_ca => '/ca.crt'}, 'tls attribute passed through to connection';
};

done_testing;
