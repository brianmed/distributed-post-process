package SparksAndMagic;

use Mojo::Base 'Mojolicious';

sub site_dir
{
    state $site_dir = shift;
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

    $self->plugin(AccessLog => {uname_helper => 'set_username', log => "$$site_config{site_dir}/docroot/sparks_and_magic/log/access.log", format => '%h %l %u %t "%r" %>s %b %D "%{Referer}i" "%{User-Agent}i"'});
    $self->plugin(tt_renderer => {template_options => {CACHE_SIZE => 0, COMPILE_EXT => undef, COMPILE_DIR => undef}});
    
    $self->renderer->default_handler('tt');
    
    $self->secrets([$$site_config{site_secret}]);
    
    # Router
    my $r = $self->routes;

    my $logged_in = $r->under (sub {
        my $self = shift;

        if (!$self->session("account_id")) {
            my $url = $self->url_for('/');
            return($self->redirect_to($url));
        }
        else {
             $self->set_username($self->session("account_id"));
        }
    });
    
    $r->get('/')->to(controller => 'Index', action => 'slash');

    $r->get('/login')->to(controller => 'Index', action => 'slash');
    $r->post('/login')->to(controller => 'Index', action => 'login');

    $r->get('/signup')->to(controller => 'Index', action => 'signup');
    $r->post('/signup')->to(controller => 'Index', action => 'signup');
}

1;
