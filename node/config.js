module.exports = {
	SteamAccounts: [''],	// add 64-bit Steam Account ID's (as String) of users that should receive reports
	logOnOptions: {		// add account credentials; see README.md
		accountName: '',
		password: '',
		authCode: '',
		shaSentryfile: 'sentry'
	},
	listenPort: 9876,	// port to listen on, must be the same as in the SourceMod plugin
	reportPassword: '',	// required password, must be the same as in the SourceMod plugin
};