---
area: server
type: fixed
audience: admins
title: Remote console shutdown no longer blocks server management
---
Graceful shutdown through the remote console releases pending console requests so the manager can stop the worldserver and switch realms reliably.
