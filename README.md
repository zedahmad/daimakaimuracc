# Ghouls 'n' Ghosts Crowd Control

The goal of this project is to create a "crowd control" mod for Daimakaimura / Ghouls 'n' Ghosts on MAME.  
The idea of a crowd control mod is allowing stream viewers to trigger certain in-game effects.

## Features

### Currently supported Effects
- Set/randomize weapon
- Set/increment/decrement armour (naked, steel, gold)
- Transform arthur into a duck for n seconds
- Transform arthur into an old man for n seconds
- Transform arthur as usual (turns into a duck or old man depending on current armour state)
- Give invincibility for n seconds
- Set/randomize/increment/decrement/max/min in-game "rank" (difficulty setting)
- Set arthur's run speed for n seconds
- Set arthur's jump height for n seconds
- Set gravity for n seconds
- Set/decrement in-game timer
- Damage arthur
- Kill arthur instantly

### TODO
- [x] Create middleware to send effect triggers to plugin
  - [ ] Integrate with Streamlabs donation API
  - [ ] Look into integrating with Twitch APIs?
    - [ ] Trigger effects using bits
    - [ ] Trigger effects using channel points
  - [x] Create donation "menu" frontend
    - [x] Display all available effects and their costs
    - [ ] Display effect cooldowns
    - [ ] Display effect queue?
  - [ ] Manage effect cooldowns
  - [x] Manage dynamic effect costs

## System design

Components:
- MAME plugin
- Node.js middleware
- React frontend
- Integration with twitch/streamlabs APIs

### MAME Plugin

The `daimakaimuracc` MAME plugin will be executing all effects.  It is a LUA script that has read/write access to game memory and communicates with the middleware app over a socket connection.

### Node.js Middleware

The middleware app acts as a proxy between the MAME plugin and the donation API(s).  It also serves data to the menu frontend.

### React frontend

The React frontend will connect to the middleware and render a "donation menu" that can be displayed on stream.

## Usage

### 0. Requirements

- Node.js
- MAME 0.251 or later
- Daimakaimura ROM (`daimakai.zip`)

### 1. Installing the MAME plugin

1. Copy the contents of the `mame` directory from the root of the project into your MAME installation folder
2. When prompted, replace all existing files
3. Navigate to `<MAME installation>/plugins/daimakaimuracc/` and open the file `init.lua` in a text editor
4. Adjust configuration as necessary  
   - To test whether the plugin works without needing to set up the other components, set `useNetwork` to `false` and `chaosMode` to `true`.  This will trigger random effects periodically.
5. Launch MAME from a terminal using the following command: `mame.exe daimakai -plugin daimakaimuracc`

### 2. Installing the middleware

1. In a terminal, navigate to the `api` directory from the root of the project
2. Run `npm install`
3. Run `npm run start`
4. Test whether the middleware is running successfully
   1. In your browser, visit [http://localhost:3080/deathprice](http://localhost:3080/deathprice)
   2. It should return "1"
5. Launch MAME using the previous command
   - Note: it is important that the middleware is running _before_ MAME. 
6. In the terminal window that you launched the middleware from, you should see it responding to MAME with a "Connected" message
7. Test whether the middleware is able to successfully send commands to MAME
   1. In MAME, insert some coins
   2. In your browser, visit [http://localhost:3080/sendData/16](http://localhost:3080/sendData/16)
   3. In the terminal window that you launched the middleware from, you should see "Sending ID 16 to client"
   4. In MAME, start the game
   5. As soon as you have control over Arthur, you should see the Death effect trigger

### 3. Installing the frontend

1. In a terminal, navigate to the `frontend` directory from the root of the project
2. Run `npm install`
3. Run `npm run start`
4. Test whether the frontend is running successfully
   1. In OBS, add a new browser source
   2. Set the URL to [http://localhost:3001](http://localhost:3001)
   3. The browser source should be rendering a GnGCC donation menu
5. Test whether the frontend is able to communicate with the middleware
   1. In your browser, visit [http://localhost:3080/sendData/16](http://localhost:3080/sendData/16) to trigger the Death effect again
   2. In the donation menu in OBS, you should see the listed price of the Death effect increase
6. To adjust the layout, style or prices of the menu, see `/frontend/src/App.js`

### 4. Usage in a live setting

Currently, the middleware does not receive requests from any donation APIs.  This means that any effects redeemed must be triggered manually for now.  

To trigger effects, an HTTP request must be sent to the middleware server at `/sendData/:effectId`.  With the default config, and the death effect, this would look like: [http://localhost:3080/sendData/16](http://localhost:3080/sendData/16).  Below is a full list of available effects sorted by their ID.  
1. Random Weapon
2. Downgrade Armour
3. Upgrade Armour
4. Fast Run
5. Slow Run
6. High Jump
7. Low Jump
8. Duck Transformation
9. Old Man Transformation
10. Invincibility
11. Subtract Time
12. Random Rank
13. Increase Rank
14. Decrease Rank
15. Max Rank
16. Death
17. Low Gravity
18. Min Rank


- Elgato Stream Deck
  - Configure each effect as a "System" -> "Website" button
  - Set the URL to the `/sendData/:effectId` endpoint of the middleware.
  - Enable the "GET request in background" option
  - Repeat this process for each effect you would like to be able to trigger from your Stream Deck.
- Browser bookmarks
  - A bookmark can be created for each effect that will trigger the effect when it is visited.
  - You may be able to trigger these bookmarks from a device other than the computer running the middleware server and game, such as another computer or a smartphone.
    - The devices must be on the same network
    - Replace `localhost` in your effect URLs with the local IP of the computer running the middleware server 