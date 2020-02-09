#!/usr/bin/perl -w

use strict;
use AnyEvent::Discord::Client;
use Data::Dumper qw(Dumper);
use Encode qw(encode_utf8);
use JSON::MaybeXS qw(encode_json);
use Digest::MD5 qw(md5_hex);
use Config::Tiny;
binmode(STDOUT, "encoding(UTF-8)");

my $config = Config::Tiny->read( "blamebot.ini", 'utf8' ); 
my $token = $config->{bot}{token};
my $lhost = $config->{server}{url};
my %commands_hidden;

my %help = (
	help => "
   Commands    |    Description
---------------+-----------------------------
admin          | Admin functions within blamebot.
ark            | Sends commands to arkmanager.
donate         | Display donation link.
minecraft      | Sends commands to minecraft.
quote          | Display random quote.
weather <zip>  | Utilizes wttr.in to display weather.

To see more information on a command type !blame help <command>

To-do:
 + Add mutex lock to ark update function
 + Raid team list
 + Ark RCON
 + Minecraft RCON
 + Change system() functions to something perl native
",

	admin => "
Option <param> |    Description
---------------+----------------------------- 
add <userid>   | Adds admin by userid. REQUIRES OP. 
remove <userid>| Removed admin by userid. REQUIRES OP.
list           | Lists admins by userid. REQUIRES OP. No way to convert to Username.

The user ID can be obtained from right clicking on a user and selecting Copy ID in discord.",

	ark => "
Option <param> |    Description
---------------+-----------------------------
checkupdate    | Checks for server and mod updates (takes 5-10m)
               | Updates found will be processed in the backgroun.
               | Capt. Hook will have notifications.
currentrelease | Lists build IDs for both server/client from SteamDB.
players        | List players connected to ARK.
start          | Starts server. REQUIRES OP.
status         | Displays Ark server status
stop           | Stops server. REQUIRES OP.
restart        | Restarts server. REQUIRES OP.
updatehistory  | Lists 10 most recent updates installed.",

	minecraft => "
Option <param> |    Description
---------------+-----------------------------
status         | Displays Minecraft server status.",

	quote => "
No additional options. Displays random quote.",

	weather => "
Usage: !blame weather <zip or location>
Outputs weather in nice PNG."
);

sub isauthed
{
	open(FILE,"blamebotadmin");
	if (grep{/$_[0]/} <FILE>){
		return(1);
	}else{
		return(0);
	}
	close FILE;

}

sub posttodiscord
{
        my ($channel, $message) = @_;
	my $encoded;

	if ( length($message) > 1994 )
	{
	        my $digest = md5_hex(localtime(time));
	        my $of = "/var/www/html/$digest";
	        open (FILE, ">> $of") || die "problem opening $of\n";
	        print FILE $message;
	        close(FILE);
	        my $uid = getpwnam "www-data";
	        my $gid = getgrnam "www-data";
	        chown $uid, $gid, $of;
		my $link = $lhost . $digest;
	        my $output = {content => "```" . "Output exceeds 2000 chars. Link will self destruct in 10 minutes\n Link: $link". "```"};
	        $encoded = encode_utf8(encode_json($output));
	        system("echo \"rm /var/www/html/$digest\" | at now + 10 minutes");
	}
	else
	{
	        my $output = {content => "```" . $message . "```"};
	        $encoded = encode_utf8(encode_json($output));
	}
	

        my $url = "https://discordapp.com/api/channels/" . $channel . "/messages";
        my $ua = LWP::UserAgent->new( 'send_te' => '0' );
        my $r  = HTTP::Request->new(
                'POST' => $url,
                [
                        'Accept' => '*/*',
                        'Authorization'  => "Bot $token",
                        'Host'           => 'discordapp.com:443',
                        'User-Agent'     => 'Mozilla/5.0',
                        'Content-Type'   => 'application/json',
                ],
                $encoded
        );
        my $res = $ua->request( $r, );
}
 
my $bot = new AnyEvent::Discord::Client(
  token => $token,
  commands => {
    'commands' => sub {
      my ($bot, $args, $msg, $channel, $guild) = @_;
      $bot->say($channel->{id}, join("   ", map {"`$_`"} sort grep {!$commands_hidden{$_}} keys %{$bot->commands}));
    },
  },
);
 
