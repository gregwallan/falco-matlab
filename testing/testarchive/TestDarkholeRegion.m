%---------------------------------------------------------------------------
% Copyright 2018-2021, by the California Institute of Technology. ALL RIGHTS
% RESERVED. United States Government Sponsorship acknowledged. Any
% commercial use must be negotiated with the Office of Technology Transfer
% at the California Institute of Technology.
%---------------------------------------------------------------------------
%% Test falco_gen_SW_mask.m
%
% We define some tests for falco_gen_SW_mask.m to test responses to
% different input parameters. 
classdef TestDarkholeRegion < matlab.unittest.TestCase    
%% Properties
%
% A presaved file with FALCO parameters was saved and is lodaded to be used
% by methods. In this case we only use the mp.path.falco + lib/utils to
% addpath to utils functions to be tested.
    properties
        mp=Parameters();
    end

%% Setup and Teardown Methods
%
%  Add and remove path to utils functions to be tested.
%
    methods (TestClassSetup)
        function addPath(testCase)
            addpath(genpath([testCase.mp.path.falco 'lib/utils']));
        end
    end
    methods (TestClassTeardown)
        function removePath(testCase)
            rmpath(genpath([testCase.mp.path.falco 'lib/utils']))
        end
    end
    
%% Tests
%
%  Creates four tests:
%
% # *testCircularSWMaskArea* verify that the area of the circular SW Mask 
%                            generated by falco_gen_bowtie_FPM.m is within 
%                            0.1% of the expected area.
% # *testCircularSWMaskTranslation* verify that the the actual translation of
%                            the circular SW Mask is equal to the expected translation.
% # *testSquareSWMaskArea* Verify that the are of the square SW Mask is
%                          within 1% of the expected area.                          
% # *testSquareSWMaskRotation* Verify that the sum of the difference
%                              between the rotated and non-rotated square 
%                              masks is equal to zero. 
%                                      
    methods (Test)    
        function testCircularSWMaskArea(testCase)
            inputs.pixresFP = 9;
            inputs.rhoInner = 2.5;
            inputs.rhoOuter = 10;
            inputs.angDeg = 160;
            inputs.whichSide = 't';
            inputs.centering = 'pixel';
            [mask1, xis1, etas1] = falco_gen_SW_mask(inputs);
            
            areaExpected = pi*(inputs.rhoOuter^2 - inputs.rhoInner^2)*(inputs.angDeg/360)*(inputs.pixresFP^2);
            area = sum(mask1(:));

            import matlab.unittest.constraints.IsEqualTo
            import matlab.unittest.constraints.RelativeTolerance
            testCase.verifyThat(area, IsEqualTo(areaExpected,'Within', RelativeTolerance(0.001)))
        end
        function testCircularSWMaskTranslation(testCase)
            inputs.pixresFP = 9;
            inputs.rhoInner = 2.5;
            inputs.rhoOuter = 10;
            inputs.angDeg = 160;
            inputs.whichSide = 't';
            inputs.centering = 'pixel';
            [mask1, xis1, etas1] = falco_gen_SW_mask(inputs);
            
            inputs.xiOffset = 1;
            inputs.etaOffset = -3;
            [maskShift, xis1, etas1] = falco_gen_SW_mask(inputs);

            diff = pad_crop(mask1, size(maskShift)) - circshift(maskShift, -inputs.pixresFP*[inputs.etaOffset, inputs.xiOffset]);            
            testCase.verifyEqual(sum(abs(diff(:))),0)             
        end
        function testSquareSWMaskArea(testCase)
            inputs.pixresFP = 19;
            inputs.rhoInner = 2.5;
            inputs.rhoOuter = 10;
            inputs.angDeg = 180;
            inputs.clockAngDeg = 0;
            inputs.whichSide = 'b';
            inputs.shape = 'square';
            [maskSquare, xis4, etas4] = falco_gen_SW_mask(inputs);
            
            areaExpected = ((2*inputs.rhoOuter)^2 - pi*inputs.rhoInner^2)*(inputs.angDeg/360)*(inputs.pixresFP^2);
            area = sum(maskSquare(:));
    
            import matlab.unittest.constraints.IsEqualTo
            import matlab.unittest.constraints.RelativeTolerance
            testCase.verifyThat(area, IsEqualTo(areaExpected,'Within', RelativeTolerance(0.01)))
        end
        function testSquareSWMaskRotation(testCase)
            inputs.pixresFP = 19;
            inputs.rhoInner = 2.5;
            inputs.rhoOuter = 10;
            inputs.angDeg = 180;
            inputs.clockAngDeg = 0;
            inputs.whichSide = 'b';
            inputs.shape = 'square';
            [maskSquare, xis4, etas4] = falco_gen_SW_mask(inputs);
            
            % Rotation test
            inputs.clockAngDeg = 90;
            inputs.whichSide = 'left';
            [maskSquareRot, xis4, etas4] = falco_gen_SW_mask(inputs);
            diff = maskSquareRot - maskSquare;
            testCase.verifyEqual(sum(abs(diff(:))),0)             
        end
    end    
end