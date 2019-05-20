% Copyright 2018, 2019, by the California Institute of Technology. ALL RIGHTS
% RESERVED. United States Government Sponsorship acknowledged. Any
% commercial use must be negotiated with the Office of Technology Transfer
% at the California Institute of Technology.
% -------------------------------------------------------------------------
%
%--Script to perform an HLC design run.
%  1) Load the default model parameters for an HLC.
%  2) Specify the values to overwrite.
%  3) Run a single trial of WFC using FALCO.
%
% REVISION HISTORY:
% --------------
% Modified on 2019-02-26 by A.J. Riggs to load the defaults first.
% ---------------

clear all;


%% Step 1: Define Necessary Paths on Your Computer System

%--Library locations. FALCO and PROPER are required. CVX is optional.
mp.path.falco = '~/Repos/falco-matlab/';  %--Location of FALCO
mp.path.proper = '~/Documents/MATLAB/PROPER/'; %--Location of the MATLAB PROPER library

%%--Output Data Directories (Comment these lines out to use defaults within falco-matlab/data/ directory.)
mp.path.config = '~/Repos/falco-matlab/data/brief/'; %--Location of config files and minimal output files. Default is [mainPath filesep 'data' filesep 'brief' filesep]
mp.path.ws = '~/Repos/falco-matlab/data/ws/'; % (Mostly) complete workspace from end of trial. Default is [mainPath filesep 'data' filesep 'ws' filesep];

%%--Add to the MATLAB Path
addpath(genpath(mp.path.falco)) %--Add FALCO library to MATLAB path
addpath(genpath(mp.path.proper)) %--Add PROPER library to MATLAB path


%% Step 2: Load default model parameters

EXAMPLE_defaults_WFIRST_PhaseB_PROPER_SPC_IFS


%% Step 3: Overwrite default values as desired

mp.Fend.res = 5;
mp.full.output_dim = ceil_even(1 + mp.Fend.res*(2*mp.Fend.FOV)); %  dimensions of output in pixels (overrides output_dim0)
mp.full.final_sampling_lam0 = 1/mp.Fend.res;	%   final sampling in lambda0/D

% %%--Special Computational Settings
mp.flagParfor = true; %--whether to use parfor for Jacobian calculation
mp.flagPlot = true;
% mp.propMethodPTP = 'mft';

%--Record Keeping
mp.SeriesNum = 1;
mp.TrialNum = 1;

%%--[OPTIONAL] Start from a previous FALCO trial's DM settings
% fn_prev = 'ws_Series0002_Trial0001_HLC_WFIRST20180103_2DM48_z1_IWA2.7_OWA10_6lams575nm_BW12.5_EFC_30its.mat';
% temp = load(fn_prev,'out');
% mp.dm1.V = temp.out.DM1V;
% mp.dm2.V = temp.out.DM2V;
% clear temp

% %--DEBUGGING:
% mp.fracBW = 0.08;       %--fractional bandwidth of the whole bandpass (Delta lambda / lambda0)
% mp.Nsbp = 3;            %--Number of sub-bandpasses to divide the whole bandpass into for estimation and control
% mp.flagParfor = true; %--whether to use parfor for Jacobian calculation

% %--DEBUGGING:
% mp.fracBW = 0.01;       %--fractional bandwidth of the whole bandpass (Delta lambda / lambda0)
% mp.Nsbp = 1;            %--Number of sub-bandpasses to divide the whole bandpass into for estimation and control
% mp.flagParfor = true; %--whether to use parfor for Jacobian calculation

% %--DEBUGGING:
% mp.fracBW = 0.04;       %--fractional bandwidth of the whole bandpass (Delta lambda / lambda0)
% mp.Nsbp = 2;            %--Number of sub-bandpasses to divide the whole bandpass into for estimation and control
% mp.flagParfor = true; %--whether to use parfor for Jacobian calculation

mp.controller = 'plannedEFC';
mp.ctrl.sched_mat = [...
    [0,0,0,1,0];...
    repmat([1,1j,12,0,1],[5,1]);...
    [1,-5,12,0,0];...
    repmat([1,1j,12,0,1],[9,1]);...
    ];
