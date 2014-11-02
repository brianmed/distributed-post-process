package SparksAndMagic;

use Mojo::Base 'Mojolicious';

use Mojo::Util qw(slurp spurt b64_encode);
use Mojo::JSON qw(encode_json decode_json);

sub site_dir
{
    state $site_dir = pop;
}

sub startup
{
    my $self = shift;

    $self->log->level("debug");

    my $site_config = $self->plugin("Config" => {file => '/opt/magic'});
    $self->helper(site_dir => \&site_dir);
    $self->site_dir($$site_config{site_dir});

    my $listen = [];
    push(@{ $listen }, "http://$$site_config{hypnotoad_ip}:$$site_config{hypnotoad_port}");
    # push(@{ $listen }, "https://$$site_config{hypnotoad_ip}:$$site_config{hypnotoad_tls}");

    $self->config(hypnotoad => {listen => $listen, workers => $$site_config{hypnotoad_workers}, user => $$site_config{user}, group => $$site_config{group}, inactivity_timeout => 15, heartbeat_timeout => 15, heartbeat_interval => 15, accepts => 100});

    $self->plugin(AccessLog => {uname_helper => 'set_username', log => "$$site_config{site_dir}/docroot/log/access.log", format => '%h %l %u %t "%r" %>s %b %D "%{Referer}i" "%{User-Agent}i"'});
    $self->plugin(tt_renderer => {template_options => {CACHE_SIZE => 0, COMPILE_EXT => undef, COMPILE_DIR => undef}});
    
    $self->renderer->default_handler('tt');
    
    $self->secrets([$$site_config{site_secret}]);
    
    # Router
    my $r = $self->routes;

    my $logged_in = $r->under (sub {
        my $self = shift;

        if (!$self->session("username")) {
            my $url = $self->url_for('/');
            return($self->redirect_to($url));
        }
        else {
            my $site_dir = $self->site_dir;
            my $username = $self->session("username");
            my $bytes = slurp("$site_dir/users/$username/metadata");
            my $user = decode_json($bytes);

            if ($username ne $user->{username}) {
                $self->flash("error", "Clerical error");

                my $url = $self->url_for('/');
                return($self->redirect_to($url));
            }
            else {
                $self->set_username($self->session("username"));
            }
        }
    });
    
    $r->get('/')->to(controller => 'Index', action => 'slash');

    $r->get('/login')->to(controller => 'Index', action => 'login');
    $r->post('/login')->to(controller => 'Index', action => 'login');

    $r->get('/signup')->to(controller => 'Index', action => 'signup');
    $r->post('/signup')->to(controller => 'Index', action => 'signup');
    $r->get('/logout')->to(controller => 'Index', action => 'logout');

    $logged_in->get('/dashboard')->to(controller => 'Dashboard', action => 'show');
}

1;
