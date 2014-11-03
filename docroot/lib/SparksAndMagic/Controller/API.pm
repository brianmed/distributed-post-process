package SparksAndMagic::Controller::API;

use Mojo::Base 'Mojolicious::Controller';

use Mojo::Util qw(slurp spurt b64_encode b64_decode);
use Mojo::JSON qw(encode_json decode_json);
use File::Copy;
use File::Basename;
use File::Temp;

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

    if (!defined $jpeg) {
        return $c->render(json => {status => "finished", data => { message => "Seems all processing is done" }});
    }

    if ("-1" eq $jpeg) {
        return $c->render(json => {status => "error", data => { message => "Unable to create inprogress directory" }});
    }

    my $path = "$site_dir/inprogress/$username/$jpeg";
    $c->render(json => {status => "ok", data => { message => "Sending $jpeg", filename => $jpeg, base64 => b64_encode(slurp($path), "")}});
}

sub gray {
    my $c = shift;

    my $site_dir = $c->site_dir;
    my $username = $c->req->json->{username};

    unless (-d "$site_dir/inprogress/$username") {
        return($c->render(json => {status => "error", data => { message => "Nothing inprogress found" }}));
    }

    return($c->render(json => {status => "error", data => { message => "No bytes found" }})) unless $c->req->json->{bytes};

    my ($fh, $filename) = File::Temp::tempfile("grayXXXXXX", TMPDIR => 1, SUFFIX => '.jpg', UNLINK => 0);
    print($fh b64_decode($c->req->json->{bytes}));
    close($fh);

    my $identify = `/usr/bin/identify $filename`;
    
    unless ($identify) {
        return($c->render(json => {status => "error", data => { message => "Unable to identify grayscale image." }}));
    }

    unless ($identify =~ m/JPEG/) {
        return($c->render(json => {status => "error", data => { message => "JPEG not detected" }}));
    }
    unless ($identify =~ m/1280x720/) {
        return($c->render(json => {status => "error", data => { message => "1280x720 not detected" }}));
    }

    my ($inprogress) = glob("$site_dir/inprogress/$username/image*.jpg");
    my $jpeg = basename($inprogress);
    my $gray = $jpeg;
    $gray =~ s#image#gray#;

    mkdir("$site_dir/gray/$username");
    mkdir("$site_dir/done/$username");
    File::Copy::move($filename, "$site_dir/gray/$username/$gray");
    File::Copy::move($inprogress, "$site_dir/done/$username/$jpeg");

    rmdir("$site_dir/inprogress/$username");

    $c->render(json => {status => "ok", data => { message => "Thank you." }});
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
