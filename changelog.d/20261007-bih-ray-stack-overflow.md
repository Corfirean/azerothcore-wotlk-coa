---
area: server
type: fixed
audience: players
title: The world server no longer crashes with many units close together
---
A line-of-sight check could write past the end of its work list and end the server process without a crash report (Windows error 0xC0000409). It now stops safely at the limit.
