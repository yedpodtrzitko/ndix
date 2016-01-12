# Nuclear Dawn Server Stack

## Components

* ansible

This directory contains tools for deploying dedicated server for Nuclear Dawn on Linux.
You can basically boostrap (and/or update) the server from zero with a single script.
For more See README in the ansible directory


* deploy_eventserver

This is the structure you want to deploy for a planned game event.
It does not contain some non-event things (eg. balancer), and contain some event things (eg. teampicker)


* deploy_server

This is the structure you want to deploy for a normal server. 
It contains all plugins and configs for fully tuned server.


* manage  

a template for rcon management console

* plugins

working directory for each scripts

* scripts

helper scripts for local deveploment and deployment

* server_cfg

a template of tuned server config (+ sync script)