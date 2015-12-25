module.exports = {
	SteamAccounts: [],	// add 64-bit Steam Account ID's (as String) of users that should receive reports
	SteamGroup: null,	// SteamGroup to send message to
	logOnOptions: {		// add account credentials; see README.md
		account_name: '',
		password: '',
		auth_code: '', // only used if steam guard key is required. After that sentry file is created.
		sha_sentryfile: 'sentry'
	},
	listenPort: 9876,	// port to listen on, must be the same as in the SourceMod plugin
	reportPassword: '',	// required password, must be the same as in the SourceMod plugin
};
