@feature: Search Hotels
Feature: Search Hotels

Scenario Outline: Search hotels with an invaild city
 Given As a room user, I launch room app
 When I search hotels with VALUE as "<VALUE>"
 And click on search button
 Then I should see "<ERROR>" alert

@env:test
   Examples:
	| VALUE  | ERROR				|
	| sgfgfs | Please type in a location		|