[mp.Nitr, mp.relinItrVec, mp.gridSearchItrVec, mp.ctrl.log10regSchedIn, mp.dm_ind_sched] = falco_ctrl_EFC_schedule_generator(mp.ctrl.sched_mat);
mp.ctrl.flagUseModel = true; %--Whether to perform a model-based (vs empirical) grid search for the controller


% %--GRID SEARCH EFC    
% mp.controller = 'gridsearchEFC';
% mp.Nitr = 5; %--Number of estimation+control iterations to perform
% mp.relinItrVec = 1; %1:mp.Nitr;  %--Which correction iterations at which to re-compute the control Jacobian
% mp.ctrl.flagUseModel = true; %--Whether to perform a model-based (vs empirical) grid search for the controller


%% Step 3b: Obtain the phase retrieval phase.

mp.full.input_field_rootname = '/home/ajriggs/Repos/falco-matlab/data/maps/input_full';

mp.P1.compact.E = zeros(mp.P1.compact.Nbeam+2,mp.P1.compact.Nbeam+2,mp.Nsbp); %--Initialize


% %--DEBUGGING: Perfect wavefront
% mp.full.pol_conds = [0];
% mp.full.polaxis = 0;
% mp.full.use_errors = false;
% mp.full.dm1.flatmap = 0;

optval.phaseb_dir = mp.full.phaseb_dir;

optval.cor_type = mp.full.cor_type;

optval.source_x_offset =0;
optval.zindex = 4;
optval.zval_m = 0.19e-9;
optval.use_errors = mp.full.use_errors;
optval.polaxis = mp.full.polaxis; %-2; 

optval.dm1_m = mp.full.dm1.flatmap; %fitsread([mp.full.phaseb_dir 'dm1_flatten.fits']);
optval.use_dm1 =1;

optval.end_at_fpm_exit_pupil = 1;
optval.output_field_rootname = ['fld_at_xtPup'];
optval.use_fpm=0;
optval.use_hlc_dm_patterns=0;
nout = 1024;%512; 			% nout > pupil_daim_pix

%% Check different polarization state initializations.
% mp.full.pol_conds = [-2,-1,1,2];
% 
% for ipol=1:length(mp.full.pol_conds)
%     lambda_um = 1e6*mp.lambda0;%*lambdaFacs(si);
%     
%     optval.polaxis = mp.full.pol_conds(ipol);
% 
%     fld = prop_run(['model_full_wfirst_phaseb'], lambda_um, nout, 'quiet', 'passvalue',optval );
%     % % % fld(2:end,2:end) = rot90(fld(2:end,2:end),2);
% 
%     % figure(601); imagesc(angle(fld)); axis xy equal tight; colorbar; colormap hsv;
%     % figure(602); imagesc(abs(fld)); axis xy equal tight; colorbar; colormap parula;
%     figure(500+ipol); imagesc(angle(fld)); axis xy equal tight; colorbar; colormap hsv; drawnow;
%     figure(600+ipol); imagesc(abs(fld)); axis xy equal tight; colorbar; colormap parula; drawnow;
%     
% end
% %%
% return
%%

if(mp.Nsbp==1)
    lambdaFacs = 1;
else
    lambdaFacs = linspace(1-mp.fracBW/2,1+mp.fracBW/2,mp.Nsbp);
end

for si=1:mp.Nsbp
    lambda_um = 1e6*mp.lambda0*lambdaFacs(si);

    fld = prop_run(['model_full_wfirst_phaseb'], lambda_um, nout, 'quiet', 'passvalue',optval );

    % figure(601); imagesc(angle(fld)); axis xy equal tight; colorbar; colormap hsv;
    % figure(602); imagesc(abs(fld)); axis xy equal tight; colorbar; colormap parula;
    figure(605); imagesc(angle(fld)); axis xy equal tight; colorbar; colormap hsv;
    figure(606); imagesc(abs(fld)); axis xy equal tight; colorbar; colormap parula;

    lams = num2str(lambda_um, '%6.4f');
    polaxis = 0;
    pols = ['polaxis'  num2str(polaxis,2)];
    fitswrite(real(fld), [mp.full.input_field_rootname '_' lams 'um_' pols '_real.fits' ]);
    fitswrite(imag(fld), [mp.full.input_field_rootname '_' lams 'um_' pols '_imag.fits' ]);

