global.assert  = require('assert');
global.expect  = require('chai').expect;
global.request = require('supertest');
global.faker   = require('faker');

const CoffeeScript = require('coffeescript');
CoffeeScript.register();

global.serven = require('..');

// before(function() {
// });
