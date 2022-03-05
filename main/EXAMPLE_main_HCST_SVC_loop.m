% Copyright 2022, by the California Institute of Technology. ALL RIGHTS
% RESERVED. United States Government Sponsorship acknowledged. Any
% commercial use must be negotiated with the Office of Technology Transfer
% at the California Institute of Technology.
% -------------------------------------------------------------------------
%
%--Script to perform a loop of SVC simulation runs.


% REVISION HISTORY:
% --------------
% Modified on 2022-02-23 by Niyati Desai.


clear all;
close all;


bws = [0.01,0.05,0.1,0.15,0.2];
nsbps = [1,3,5,7,9];
vals = [];


for index = 1:2 %length(bws)
    clearvars -except vals bws index nsbps
    mp.use_lastJacStruc = false;
    
    %% Step 1: Define Necessary Paths on Your Computer System

    %--Library locations. FALCO and PROPER are required. CVX is optional.
    mp.path.falco = '/Users/niyatid/falco-matlab/';  %--Location of FALCO
    mp.path.proper = '/Users/niyatid/falco-matlab/lib_external/proper/'; %--Location of the MATLAB PROPER library
    % mp.path.cvx = '~/Documents/MATLAB/cvx/'; %--Location of MATLAB CVX

    %%--Output Data Directories (Comment these lines out to use defaults within falco-matlab/data/ directory.)
    mp.path.config = '/Users/niyatid/falco-matlab/data/brief/'; %--Location of config files and minimal output files. Default is [mainPath filesep 'data' filesep 'brief' filesep]
    mp.path.ws = '/Users/niyatid/falco-matlab/data/ws/'; % (Mostly) complete workspace from end of trial. Default is [mainPath filesep 'data' filesep 'ws' filesep];
    mp.path.mask = '/Users/niyatid/falco-matlab/lib/masks/'; % (Mostly) complete workspace from end of trial. Default is [mainPath filesep 'data' filesep 'ws' filesep];
    mp.path.ws_inprogress = mp.path.ws;

    % % %--Library locations. FALCO and PROPER are required. CVX is optional.
    % mp.path.falco = 'C:\Users\jdllop\Documents\GitHub\falco-matlab';%'~/Repos/falco-matlab/';  %--Location of FALCO
    % mp.path.proper = 'C:\Users\jdllop\Documents\GitHub\falco-matlab\proper';%'~/Documents/MATLAB/PROPER/'; %--Location of the MATLAB PROPER library

    % %%--Output Data Directories ( Comment these lines out to use defaults within falco-matlab/data/ directory.)
    % mp.path.config = 'C:\Lab\falco-matlab\data\configs';%'~/Repos/falco-matlab/data/brief/'; %--Location of config files and minimal output files. Default is [mainPath filesep 'data' filesep 'brief' filesep]
    % mp.path.ws = 'C:\Lab\falco-matlab\data\ws';%'~/Repos/falco-matlab/data/ws/'; % (Mostly) complete workspace from end of trial. Default is [mainPath filesep 'data' filesep 'ws' filesep];

    %%--Add to the MATLAB Path
    addpath(genpath(mp.path.falco)) %--Add FALCO library to MATLAB path
    addpath(genpath(mp.path.proper)) %--Add PROPER library to MATLAB path

    %% Step 2: Load default model parameters

    disp(index);
    mp.fracBW = bws(index); %make sure this line is commented out in EXAMPLE_defaults_HCST_SVC_chromatic
    mp.Nsbp = nsbps(index); %make sure this line is commented out in EXAMPLE_defaults_HCST_SVC_chromatic
    mp.F3.phaseMaskType = 'vortex';
    EXAMPLE_defaults_HCST_SVC_chromatic
   


    %% Step 3: Overwrite default values as desired

    %%--Special Computational Settings
    mp.flagParfor = false; %--whether to use parfor for Jacobian calculation
    mp.flagPlot = true;

    %--Record Keeping
    mp.SeriesNum = 1;
    mp.TrialNum = 1;

    %--Use just 1 wavelength for initial debugging/testing of code

    %FOR BROADBAND, change frac to 10% and nsbp 5 or 3
%     mp.fracBW = 0.01;       %--fractional bandwidth of the whole bandpass (Delta lambda / lambda0)
%     mp.Nsbp = 1;            %--Number of sub-bandpasses to divide the whole bandpass into for estimation and control
    mp.Nwpsbp = 1;          %--Number of wavelengths to be used to approximate an image in each sub-bandpass

    mp.Nitr = 1; %--Number of wavefront control iterations

    %% Step 4: Generate the label associated with this trial

    mp.runLabel = ['Series',num2str(mp.SeriesNum,'%04d'),'_Trial',num2str(mp.TrialNum,'%04d_'),...
        mp.coro,'_',mp.whichPupil,'_',num2str(numel(mp.dm_ind)),'DM',num2str(mp.dm1.Nact),'_z',num2str(mp.d_dm1_dm2),...
        '_IWA',num2str(mp.Fend.corr.Rin),'_OWA',num2str(mp.Fend.corr.Rout),...
        '_',num2str(mp.Nsbp),'lams',num2str(round(1e9*mp.lambda0)),'nm_BW',num2str(mp.fracBW*100),...
        '_',mp.controller];


    %% Step 5: Perform the Wavefront Sensing and Control

    [mp, out] = falco_flesh_out_workspace(mp);

    [mp, out] = falco_wfsc_loop(mp, out);


    val = out.InormHist(end);
    vals = [vals;val]
%       val = 2
end

