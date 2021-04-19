var assert = require('assert'),
    raymarch_utilities = require("../utility.js"),
    should = require("should");

// Attach tested function to global scope
for (i in raymarch_utilities) {
    global[i] = raymarch_utilities[i];
}

// TODO: FIX should
describe('Raymarching in js utility functions', function () {
    describe('lengthV', function () {
        it('should return unit vectors length = 1', function () {
            let unitVectors = [[0, 0, 1], [0, 1, 0], [1, 0, 0]];
            for (u of unitVectors) {
                let res = lengthV(u);
                should(typeof res === 'Number');
                should(Math.abs(res - 1) < 0.0001);
            }
        });
        it('should return valid length of [1, 1, 1]', function () {
            let res = lengthV([1, 1, 1]);
            should(typeof res === 'Number');
            should(Math.abs(res - 1.73205080757) < 0.0001);
        });
    });
    describe('add', function () {
        it('should add two arrays and return a third', function () {
            let vecA = [1, 2, 3],
                vecB = [10, 11, 12],
                actual = [11, 13, 15],
                res = add(vecA, vecB);
            should(typeof res === 'Array');
            should(res.length === 3);
            for (let i = 0; i < actual.length; i++) {
                should(res[i] === actual[i]);
            }
        });
    });
    describe('sum', function () {
        it('should return sum of vector', function () {
            let A = [1, 2, 3],
                res = sum(A),
                actual = 7;
            console.log(res);
            should(typeof res === 'Number');
            should(res === actual);
        });
    });
});
