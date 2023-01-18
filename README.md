# General Sherman Media Stack

A set up docker-compose file, with a default .env and qbittorrent config example for my Unraid server.

Based off of [htpc-download-box](https://github.com/sebgl/htpc-download-box)

## First time set up
The first time you run the docker-compose, you'll have a directory set up for you that looks like:

> `${ROOT}/complete`
>* `/movies`
>* `/tv`

> `${ROOT}/config/`
>* `qbittorrent`
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

`/downloads` is where qbittorrent puts both complete and incomplete torrents.

## Caveats
`/config/vpn` no longer requires a vpn config, as this repo has moved over to Wireguard. Instead, you'll be adding 3 things to your glueten section of the `docker-compose.yaml`:
1. The `WIREGUARD_PRIVATE_KEY`, which is the `PrivateKey` found in the Mullvad config file downloaded as part of creating your wireguard setup.
1. The `WIREGUARD_ADDRESSES`, which is the `Address` found in the Mullvad config file downloaded as part of creating your wireguard setup. It should follow the format `x.x.x.x/32`.
1. The `SERVER_CITIES`. In my case (at time of writing) it is `San Jose CA`. You can find all available options [here](https://github.com/qdm12/gluetun/wiki/Mullvad-servers)
