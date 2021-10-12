%% Test input checks
%
% Unit tests of the methods in the Check class.
%
classdef TestCheckTwoDimArray < matlab.unittest.TestCase
%% Setup and Teardown Methods
%
%  Add and remove path to utils functions to be tested.
%
    methods (TestClassSetup)
        function addPath(testCase)
            addpath(genpath('../../lib'));
        end
    end
    methods (TestClassTeardown)
        function removePath(testCase)
            rmpath(genpath('../../lib'));
        end
    end
    
%% Unit tests of two_dim_array

    methods (Test)
        
        function testNonNumeric(testCase)
            var = 'asdf';
            identifier = 'two_dim_array:InputMustBeNumeric';
            verifyError(testCase, @() Check.two_dim_array(var), identifier)
        end
        function testEmpty(testCase)
            var = [];
            identifier = 'two_dim_array:InputMustBeArray';
            verifyError(testCase, @() Check.two_dim_array(var), identifier)
        end
        function testScalar(testCase)
            var = 2.5;
            identifier = 'two_dim_array:InputMustBeArray';
            verifyError(testCase, @() Check.two_dim_array(var), identifier)
        end
        function testTwoDim(testCase)
            var = ones(3, 2, 4);
            identifier = 'two_dim_array:InputMustBeTwoDim';
            verifyError(testCase, @() Check.two_dim_array(var), identifier)
        end
        
    end 

end
