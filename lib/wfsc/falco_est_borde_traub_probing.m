% Copyright 2018-2021, by the California Institute of Technology. ALL RIGHTS
% RESERVED. United States Government Sponsorship acknowledged. Any
% commercial use must be negotiated with the Office of Technology Transfer
% at the California Institute of Technology.
% -------------------------------------------------------------------------
%
% Estimate the final focal plane electric field via Borde-Traub probing.
% The estimator performs a batch process.
% The Kalman filter addition has not been implemented.
%
% INPUTS
% ------
% mp : structure of model parameters
% ev : structure of estimation variables
% jacStruct : (optional) structure of control Jacobians
%
% RETURNS
% -------
% ev : structure of estimation variables
%
% REFERENCES
% ----------
% P. J. Borde and W. A. Traub, "High-contrast imaging from space: 
% Speckle nulling in a low aberration regime," ApJ, vol. 638, p488-498, 2006.

function ev = falco_est_borde_traub_probing(mp, ev, varargin)

Itr = ev.Itr;
whichDM = mp.est.probe.whichDM;

% Number of elements to correct depending of regular pixels or fibers
if mp.flagFiber
    Ncorr = mp.Fend.Nfiber;
else
    Ncorr = mp.Fend.corr.Npix;
end

%% Input checks
if ~isa(mp.est.probe, 'Probe')
    error('mp.est.probe must be an instance of class Probe')
end

% If scheduled, change some aspects of the probe.
% Empty values mean they are not scheduled.
if ~isempty(mp.est.probeSchedule.xOffsetVec)
    if length(mp.est.probeSchedule.xOffsetVec) < mp.Nitr
        error('mp.est.probeSchedule.xOffsetVec must have enough values for all WFSC iterations.')
    end
    mp.est.probe.xOffset = mp.est.probeSchedule.xOffsetVec(Itr);
end

if ~isempty(mp.est.probeSchedule.yOffsetVec)
    if length(mp.est.probeSchedule.yOffsetVec) < mp.Nitr
        error('mp.est.probeSchedule.yOffsetVec must have enough values for all WFSC iterations.')
    end
    mp.est.probe.yOffset = mp.est.probeSchedule.yOffsetVec(Itr);
end
fprintf('Probe offsets at the DM are (x=%.2f, y=%.2f) actuators.\n', mp.est.probe.xOffset, mp.est.probe.yOffset);

if ~isempty(mp.est.probeSchedule.rotationVec)
    if length(mp.est.probeSchedule.rotationVec) < mp.Nitr
        error('mp.est.probeSchedule.rotationVec must have enough values for all WFSC iterations.')
    end
    mp.est.probe.rotation = mp.est.probeSchedule.rotationVec(Itr);
end

if ~isempty(mp.est.probeSchedule.InormProbeVec)
    if length(mp.est.probeSchedule.InormProbeVec) < mp.Nitr
        error('mp.est.probeSchedule.InormProbeVec must have enough values for all WFSC iterations.')
    end
end

%--If there is a third input, it is the Jacobian structure
if size(varargin, 2) == 1
    jacStruct = varargin{1};
end

%%

%--"ev" is passed in only for the Kalman filter. Clear it for the batch
% process to avoid accidentally using old data.
switch lower(mp.estimator)
    case{'borde-traub', 'bt', 'bt-rect'}
        clear ev
end

% Augment which DMs are used if the probing DM isn't used for control.
if whichDM == 1 && ~any(mp.dm_ind == 1)
    mp.dm_ind = [mp.dm_ind(:); 1];
elseif whichDM == 2 && ~any(mp.dm_ind == 2)
    mp.dm_ind = [mp.dm_ind(:); 2];
end

%--Select number of actuators across based on chosen DM for the probing
if whichDM == 1
    Nact = mp.dm1.Nact;
elseif whichDM == 2
    Nact = mp.dm2.Nact;
end

%--Store the initial DM commands
if any(mp.dm_ind == 1);  DM1Vnom = mp.dm1.V;  else; DM1Vnom = zeros(size(mp.dm1.V)); end % The 'else' block would mean we're only using DM2
if any(mp.dm_ind == 2);  DM2Vnom = mp.dm2.V;  else; DM2Vnom = zeros(size(mp.dm2.V)); end % The 'else' block would mean we're only using DM1

