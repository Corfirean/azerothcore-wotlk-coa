---
area: server
type: fixed
audience: admins
title: Disabled SquidBots no longer require their database to start the server
---
The server skips registering SquidBots when their master switch is off. Enabling or disabling the module takes effect after a world-server restart; upstream module sources remain unchanged.
