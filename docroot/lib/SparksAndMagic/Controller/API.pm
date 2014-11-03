package SparksAndMagic::Controller::API;

use Mojo::Base 'Mojolicious::Controller';

use Mojo::Util qw(slurp spurt b64_encode);
use Mojo::JSON qw(encode_json decode_json);
use File::Copy;
use File::Basename;

sub post {
    my $c = shift;

    $c->render(json => {status => "error", data => { message => "Use POST" }});
}

sub jpeg {
    my $c = shift;

    my $site_dir = $c->site_dir;
    my $username = $c->req->json->{username};

    if (-d "$site_dir/inprogress/$username") {
        my ($path) = glob("$site_dir/inprogress/$username/image*.jpg");
        my $jpeg = basename($path);
        $c->render(json => {status => "ok", data => { message => "Sending $jpeg", filename => $jpeg, base64 => b64_encode(slurp($path), "")}});
        return;
    }

    my $jpeg = $c->next_jpeg($username);

    if ("-1" eq $jpeg) {
        return $c->render(json => {status => "error", data => { message => "Unable to create inprogress directory" }});
    }

    my $path = "$site_dir/inprogress/$username/$jpeg";
    $c->render(json => {status => "ok", data => { message => "Sending $jpeg", filename => $jpeg, base64 => b64_encode(slurp($path), "")}});
}

sub next_jpeg {
    my $c = shift;
    my $username = shift;

    my $site_dir = $c->site_dir;
    mkdir("$site_dir/inprogress/$username");
    unless (-d "$site_dir/inprogress/$username") {
        return("-1");
    }

    # Database? Naa.. :)
    my $found;
    opendir(my $dh, "$site_dir/jpegs");
    while (readdir($dh)) {
        my $file = $_;
        if ($file =~ /image\d+.jpg/) {
            eval {
                File::Copy::move("$site_dir/jpegs/$file", "$site_dir/inprogress/$username");
            };
            if ($@) {
                unless (-f "$site_dir/inprogress/$username/$file") {
                    continue;  # someone else may have gotten the file
                }
            }

            $found = $file;
            last;
        }
    }
    closedir($dh);

    return($found);
}

1;
