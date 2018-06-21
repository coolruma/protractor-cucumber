var p = require('relative-path');
var chai = require('chai');
var chaiAsPromised = require('chai-as-promised');
chai.use(chaiAsPromised);
var expect = chai.expect;
var homePage = require(p('../pages/homePage'));
var EC = protractor.ExpectedConditions;
var ptor = protractor;

var myStepDefinitionsWrapper = function() {

	this.Given(/^As a room user, I launch room app$/, function(callback) {
		// Write code here that turns the phrase above into concrete actions
		browser.get("https://www.room77.com").then(function() {
			callback();
		});
	});

	this.When(/^I search hotels with VALUE as "([^"]*)"$/, function(city,
			callback) {
		// Write code here that turns the phrase above into concrete actions
		browser.wait(EC.elementToBeClickable(element(homePage.enterSearch)),
				30000);
		element(homePage.enterSearch).sendKeys(city);
		callback();
	});

	this.When(/^click on search button$/, function(callback) {
		// Write code here that turns the phrase above into concrete actions
		browser.wait(function() {
			return element(homePage.clickSearch).isDisplayed();
		}, 10000).then(function() {
			element(homePage.clickSearch).click().then(function() {
				callback();
			});
		});
	});

	this.Then(/^I should see "([^"]*)" alert$/, function(error, callback) {
		// Write code here that turns the phrase above into concrete actions
		browser.sleep(1000);
		browser.switchTo().alert().then(function(alert, value) {
			alert.accept();
			callback();
		});
	});
};
module.exports = myStepDefinitionsWrapper;