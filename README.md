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

Below is the reason I updated this addon in the first place.  This is my favorite feature.  It will save a ton of time.  
👉 The addon calculates the maximum you can buy based on:

✅ Unity Accolades available
✅ Free inventory slots
✅ Remaining space in existing stacks
✅ Weekly cap 