% Initialize output arrays
Npairs = mp.est.probe.Npairs; % % Number of image PAIRS for DM Diversity or Kalman filter initialization
ev.imageArray = zeros(mp.Fend.Neta, mp.Fend.Nxi, 1+2*Npairs, mp.Nsbp);
if mp.flagFiber
    ev.Ifiber = zeros(mp.Fend.Nfiber, 1);
end
ev.Eest = zeros(Ncorr, mp.Nsbp*mp.compact.star.count);
ev.IincoEst = zeros(Ncorr, mp.Nsbp*mp.compact.star.count);

ev.IprobedMean = 0;
ev.Im = zeros(mp.Fend.Neta, mp.Fend.Nxi);
if whichDM == 1;  ev.dm1.Vall = zeros(mp.dm1.Nact, mp.dm1.Nact, 1+2*Npairs, mp.Nsbp);  end
if whichDM == 2;  ev.dm2.Vall = zeros(mp.dm2.Nact, mp.dm2.Nact, 1+2*Npairs, mp.Nsbp);  end

%--Generate evenly spaced probes along the complex unit circle
% NOTE: Nprobes=Npairs*2;   
probePhaseVec = [0 Npairs];
for k = 1:Npairs-1
    probePhaseVec = [probePhaseVec probePhaseVec(end)-(Npairs-1)];
    probePhaseVec = [probePhaseVec probePhaseVec(end)+(Npairs)];
end
probePhaseVec = probePhaseVec * pi / Npairs;

switch mp.estimator
    case{'borde-traub', 'bt'}
        
        switch lower(mp.est.probe.axis)
            case 'y'
                badAxisVec = repmat('y', [2*Npairs, 1]);
            case 'x'
                badAxisVec = repmat('x', [2*Npairs, 1]);
            case{'alt', 'xy', 'alternate'}
                % Change probe ordering for odd- vs even-numbered
                % WFSC iterations.
                if mod(Itr, 2) == 1
                    badAxisVec = repmat('x', [2*Npairs, 1]);
                    badAxisVec(3:4:end) = 'y';
                    badAxisVec(4:4:end) = 'y';
                else
                    badAxisVec = repmat('y', [2*Npairs, 1]);
                    badAxisVec(3:4:end) = 'x';
                    badAxisVec(4:4:end) = 'x';
                end

            case 'multi'
                badAxisVec = repmat('m', [2*Npairs, 1]);
        end
end


%% Get images and perform estimates in each sub-bandpass

fprintf('Estimating electric field with batch process estimation ...\n'); tic;

for iStar = 1:mp.compact.star.count

    modvar = ModelVariables;
    modvar.starIndex = iStar;
    modvar.whichSource = 'star';

for iSubband = 1:mp.Nsbp

    modvar.sbpIndex = iSubband;
    fprintf('Wavelength: %u/%u ... ', iSubband, mp.Nsbp);
    modeIndex = (iStar-1)*mp.Nsbp + iSubband;
    fprintf('Mode: %u/%u ... ', modeIndex, mp.jac.Nmode);    

    %% Measure current contrast level average, and on each side of Image Plane
    % Reset DM commands to the unprobed state:
    if any(mp.dm_ind == 1); mp.dm1 = falco_set_constrained_voltage(mp.dm1, DM1Vnom); end
    if any(mp.dm_ind == 2); mp.dm2 = falco_set_constrained_voltage(mp.dm2, DM2Vnom); end
    
    %% Separate out values of images at dark hole pixels and delta DM voltage settings
    
    Iplus  = zeros([mp.Fend.corr.Npix, Npairs]); % Pixels of plus probes' intensities
%     Iminus = zeros([mp.Fend.corr.Npix, Npairs]); % Pixels of minus probes' intensities
    if mp.flagFiber
        Ifiberplus  = zeros([mp.Fend.Nfiber, Npairs]); % Pixels of plus probes' intensities
