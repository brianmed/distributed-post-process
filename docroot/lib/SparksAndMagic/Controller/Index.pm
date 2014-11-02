package SparksAndMagic::Controller::Index;

use Mojo::Base 'Mojolicious::Controller';

use Mojo::Util qw(slurp spurt b64_encode);
use Mojo::JSON qw(encode_json);

use Crypt::Eksblowfish::Bcrypt;
use Email::Valid;

sub slash {
    my $c = shift;

    if ($c->session->{account_id}) {
        my $url = $c->url_for('/dashboard');
        return($c->redirect_to($url));
    }

    $c->render;
}

sub login {
    my $c = shift;

    my ($username, $password) = $c->param(['username', 'password']);

    if ($username) {
        $c->stash(username => $username);
    }

    my $site_dir = $c->site_dir;
    unless (-d "$site_dir/users/$username") {
        $c->stash(error => "Credentials mis-match");

        return($c->render(template => "index/slash"));
    }

    my $bytes = slurp("$site_dir/users/$username/metadata");
    my $user = decode_json($bytes);

    unless ($c->check_password($password, $user->{password})) {
        $c->stash(error => "Credentials mis-match");

        return($c->render(template => "index/slash"));
    }

    $c->render(template => "index/slash");
}

sub signup {
    my $c = shift;

    if ("GET" eq $c->req->method) {
        return($c->render());
    }

    my ($username, $password, $v_password, $email) = $c->param(['username', 'password', 'v_password', 'email']);

    my $site_dir = $c->site_dir;

    unless ($username =~ m#^[\w]+$#) {
        $c->stash(error => "Username not valid");

        return($c->render);
    }

    if (3 > length($username)) {
        $c->stash(error => "Username length too small");

        return($c->render);
    }

    if (-d "$site_dir/users/$username") {
        $c->stash(error => "Username already taken");

        return($c->render);
    }

    if ($password ne $v_password) {
        $c->stash(error => "Passwords must match");

        return($c->render);
    }

    if (8 > length($password)) {
        $c->stash(error => "Password needs to be at least 8 characters");

        return($c->render);
    }

    unless (Email::Valid->address($email)) {
        $c->stash(error => "Email doesn't seem to valid");

        return($c->render);
    }

    unless (-d "$site_dir/users/$username") {
        $c->stash(error => "Username not found");

        return($c->render);
    }

    mkdir("$site_dir/users/$username");
    my $bytes = encode_json({
        username => $username,
        password => $c->hash_password($password),
        api_key => b64_encode(scalar(localtime(time)) . "::" . $$ . "::" . int(rand(10_000))),
    });
    spurt($bytes, "$site_dir/users/$username/metadata");

    $c->render;
}

# http://www.eiboeck.de/blog/2012-09-11-hash-your-passwords

sub check_password { 
    my $self = shift;

    return(0) if !defined $_[0];
    return(0) if !defined $_[1];

    my $hash = $self->hash_password($_[0], $_[1]);

    return($hash eq $_[1]);
}

sub hash_password {
    my $self = shift;

	my ($plain_text, $settings_str) = @_;

    unless ($settings_str) {
        my $cost = 10;
        my $nul  = 'a';
         
        $cost = sprintf("%02i", 0+$cost);

        my $settings_base = join('','$2',$nul,'$',$cost, '$');

        my $salt = join('', map { chr(int(rand(256))) } 1 .. 16);
        $salt = Crypt::Eksblowfish::Bcrypt::en_base64( $salt );
        $settings_str = $settings_base.$salt;
    }

	return Crypt::Eksblowfish::Bcrypt::bcrypt($plain_text, $settings_str);
}

1;