%     %%--Downsampling for the compact model
%     dxF = 1;
%     dxC = mp.P1.full.Nbeam/mp.P1.compact.Nbeam;
% 
%     Nf = length(fld);
%     Nc = ceil_even( (mp.P1.compact.Nbeam/mp.P1.full.Nbeam)*Nf );
% 
%     xF = (-Nf/2:Nf/2-1)*dxF;
%     xC = (-Nc/2:Nc/2-1)*dxC;
% 
%     [Xf,Yf] = meshgrid(xF);
%     [Xc,Yc] = meshgrid(xC);
% 
%     fldC = interp2(Xf,Yf,fld,Xc,Yc,'cubic',0); %--Downsample by interpolation
% 
%     figure(607); imagesc(angle(fldC)); axis xy equal tight; colorbar; colormap hsv;
%     figure(608); imagesc(abs(fldC)); axis xy equal tight; colorbar; colormap parula;
% 
% 
%     fldC = padOrCropEven(fldC,mp.P1.compact.Nbeam+2);
%     temp = 0*fldC;
%     temp(2:end,2:end) = rot90(fldC(2:end,2:end),2);
%     mp.P1.compact.E(:,:,si) = temp;
    
    
    
    %%--Downsampling for the compact model
    dxF = 1;
    dxC = mp.P1.full.Nbeam/mp.P1.compact.Nbeam;

    Nf = length(fld);
    Nc = ceil_even( (mp.P1.compact.Nbeam/mp.P1.full.Nbeam)*Nf );

    xF = (-Nf/2:Nf/2-1)*dxF;
    xC = (-Nc/2:Nc/2-1)*dxC;

    [Xf,Yf] = meshgrid(xF);
    [Xc,Yc] = meshgrid(xC);

    fldC = interp2(Xf,Yf,fld,Xc,Yc,'cubic',0); %--Downsample by interpolation

    figure(607); imagesc(angle(fldC)); axis xy equal tight; colorbar; colormap hsv;
    figure(608); imagesc(abs(fldC)); axis xy equal tight; colorbar; colormap parula;

    %--Subtract out the tip/tilt
    Narray = ceil_even(mp.P1.compact.Nbeam+1);

%     x = (-Narray/2:Narray/2-1)/mp.P1.compact.Nbeam; 
%     [tip,tilt] = meshgrid(x);
    
    fldC = padOrCropEven(fldC,ceil_even(mp.P1.compact.Nbeam+1));
%     if(mp.full.dm1.flatmap ~= 0)
%         fldC = fldC.*exp(1i*tilt*0.87*(1/lambdaFacs(si)));
%     end
    
    temp = 0*fldC;
    temp(2:end,2:end) = rot90(fldC(2:end,2:end),2);
    mp.P1.compact.E(:,:,si) = temp;
    
    figure(617+si-1); imagesc(angle(fldC)); axis xy equal tight; colorbar; colormap hsv; drawnow;
    
    

end

%% Step 4: Generate the label associated with this trial

mp.runLabel = ['Series',num2str(mp.SeriesNum,'%04d'),'_Trial',num2str(mp.TrialNum,'%04d_'),...
    mp.coro,'_',mp.whichPupil,'_',num2str(numel(mp.dm_ind)),'DM',num2str(mp.dm1.Nact),'_z',num2str(mp.d_dm1_dm2),...
    '_IWA',num2str(mp.Fend.corr.Rin),'_OWA',num2str(mp.Fend.corr.Rout),...
    '_',num2str(mp.Nsbp),'lams',num2str(round(1e9*mp.lambda0)),'nm_BW',num2str(mp.fracBW*100),...
    '_',mp.controller];

