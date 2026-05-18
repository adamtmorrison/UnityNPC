# UnityNPC
A small windower addon to bypass slow client ui when interacting with a Unity NPC.

Action                | Addon Command
--------------------- | -----------------------------
Load                  | //lua l unitynpc
Reload                | //lua r unitynpc
Unload                | //lua u unitynpc
Warp                  | //unpc warp \<zone\>
Buy                   | //unpc buy \<item\> \<count\> OR all

Aliases:

Action                                        | Addon Command
--------------------------------------------- | -----------------------------
Buy SP Gobbie Key                             | //buykeys \<count\>
Buy Prize Powder                              | //buypowder \<count\>
Buy Prize All Powder                          | //buypowder all
Buy Warp Scroll                               | //buywarp
Show current accolades                        | //unpc accolades
Set current spent accolades                   | //unpc setspent \<count\> - In case you load the addon mid-week.  
Add a number of accolades to your spent total | //unpc addspent <\count\> - Make a quick adjustments
UnityNPC help commands                        | //unpc help or //unpc ?

\<zone\> should be replaced with zone names (you can use the in-game auto-translate feature).  
\<item\> should be replaced with item names from [data/items.lua](https://github.com/Tny5989/UnityNPC/blob/master/data/items.lua)  

This addon will track your total number of accolades spent this week and automatically resets it to 100,000 at JSP midnight, or if JSP midnight
has occurred since you last logged in.  

When using the "all" command, this addon checks your accolades and calculates the total number you can purchase based on the total number spent for the week, your total available accolades, and your inventory space.  

As with all my addons, this is still a work in progress and should be used at your own risk.
