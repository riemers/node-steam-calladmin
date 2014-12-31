var fs = require('fs');
var config = require('./config');
var Steam = require('steam');
var http = require('http');
var util = require('util');

var SteamCommunity = require('steamcommunity');
var SteamID = SteamCommunity.SteamID;
var community = new SteamCommunity();

var logOnOptions = config.logOnOptions;

if (fs.existsSync(logOnOptions.sentry)) {
	logOnOptions.shaSentryfile = fs.readFileSync(logOnOptions.sentry);
} else if (logOnOptions.authCode != '') {
	logOnOptions.authCode = authCode;
}

var steamAccounts = config.SteamAccounts.slice();

var steam = new Steam.SteamClient();
var loggedOn = false;
var messageQueue = [];

steam.logOn(logOnOptions);

//steam.on('debug', console.log);
steam.on('error', console.log);

steam.on('sentry', function(sentry) {
	fs.writeFileSync(config.logOnOptions.sentry, sentry);
});

steam.on('loggedOn', function(result) {
	loggedOn = true;
	console.log('Logged in on Steam!');
	steam.setPersonaState(Steam.EPersonaState.Online);
	process.nextTick(processMessageQueue);
});

steam.on('loggedOff', function(result) {
	loggedOn = false;
	console.log('Logged off :\'( Auto-retry');
});

var syncFriends = function() {
	steamAccounts.forEach(function (steamAccount) {
		if (steam.friends[steamAccount] === undefined) {
			console.log('Adding friend '+ steamAccount);
			steam.addFriend(steamAccount);
		}
	});
};

steam.on('relationships', function() {
	// friends and groups loaded
	syncFriends();
});

steam.on('webSessionID', function(sessionID) {
	//console.log('got a new session ID:', sessionID);
	steam.webLogOn(function(cookies) {
		//console.log('got a new cookie:', cookies);
		community.setCookies(cookies);
		process.nextTick(getGroupMembers);
	});
});

http.createServer(function (req, res) {
	var body = '';
	req.on('data', function (chunk) {
		body += chunk;
	});
	req.on('end', function () {
		body = body.split('\n');
		if (body.length >= 2) {
			var last = body.pop();
			if (last == config.reportPassword) {
				if (req.url == '/report') {
					var queuedMessage = util.format('New report on server: %s (%s:%d)\nReporter: %s (%s)\nTarget: %s (%s)\nReason: %s\nJoin server: steam://connect/%s:%d', 
						body[0], body[1], body[2], body[3], body[4], body[5], body[6], body[7], body[1], body[2])
					queueMessage(queuedMessage);
				} else if (req.url == '/admin') {
					var newAdmin = body[0];
					var newAdminSteamId = new SteamID(newAdmin);
					newAdminSteamId = newAdminSteamId.getSteamID64();
					if (steamAccounts.indexOf(newAdminSteamId) == -1) {
						steamAccounts.push(newAdminSteamId);
						config.SteamAccounts.push(newAdminSteamId);		// not persistent, but necessary in order to prevent the "rescan" command from removing this person again
						syncFriends();
					}
				}
			}
		}
		res.writeHead(200, {'Content-Type': 'text/plain'});
		res.end('');
	});
}).listen(config.listenPort);
console.log('Server running on port '+ config.listenPort);

var broadcastMessage = function(message) {
	steamAccounts.forEach(function (steamAccount) {
		steam.sendMessage(steamAccount, message);
	});
	process.nextTick(processMessageQueue);
};

var processMessageQueue = function() {
	if (loggedOn) {
		if (messageQueue.length >= 1) {
			broadcastMessage(messageQueue.shift());
		}
	}
};

var queueMessage = function(message) {
	messageQueue.push(message);
	process.nextTick(processMessageQueue);
};

var getGroupMembers = function(callback) {
	console.log('Rescanning group members initiated');
	callback = callback || function(message){};
	if (config.SteamGroup !== null) {
		community.getSteamGroup(config.SteamGroup, function(err, group) {
			if (err === null) {
				group.getMembers(function(err, members) {
					if (err == null) {
						steamAccounts = config.SteamAccounts.slice();
						var ownSteamID = community.steamID.getSteamID64();
						members.forEach(function(member) {
							member = member.getSteamID64();
							if (member != ownSteamID) {
								steamAccounts.push(member);
							}
						});
						console.log('Group members:', steamAccounts);
						syncFriends();
						callback('done');
					} else {
						console.log('Error getting group members: '+ err);
						callback('Error getting group members: '+ err);
					}
				});
			} else {
				console.log('Error getting group: '+ err);
				callback('Error getting group: '+ err);
			}
		});
	}
};

steam.on('friendMsg', function(client, msg, type) {
	if (type == Steam.EChatEntryType.Emote || type == Steam.EChatEntryType.ChatMsg) {
		if (steamAccounts.indexOf(client) != -1) {
			if (msg == 'rescan') {
				steam.sendMessage(client, 'Rescanning group members...');
				process.nextTick(function() {
					getGroupMembers(function(message) {
						steam.sendMessage(client, 'Rescanning group members: '+ message);
					});
				});
			}/* else if (msg == 'close') {
				steam.logOff();
				process.exit();
			}*/
		}
	}
});