%         Ifiberminus = zeros([mp.Fend.Nfiber, Npairs]); % Pixels of minus probes' intensities
    end
    DM1Vplus  = zeros([Nact, Nact, Npairs]);
    DM1Vminus = zeros([Nact, Nact, Npairs]);
    DM2Vplus  = zeros([Nact, Nact, Npairs]);
    DM2Vminus = zeros([Nact, Nact, Npairs]);

    %% Compute probe shapes and take probed images:

    %--Take initial, unprobed image (for unprobed DM settings).
    whichImage = 1;
    mp.isProbing = false; % tells the camera whether to use the exposure time for either probed or unprobed images.
    if ~mp.flagFiber
        I0 = falco_get_sbp_image(mp, iSubband);
        ev.score.Inorm = mean(I0(mp.Fend.score.maskBool));
        ev.corr.Inorm  = mean(I0(mp.Fend.corr.maskBool));
    else
        [I0,I0fiber] = falco_get_sbp_image(mp, iSubband);
        I0fibervec = I0fiber;
        ev.score.Inorm = mean(I0fibervec);
        ev.corr.Inorm  = mean(I0fibervec);
    end
    I0vec = I0(mp.Fend.corr.maskBool); % Vectorize the correction region pixels
    
    if iStar == 1 % Image already includes all stars, so don't sum over star loop
        ev.Im = ev.Im + mp.sbp_weights(iSubband)*I0; % subband-averaged image for plotting
        if mp.flagFiber; ev.Ifiber = ev.Ifiber + mp.sbp_weights(iSubband)*I0fiber;end % 

        %--Store values for first image and its DM commands
        ev.imageArray(:, :, whichImage, iSubband) = I0;
        if any(mp.dm_ind == 1);  ev.dm1.Vall(:, :, whichImage, iSubband) = mp.dm1.V;  end
        if any(mp.dm_ind == 2);  ev.dm2.Vall(:, :, whichImage, iSubband) = mp.dm2.V;  end
    end
    
    %--Compute the average Inorm in the scoring and correction regions
    fprintf('Measured unprobed Inorm (Corr / Score): %.2e \t%.2e \n',ev.corr.Inorm,ev.score.Inorm);    

    % Set (approximate) probe intensity based on current measured Inorm
    if isempty(mp.est.probeSchedule.InormProbeVec)
        ev.InormProbeMax = mp.est.InormProbeMax;
        if mp.flagFiber
            InormProbe = min([sqrt(max(I0fibervec)*1e-8), ev.InormProbeMax]);
        else
            InormProbe = min([sqrt(max(I0vec)*1e-5), ev.InormProbeMax]);
        end
        fprintf('Chosen probe intensity: %.2e \n', InormProbe);
    else
        InormProbe = mp.est.probeSchedule.InormProbeVec(Itr);
        fprintf('Scheduled probe intensity: %.2e \n', InormProbe);
    end

    %--Perform the probing
    mp.isProbing = true; % tells the camera whether to use the exposure time for either probed or unprobed images.
    iOdd = 1; iEven = 1; % Initialize index counters
    for iProbe = 1:2*Npairs
        isPlusProbe = (mod(iProbe, 2) == 1);
        isMinusProbe = (mod(iProbe, 2) == 0);

        %--Generate the DM command map for the probe
        switch lower(mp.estimator)
            case{'bt-rect'} 
                probeCmd = falco_gen_pairwise_probe(mp, InormProbe, probePhaseVec(iProbe), iStar, mp.est.probe.rotation);
            case{'borde-traub', 'bt'}
                probeCmd = falco_gen_pairwise_probe_square(mp, InormProbe, probePhaseVec(iProbe), badAxisVec(iProbe), mp.est.probe.rotation);
        end
        %--Select which DM to use for probing. Allocate probe to that DM
        if whichDM == 1
            dDM1Vprobe = probeCmd ./ mp.dm1.VtoH; % Now in volts
            dDM2Vprobe = 0;
        elseif whichDM == 2
            dDM1Vprobe = 0;        
            dDM2Vprobe = probeCmd ./ mp.dm2.VtoH; % Now in volts
        end

        if any(mp.dm_ind == 1)
            mp.dm1 = falco_set_constrained_voltage(mp.dm1, DM1Vnom + dDM1Vprobe); 
        end
        if any(mp.dm_ind == 2)
            mp.dm2 = falco_set_constrained_voltage(mp.dm2, DM2Vnom + dDM2Vprobe);
        end

        %--Take probed image
        if isPlusProbe  % Only take images for plus probes
            if mp.flagFiber
                [Im,Ifiber] = falco_get_sbp_image(mp, iSubband);
                ev.IprobedMean = ev.IprobedMean + Ifiber/(2*Npairs); %--Inorm averaged over all the probed images
            else
                Im = falco_get_sbp_image(mp, iSubband);
                ev.IprobedMean = ev.IprobedMean + mean(Im(mp.Fend.corr.maskBool))/(2*Npairs); %--Inorm averaged over all the probed images
            end
        else
            Im = 0*Im;
        end
        whichImage = 1+iProbe; %--Increment image counter

        %--Store probed image and its DM settings
        ev.imageArray(:, :, whichImage, iSubband) = Im;
        if any(mp.dm_ind == 1);  ev.dm1.Vall(:, :, whichImage, iSubband) = mp.dm1.V;  end
        if any(mp.dm_ind == 2);  ev.dm2.Vall(:, :, whichImage, iSubband) = mp.dm2.V;  end

        %--Report results
        probeSign = ['-', '+'];
        if isPlusProbe % Don't print the zero value for minus probes since no image is taken.
            if mp.flagFiber
                fprintf('Actual Probe %d%s Contrast is: %.2e \n', ceil(iProbe/2), probeSign(mod(iProbe, 2)+1), mean(Ifiber));
            else
                fprintf('Actual Probe %d%s Contrast is: %.2e \n', ceil(iProbe/2), probeSign(mod(iProbe, 2)+1), mean(Im(mp.Fend.corr.maskBool)));
            end
        end
        
        %--Assign image to positive or negative probe collection:
        if isPlusProbe  % Odd; for plus probes
            if whichDM == 1;  DM1Vplus(:, :, iOdd) = dDM1Vprobe + DM1Vnom;  end
            if whichDM == 2;  DM2Vplus(:, :, iOdd) = dDM2Vprobe + DM2Vnom;  end
            Iplus(:, iOdd) = Im(mp.Fend.corr.maskBool);
            if mp.flagFiber
                Ifiberplus(:, iOdd) = Ifiber;
            end

            iOdd = iOdd + 1;
            
        elseif isMinusProbe  % Even; for minus probes
            if whichDM == 1;  DM1Vminus(:, :, iEven) = dDM1Vprobe + DM1Vnom;  end
            if whichDM == 2;  DM2Vminus(:, :, iEven) = dDM2Vprobe + DM2Vnom;  end 
