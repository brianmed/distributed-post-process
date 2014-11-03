package SparksAndMagic::Controller::Dashboard;

use Mojo::Base 'Mojolicious::Controller';

use Mojo::Util qw(slurp spurt b64_encode);
use Mojo::JSON qw(encode_json decode_json);

use File::Temp;
use Email::Sender::Simple qw(sendmail);
use Email::Simple;
use Email::Simple::Creator;
use Email::Sender::Transport::SMTP::TLS;

sub show {
    my $c = shift;

    my $username = $c->session("username");

    my $site_dir = $c->site_dir;
    my $bytes = slurp("$site_dir/users/$username/metadata");
    my $user = decode_json($bytes);

    $c->stash("username", $user->{username});
    $c->stash("api_key", $user->{api_key});
    $c->stash("verified", $user->{verified});
    $c->stash("url", $c->url_for("/api/v1/jpeg")->to_abs);

    if ($c->flash("error")) {
        $c->stash("error", $c->flash("error"));
    }
    if ($c->flash("success")) {
        $c->stash("success", $c->flash("success"));
    }

    $c->render;
}

sub email {
    my $c = shift;

    my $username = $c->session("username");

    my $site_dir = $c->site_dir;
    my $site_config = $c->site_config;
    my $bytes = slurp("$site_dir/users/$username/metadata");
    my $user = decode_json($bytes);
    my $md5 = $user->{verification_code};
    my $email = $user->{email};

    my $url = $c->url_for("/dashboard/verify/$username/$md5")->to_abs;

    my $mail = Email::Simple->create(
        header => [
            To     => $email,
            From    => 'signup@sparksandmagic.com',
            Subject => "Welcome to some fun",
        ],
        body => "Thank you for signing up with us.\nPlease follow the link below to verify your email address:\n\nEmail: $email\nVerification number: $md5\n\n$url\n",
    );

    my $dir = POSIX::strftime("$site_dir/emails/%F", localtime(time));
    mkdir $dir unless -d $dir;
    my ($fh, $filename) = File::Temp::tempfile("verifyXXXXX", DIR => $dir, SUFFIX => '.txt', UNLINK => 0);
    print($fh $mail->as_string);
    close($fh);

    my $transport = Email::Sender::Transport::SMTP::TLS->new({
            host => $site_config->{smtp_host},
            port => $site_config->{smtp_port},
            username => $site_config->{smtp_user},
            password => $site_config->{smtp_pass},
            timeout => 10,
    });

    eval {
        sendmail($mail, {transport => $transport });
        # sendmail($mail);
    };
    if ($@) {
        $c->app->log->debug("username: $username: " . $@);
        $c->flash("error", "Email not sent: " . scalar(localtime(time)));
    }
    else {
        $c->flash("success", "Email sent: " . scalar(localtime(time)));
    }

    $url = $c->url_for('/dashboard');
    return($c->redirect_to($url));
}

sub verify {
    my $c = shift;

    my $username = $c->session("username") || $c->param("username");

    my $site_dir = $c->site_dir;
    my $site_config = $c->site_config;
    my $bytes = slurp("$site_dir/users/$username/metadata");
    my $user = decode_json($bytes);
    my $md5 = $user->{verification_code};

    if ($md5 eq $c->param("verification_code")) {
        $user->{verified} = 1;
        my $bytes = encode_json($user);
        spurt($bytes, "$site_dir/users/$username/metadata");

        $c->flash("success", "Verificaiton succeeded");
    }
    else {
        $c->flash("error", "Verificaiton failed");
    }

    my $url = $c->url_for('/dashboard');
    return($c->redirect_to($url));
}

1;
