# Ghouls 'n' Ghosts Crowd Control

The goal of this project is to create a "crowd control" mod for Daimakaimura / Ghouls 'n' Ghosts on MAME.  
The idea of a crowd control mod is allowing stream viewers to trigger certain in-game effects.

## Features

### Currently supported Effects
- Set weapon
- Set armour (naked, steel, gold)
- Transform arthur into a duck
- Transform arthur into an old man
- Transform arthur as usual (turns into a duck or old man depending on current armour state)
- Give invincibility for n seconds
- Set in-game "rank" (difficulty setting)
- Set arthur's run speed
- Set arthur's jump height
- Set in-game timer
- Damage arthur
- Kill arthur instantly

### TODO
- Create middleware to send effect triggers to plugin
  - Integrate with Streamlabs donation API
  - Look into integrating with Twitch APIs?
    - Trigger effects using bits
    - Trigger effects using channel points
  - Create donation "menu" frontend
    - Display all available effects and their costs
    - Display effect cooldowns
    - Display effect queue?
  - Manage effect cooldowns
  - Manage dynamic effect costs

## System design

Components:
- MAME plugin
- Node.js middleware
- React frontend
- Integration with twitch/streamlabs APIs

### MAME Plugin

The `daimakaimuracc` MAME plugin will be executing all effects.  It is a LUA script that has read/write access to game memory and communicates with the middleware app over a socket connection.

### Node.js Middleware

The middleware app acts as a proxy between the MAME plugin and the donation API(s).  It will serve data to the frontend using Express.

### React frontend

The React frontend will connect to the middleware and render a "donation menu" that can be displayed on stream.