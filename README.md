# blamebot
Perl discord bot that utilizes anyevent::discord::client

This started as a way for my guild members in discord to check for and run updates on my ark server (even though I have a cron job that does it).
I figured I needed an interface between discord and my server anyways.

## Prerequisites ##
Perl libraries
`cpanm AnyEvent::Discord::Client Data::Dumper Encode JSON::MaybeXS Digest::MD5 Config::Tiny`

System packages
`apt-get install at kbtin steamcmd fortune cowsay`

Ark Server tools
https://github.com/FezVrasta/ark-server-tools

Minecraft
Minecraft init script is available to download.

Tiny::Config will use a config.ini file that should look something like this:
```
[bot]
token = yourtokenhere

[server]
url = http://your.local.httpd/
```

Output that is longer than discords 2000 limit is put into my www directory with an expire time of 10 minutes.
Personal pastebin of sorts.

Your bot token you get from the discord developer portal.