%             Iminus(:, iEven) = Im(mp.Fend.corr.maskBool);
%             if mp.flagFiber
%                 Ifiberminus(:, iEven) = Ifiber;
%             end
            iEven = iEven + 1;
        end
    end
    

    %% Plot relevant data for all the probes
    ev.iStar = iStar;
    if whichDM == 1
        DMV4plot = DM1Vplus - repmat(DM1Vnom, [1, 1, size(DM1Vplus, 3)]);
    elseif whichDM == 2
        DMV4plot = DM2Vplus - repmat(DM2Vnom, [1, 1, size(DM2Vplus, 3)]);
    end
    falco_plot_borde_traub_probes(mp, ev, DMV4plot, iSubband)
    % falco_plot_pairwise_probes(mp, ev, DMV4plot, ampSq2Dcube, iSubband)

    %% Perform the estimation
    
%     % Using the Jacobian only
%     dEplus  = zeros(size(Iplus ));
%     for iProbe=1:Npairs
%         if whichDM == 1
%             dV = DM1Vplus(:, :, iProbe) - DM1Vnom;
%             dEplus(:, iProbe) = squeeze(jacStruct.G1(:, :, modeIndex))*dV(mp.dm1.act_ele);
%         elseif whichDM == 2
%             dV = DM2Vplus(:, :, iProbe) - DM2Vnom;
%             dEplus(:, iProbe) = squeeze(jacStruct.G2(:, :, modeIndex))*dV(mp.dm2.act_ele);
%         end
%     end
    
    
    % Use the compact model to compute the expected E-fields for positive AND negative probes:
    if any(mp.dm_ind == 1); mp.dm1 = falco_set_constrained_voltage(mp.dm1, DM1Vnom); end
    if any(mp.dm_ind == 2); mp.dm2 = falco_set_constrained_voltage(mp.dm2, DM2Vnom); end

    if mp.flagFiber
        [~, E0] = model_compact(mp, modvar);
        E0vec = E0;
        %--For probed fields based on model:
        Eplus  = zeros(size(Ifiberplus ));
        Eminus = zeros(size(Ifiberplus));
    else
        E0 = model_compact(mp, modvar);
        E0vec = E0(mp.Fend.corr.maskBool);
         %--For probed fields based on model:
        Eplus  = zeros(size(Iplus ));
        Eminus = zeros(size(Iplus));
    end
        
    for iProbe = 1:Npairs
        % For plus probes:
        if whichDM == 1
            mp.dm1 = falco_set_constrained_voltage(mp.dm1, DM1Vplus(:, :, iProbe));
        elseif whichDM == 2
            mp.dm2 = falco_set_constrained_voltage(mp.dm2, DM2Vplus(:, :, iProbe));
        end
        if(mp.flagFiber)
            [~, Etemp] = model_compact(mp, modvar);
            Eplus(:, iProbe) = Etemp;
        else
            Etemp = model_compact(mp, modvar);
            Eplus(:, iProbe) = Etemp(mp.Fend.corr.maskBool);
        end

        % For minus probes:
        if whichDM == 1
            mp.dm1 = falco_set_constrained_voltage(mp.dm1, DM1Vminus(:, :, iProbe));
        elseif whichDM == 2
            mp.dm2 = falco_set_constrained_voltage(mp.dm2, DM2Vminus(:, :, iProbe));
        end
        if mp.flagFiber
            [~, Etemp] = model_compact(mp, modvar);
            Eminus(:, iProbe) = Etemp;
        else
            Etemp = model_compact(mp, modvar);
            Eminus(:, iProbe) = Etemp(mp.Fend.corr.maskBool);
        end
    end
    
    %%--Create delta E-fields for each probe image. Then create Npairs phase angles.
    dEplus  = Eplus  - repmat(E0vec, [1, Npairs]);
    dEminus = Eminus - repmat(E0vec, [1, Npairs]);
    dEprobe = (dEplus - dEminus)/2; % Take the average to mitigate nonlinear parts
    
    dIprobe = (abs(Eplus).^2 + abs(Eminus).^2)/2 - abs(repmat(E0vec, [1, Npairs])).^2;

    
    %% Batch process the measurements to estimate the electric field in the dark hole. Done pixel by pixel.

    % Old way from pairwise probing:
    % zAll = ((Iplus-Iminus)/4).';  % Measurement vector, dimensions: [Npairs, mp.Fend.corr.Npix]

    % New way with Borde-Traub probing:
    zAll = (Iplus - I0vec - dIprobe).'/2; % Measurement vector, dimensions: [Npairs, mp.Fend.corr.Npix]
    
    Eest = zeros(Ncorr, 1);
    for ipix = 1:Ncorr
        dE = dEprobe(ipix, :).';
        H = [real(dE), imag(dE)];
        Epix = pinv(H) * zAll(:, ipix); %--Batch process estimation
        Eest(ipix) = Epix(1) + 1i*Epix(2);
    end

