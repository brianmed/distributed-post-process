package SparksAndMagic::Controller::Dashboard;

use Mojo::Base 'Mojolicious::Controller';

use Mojo::Util qw(slurp spurt b64_encode);
use Mojo::JSON qw(encode_json decode_json);

sub show {
    my $c = shift;

    my $username = $c->session("username");

    my $site_dir = $c->site_dir;
    my $bytes = slurp("$site_dir/users/$username/metadata");
    my $user = decode_json($bytes);

    warn($c->dumper($user));
    
    $c->stash("username", $user->{username});
    $c->stash("api_key", $user->{api_key});

    $c->render;
}

1;