%% Step 5: Perform the Wavefront Sensing and Control

[out,mp] = falco_wfsc_loop(mp);


%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Change the resolution

E0 = mp.P1.compact.E; %--Don't erase the starting settings.
paths = mp.path;
runLabel = mp.runLabel;
clear mp
mp.runLabel = runLabel;
mp.P1.compact.E = E0; 
mp.path = paths;

%--Data locations for WFIRST CGI calculations of flux ratio noise (FRN)
mp.path.frn_coro = '/home/ajriggs/Downloads/'; %--Location of coronagraph performance data tables

%--Re-initialize mp structure
EXAMPLE_defaults_WFIRST_PhaseB_PROPER_SPC_IFS %--Load default model parameters

mp.Fend.res = 5; %--Change the image resolution [pixels per lambda0/D]
mp.full.output_dim = ceil_even(1 + mp.Fend.res*(2*mp.Fend.FOV)); %  dimensions of output in pixels (overrides output_dim0)
mp.full.final_sampling_lam0 = 1/mp.Fend.res;	%   final sampling in lambda0/D

%--Set DM commands back to final
mp.dm1.V = out.dm1.Vall(:,:,end);
mp.dm2.V = out.dm2.Vall(:,:,end);

%--DEBUGGING:
mp.fracBW = 0.01;       %--fractional bandwidth of the whole bandpass (Delta lambda / lambda0)
mp.Nsbp = 1;            %--Number of sub-bandpasses to divide the whole bandpass into for estimation and control
mp.flagParfor = true; %--whether to use parfor for Jacobian calculation


%--Save the config file
fn_config = [mp.path.config mp.runLabel,'_configHD.mat'];
save(fn_config)
fprintf('Saved the config file: \t%s\n',fn_config)
%--Get configuration data from a function file
[mp,out] = falco_init_ws(fn_config);


%% Compute the table of annular zones

mp.eval.Rsens = ...
                [3., 4.;...
                4., 5.;...
                5., 6.;...
                6., 7.;...
                7., 8.]; 
            
tableAnn = falco_FRN_AnnularZone_table(mp);
writetable(tableAnn,[mp.path.frn_coro 'AnnZoneList.csv']); %--Save to CSV file
tableAnn  


%% Compute the table InitialRawContrast.csv --> DO THIS INSIDE OF THE FRN CALCULATOR TO RE-USE THE CONTRAST MAPS

tableContrast = falco_FRN_InitialRawContrast(mp);
writetable(tableContrast,[mp.path.frn_coro 'InitialRawContrast.csv']); %--Save to CSV file
tableContrast


%% Compute the Krist table

%--Other constants
mp.yield.Dtel = 2.3631; % meters

%--Define radial sampling and range
mp.yield.R0 = 2.5;
mp.yield.R1 = 9.1;

%--Compute and save the table
tableKrist = falco_FRN_Krist_table(mp);
writetable(tableKrist,[mp.path.frn_coro 'KristTable.csv']); %--Save to CSV file

%--Plot the table data
matKrist = tableKrist{:,:};
figure(200); imagesc(matKrist); axis tight;
figure(201); imagesc(log10(matKrist)); axis tight;
figure(202); semilogy(matKrist(:,1),matKrist(:,3),'-b',matKrist(:,1),matKrist(:,4),'-r','Linewidth',3); %--Compare intensity and contrast plots


%% Calculate Sensitivities.csv 

%--Rows 1 to 10: Z2 to Z11 sensitivities to 1nm RMS of Zernike phase aberrations at entrance pupil.
%--Rows 11 to 17: Gain Z5 to Z11 sensitivities
%--Row 18: Pupil X shear
%--Row 19: Pupil Y shear
%--Row 20: DM Settling
%--Row 21: DM Thermal

tableSens = falco_FRN_Sens_table(mp);
writetable(tableSens,[mp.path.frn_coro 'Sensitivities.csv']); %--Save to CSV file
tableSens