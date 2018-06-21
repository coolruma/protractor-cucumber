exports.config = {
    defaultTimeoutInterval: 25000,
    getPageTimeout: 60000,
    allScriptsTimeout: 500000,
    framework: 'custom',
	seleniumAddress:'http://localhost:4444/wd/hub',
		framework:'custom',
    frameworkPath: require.resolve('protractor-cucumber-framework'),
    capabilities: {
        browserName: 'chrome',
		seleniumAddress:'http://localhost:4444/wd/hub',
			maxInstances:1
    },
    specs: [
        'features/*.feature'
    ],
    baseURL: 'https://www.room77.com',
    cucumberOpts: {
        format: ['json:reports/results.json', 'pretty'],
        require: ['step_definitions/room.js','support/env.js'],
        profile: false,
			tags: false,
        'no-source': true
    }
};