$bot->add_commands(
  'hello' => sub {
    my ($bot, $args, $msg, $channel, $guild) = @_;
 
    $bot->say($channel->{id}, "hi, $msg->{author}{username}!");
  },
  'blame' => sub {
    my ($bot, $args, $msg, $channel, $guild) = @_;
    my @message = split( /\s+/, $msg->{content} );

	my $output = "";

        if ( $message[1] eq "help") {
        	if ( !defined($message[2]) )
		{
			$output = "```plaintext\n" . $help{help} . "```";
		}
		elsif ( defined($help{$message[2]}) )
		{
			$output = "```plantext\n" . $help{$message[2]} . "```";
		}
        }
	if ( $message[1] eq "donate" )
	{
		$output = "Server donations can be made via paypal here: http://paypal.me/chingadera
Buy your admin a beer, pizza, and server hardware to bring you a better gaming experience.";
	}
        if ( $message[1] eq "ark" )
        {
		if ( $message[2] eq "start" && isauthed($msg->{author}{id}) )
		{
			$output = "```\n" . `arkmanager start` . "```";
		}
		if ( $message[2] eq "stop" && isauthed($msg->{author}{id}) )
		{
			$output = "```\n" . `arkmanager stop --warn` . "```";
		}
		if ( $message[3] eq "restart" && isauthed($msg->{author}{id}) )
		{
			$output = "```\n" . `arkmanager restart --warnreason` . "```";
		} 
	        if ( $message[2] eq "status" )
	        {
	                $output = "```\n" . `arkmanager status | ansi2txt | awk '{\$1=\$1}1' | sed -n '2p;4p;5p;6p;8p'` . "```";
	        }
	        elsif ( $message[2] eq "players" )
	        {
	        	$output = "```\n" . `arkmanager rconcmd "listplayers" | ansi2txt` . "```";
	        }
	        elsif ( $message[2] eq "checkupdate" )
	        {
                        my $pid = fork;
                        die "failed to fork: $!" unless defined $pid;
                        if ($pid == 0)
                        {
				my $update;
                        	my $mod;
				posttodiscord($channel->{id}, "Checking for update. May take a while.");

				#$output = "```";
	                        $output = `arkmanager checkupdate`;
	                        $update = $? >> 8;
	                        $output .= `arkmanager checkmodupdate --revstatus`;
	                        #$output .= "```";
	                        $output =~ s/\x1B(\[[0-9;]*[JKmsu]|\(B)//g;
	                        $output =~ s/\x1B[7-8]//g;
				posttodiscord($channel->{id}, $output);
			
				$mod = $? >> 8;
	                        if ( $update == 1 || $mod == 1 )
	                        {
	                                posttodiscord($channel->{id}, "Update detected, automagically running update in background.");
					my $stdout = `echo \$(date -u) >> arkmanager.log; arkmanager update --warn --update-mods`;
					posttodiscord($channel->{id}, $stdout) unless !length($stdout);
	                        }
                                exit;
                        }
		}
		elsif ( $message[2] eq "updatehistory" )
		{
			$output = "```\n" . `grep \"Update to\\|updated\" /var/log/arktools/arkmanager.log \| tail -n 10` . "```";
		}
		elsif ( $message[2] eq "currentrelease" )
		{
			$output = "```";
			$output .= "Build IDs as reported from the Steam API\n";
			$output .= "Server: " . `/usr/games/steamcmd +login anonymous +app_info_print 376030 +quit | grep "buildid" | head -n 1 | awk '{print \$2}'`;
			$output .= "   https://steamdb.info/app/376030/depots/?branch=public \n";
			$output .= "Host (Desktop Game): " . `/usr/games/steamcmd +login anonymous +app_info_print 346110 +quit | grep "buildid" | head -n 1 | awk '{print \$2}'`;
			$output .= "   https://steamdb.info/app/346110/depots/?branch=public \n";
			$output .= "```";
		}
	}
	if ( $message[1] eq "minecraft" )
	{
		if ( $message[2] eq "status" )
		{
			$output = "```\n" . `/etc/init.d/minecraft status` . "```";
		}
	}
	if ( $message[1] eq "bash" )
	{
		if ( $msg->{author}{id} eq '208359149359071233' && $msg->{author}{discriminator} eq '0060' )
		{
			my $pid = fork;
	                die "failed to fork: $!" unless defined $pid;
	                if ($pid == 0)
			{
        	                my $stdout = `@message[2..$#message]`;
	                        posttodiscord($channel->{id}, $stdout) unless !length($stdout);
	                        exit;
	                }
		}
	}
	if ( $message[1] eq "weather" )
	{
		$output = "http://wttr.in/" . join('%20', @message[2..$#message]) . ".png";
	}
	if ( $message[1] eq "quote" )
	{
		$output = "```\n" . `/usr/games/fortune | /usr/games/cowsay -f \$(ls /usr/share/cowsay/cows/ | shuf -n1)` . "```";
	}
	if ( $message[1] eq "admin" && isauthed($msg->{author}{id}) )
	{
		if ( $message[2] eq "add" && defined($message[3]) && $message[3] =~ /^[0-9]*$/ && !isauthed($message[3]) )
		{
			system "echo $message[3] >> blamebotadmin";
			$output = "admin added";
		}
		elsif ( $message[2] eq "remove" && defined($message[3]) && $message[3] =~ /^[0-9]*$/ && isauthed($message[3]) )
		{
			system "sed -i '/$message[3]/d' blamebotadmin";
			$output = "admin removed";
		}
		elsif ( $message[2] eq "list" )
		{
			$output = "```\n" . `cat blamebotadmin` . "```";
		}
	}
	elsif ( $message[1] eq "admin" && !isauthed($msg->{author}{id}) )
	{
		$output = "not authorized";
	}
	if (defined($output)) { $bot->say($channel->{id}, $output); undef $output; }
  },
);
$bot->connect();
AnyEvent->condvar->recv;