%% Save out the estimates
ev.Eest(:, modeIndex) = Eest;
if mp.flagFiber
    ev.IincoEst(:, modeIndex) =  I0fibervec - abs(Eest).^2; % incoherent light
else
    ev.IincoEst(:, modeIndex) =  I0vec - abs(Eest).^2; % incoherent light
end

if mp.flagPlot && ~mp.flagFiber
    Eest2D = zeros(mp.Fend.Neta, mp.Fend.Nxi);
    Eest2D(mp.Fend.corr.maskBool) = Eest;
    %figure(701); imagesc(real(Eest2D)); title('real(Eest)', 'Fontsize', 18); set(gca, 'Fontsize', 18); axis xy equal tight; colorbar;
    %figure(702); imagesc(imag(Eest2D)); title('imag(Eest)', 'Fontsize', 18); set(gca, 'Fontsize', 18); axis xy equal tight; colorbar;
    %figure(703); imagesc(log10(abs(Eest2D).^2)); title('abs(Eest)^2', 'Fontsize', 18); set(gca, 'Fontsize', 18); axis xy equal tight; colorbar;
    %drawnow;
end

end %--End of loop over the wavelengths
end %--End of loop over stars

%--Other data to save out
% ev.ampSqMean = mean(ampSq(:)); %--Mean probe intensity
% ev.ampNorm = amp/sqrt(InormProbe); %--Normalized probe amplitude maps
% ev.InormProbe = InormProbe;        
ev.maskBool = mp.Fend.corr.maskBool; %--for resizing Eest and IincoEst for plotting
% ev.amp_model = amp_model;

mp.isProbing = false; % tells the camera whether to use the exposure time for either probed or unprobed images.

fprintf(' done. Time: %.3f\n',toc);

end %--END OF FUNCTION