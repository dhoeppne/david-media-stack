# General Sherman Media Stack

A set up docker-compose file, with a default .env and deluge config example for my Unraid server.

Based off of [htpc-download-box](https://github.com/sebgl/htpc-download-box)

## First time set up
The first time you run the docker-compose, you'll have a directory set up for you that looks like:

> `${ROOT}/complete`
>* `/movies`
>* `/tv`

> `${ROOT}/config/`
>* `deluge`
>* `jackett`
>* `plex`
>* `radarr`
>* `sonarr`
>* `vpn`

> `${ROOT}/downloads/`
>* `torrent-blackhole`
>* `complete`
>* `incomplete`

`/complete` is where your watchable downloads that plex picks up live.

`/config` is where the docker modules configs live.

`/downloads` is where deluge puts both complete and incomplete torrents.

## Caveats
`/config/vpn` will require you to create `vpn.auth` and `vpn.conf` files. Follow the guide in htpc-download-box carefully.