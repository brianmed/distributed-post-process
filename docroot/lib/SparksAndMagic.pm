package SparksAndMagic;

use Mojo::Base 'Mojolicious';

use Mojo::Util qw(slurp spurt b64_encode);
use Mojo::JSON qw(encode_json decode_json);

sub site_dir
{
    state $site_dir = pop;
}

sub site_config
{
    state $site_config = pop;
}

sub startup
{
    my $self = shift;

    $self->log->level("debug");

    my $site_config = $self->plugin("Config" => {file => '/opt/magic'});
    $self->helper(site_dir => \&site_dir);
    $self->helper(site_config => \&site_config);
    $self->site_dir($$site_config{site_dir});
    $self->site_config($site_config);

    my $listen = [];
    push(@{ $listen }, "http://$$site_config{hypnotoad_ip}:$$site_config{hypnotoad_port}");
    # push(@{ $listen }, "https://$$site_config{hypnotoad_ip}:$$site_config{hypnotoad_tls}");

    $self->config(hypnotoad => {listen => $listen, workers => $$site_config{hypnotoad_workers}, user => $$site_config{user}, group => $$site_config{group}, inactivity_timeout => 15, heartbeat_timeout => 15, heartbeat_interval => 15, accepts => 100});

    $self->plugin(AccessLog => {uname_helper => 'set_username', log => "$$site_config{site_dir}/docroot/log/access.log", format => '%h %l %u %t "%r" %>s %b %D "%{Referer}i" "%{User-Agent}i"'});

    # $self->plugin(tt_renderer => {template_options => {CACHE_SIZE => 0, COMPILE_EXT => undef, COMPILE_DIR => undef}});
    # $self->renderer->default_handler('tt');
    
    $self->secrets([$$site_config{site_secret}]);
    
    # Router
    my $r = $self->routes;

    my $logged_in = $r->under (sub {
        my $self = shift;

        if (!$self->session("username")) {
            my $url = $self->url_for('/');
            $self->redirect_to($url);

            return undef;
        }
        else {
            my $site_dir = $self->site_dir;
            my $username = $self->session("username");
            my $bytes = slurp("$site_dir/users/$username/metadata");
            my $user = decode_json($bytes);

            if ($username ne $user->{username}) {
                $self->flash("error", "Clerical error");

                my $url = $self->url_for('/');
                $self->redirect_to($url);

                return undef;
            }
            else {
                $self->set_username($self->session("username"));

                return 1;
            }
        }
    });

    my $api = $r->under (sub {
        my $self = shift;

        return($self->render(json => {status => "error", data => { message => "No JSON found" }})) unless $self->req->json;

        my $site_dir = $self->site_dir;
        my $username = $self->req->json->{username};
        my $api_key = $self->req->json->{api_key};

        unless ($username) {
            $self->render(json => {status => "error", data => { message => "No username found" }});

            return undef;
        }

        unless ($api_key) {
            $self->render(json => {status => "error", data => { message => "No API Key found" }});

            return undef;
        }

        unless (-d "$site_dir/users/$username") {
            $self->render(json => {status => "error", data => { message => "Credentials mis-match" }});

            return undef;
        }

        my $bytes = slurp("$site_dir/users/$username/metadata");
        my $user = decode_json($bytes);

        if ($username ne $user->{username}) {
            $self->render(json => {status => "error", data => { message => "Clerical error" }});

            return undef;
        }
        else {
            $self->set_username($username);
        }

        unless ($api_key eq $user->{api_key}) {
            $self->render(json => {status => "error", data => { message => "Credentials mis-match" }});

            return undef;
        }

        return 1;
    });
    
    $r->get('/')->to(controller => 'Index', action => 'slash');

    $r->get('/login')->to(controller => 'Index', action => 'login');
    $r->post('/login')->to(controller => 'Index', action => 'login');

    $r->get('/signup')->to(controller => 'Index', action => 'signup');
    $r->post('/signup')->to(controller => 'Index', action => 'signup');
    $r->get('/logout')->to(controller => 'Index', action => 'logout');

    $logged_in->get('/dashboard')->to(controller => 'Dashboard', action => 'show');
    $logged_in->get('/dashboard/email')->to(controller => 'Dashboard', action => 'email');
    $logged_in->post('/dashboard/verify')->to(controller => 'Dashboard', action => 'verify');
    $logged_in->get('/dashboard/verify/:username/:verification_code')->to(controller => 'Dashboard', action => 'verify');

    $api->get('/api/v1/jpeg')->to(controller => "API", action => "post");
    $api->post('/api/v1/jpeg')->to(controller => "API", action => "jpeg");

    $api->get('/api/v1/gray')->to(controller => "API", action => "post");
    $api->post('/api/v1/gray')->to(controller => "API", action => "gray");
}

1;
