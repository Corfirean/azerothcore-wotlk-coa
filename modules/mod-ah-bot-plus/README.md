# Auction House Bot Plus

Fills the auction house with listings and optionally buys from players. Vendored from
[NathanHandley/mod-ah-bot-plus](https://github.com/NathanHandley/mod-ah-bot-plus) (AzerothCore AGPL-3.0 headers in each file);
see the upstream README for every setting.

It does nothing until configured: `AuctionHouseBot.GUIDs` stays 0 and `AuctionHouseBot.EnableSeller = false`.
To use it, make a normal (not bot) character, put its guid into `AuctionHouseBot.GUIDs` and enable the seller.
The CoA item tables hold hundreds of thousands of generated entries, so set `AuctionHouseBot.ListedItemIDRestrict.*`
or the item level limits before enabling it, or the bot will list items nobody should see.
