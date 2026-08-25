clc;
clear;
close all;

% Delete old Mic_Plots folder if it exists
if exist('Mic_Plots','dir')
    rmdir('Mic_Plots','s');
end

figNum = 1;

%% Create output folders

%% Audio output folders

% Save Room Impulse Response files
rir_folder = 'RIR_Outputs';

% Save generated echo signals
echo_folder = 'Echo_Outputs';

% Save microphone signals
mic_folder = 'Mic_Outputs';

% Save NLMS output signals
nlms_folder = 'NLMS_Outputs';

% Save estimated echo signals
estecho_folder = 'EstimatedEcho_Outputs';

% Save final AEC output signals
aec_folder = 'AEC_Outputs';

%% Plot output folders

% Save RIR waveform plots
rirplot_folder = 'RIR_Plots';

% Save waveform comparison plots
waveplot_folder = 'Waveform_Plots';

% Save spectrogram comparison plots
specplot_folder = 'Spectrogram_Plots';

% Save performance metric plots
metricsplot_folder = 'Metrics_Plots';

%% Metrics folder

% Save NLMS error table
nlmsmetrics_folder = 'NLMS_Metrics';

%% Create all folders

folders = {
    rir_folder
    echo_folder
    mic_folder
    nlms_folder
    estecho_folder
    aec_folder
    rirplot_folder
    waveplot_folder
    specplot_folder
    metricsplot_folder
    nlmsmetrics_folder
};

% Create the folders if they do not exist
for i = 1:numel(folders)

    if ~exist(folders{i},'dir')
        mkdir(folders{i});
    end

end

%% Load speech signals

% Read far-end and near-end speech signals
[x,fs] = audioread('far_end_speech.wav');
[s,~]  = audioread('near_end_speech.wav');

% Convert stereo signals to mono if required
x = mean(x,2);
s = mean(s,2);

% Normalize the signals
x = x/(rms(x)+eps);
s = s/(rms(s)+eps);

% Make both signals the same length
L = max(length(x),length(s));

x(end+1:L) = 0;
s(end+1:L) = 0;

% Time vector for plotting
t = (0:L-1)/fs;

%% Room configurations

% Room names used in the simulation
room_names = {
    'SmallRoom'
    'MediumRoom'
    'LargeRoom'
};

% Room dimensions [Length Width Height] in meters
room_dims = [
    4 3 2.5;
    5 4 3;
    8 6 4
];

% Reverberation time (RT60) for each room
rt60_list = [
    0.3;
    0.6;
    0.9
];

%% Noise files

% Noise audio files used for testing
noise_files = {
    'noise_white.wav'
    'noise_babble.wav'
    'noise_factory.wav'
    'noise_cockpit.wav'
    'noise_street.wav'
    'noise_car.wav'
};

% Names of the noise types
noise_names = {
    'white'
    'babble'
    'factory'
    'cockpit'
    'street'
    'car'
};

% Short names of the room environments
rir_names = {
    'small'
    'medium'
    'large'
};

%% Target SNR values

% Input SNR levels used for testing
snr_list = [-10 -5 0 5 10 15 20];

% Store performance metrics
metrics_table = [];

% Store NLMS error values
error_table = [];

%% Process each room

for roomIdx = 1:length(room_names)

    % Get room dimensions
    room_dim = room_dims(roomIdx,:);

    % Get RT60 value
    rt60 = rt60_list(roomIdx);

    % Generate Room Impulse Response (RIR)
    h = rir( ...
        fs,...
        [5 4 3],...
        6,...
        rt60,...
        room_dim,...
        [2 1 1]);


%% Save RIR

% Save Room Impulse Response as a MAT file
save(fullfile(rir_folder,...
['RIR_',room_names{roomIdx},'.mat']),'h');

% Normalize the RIR before saving as an audio file
h_save = h./(max(abs(h))+eps);

% Save the normalized RIR as a WAV file
audiowrite( ...
fullfile(rir_folder,...
['RIR_',room_names{roomIdx},'.wav']),...
h_save,fs);

%% Time axis for RIR

% Create time vector for the RIR signal
t_rir = (0:length(h)-1)/fs;

% Find the last significant sample in the RIR
idx_last = find(abs(h) > 1e-4,1,'last');

if isempty(idx_last)
    idx_last = length(h);
end

% Set the x-axis limit for the RIR plot
maxTime = min(t_rir(idx_last)*1.1, t_rir(end));

%% RIR waveform

% Create RIR waveform plot
fig = figure('Visible','off');

plot(t_rir,h,...
    'b','LineWidth',1.5);

title(['RIR Waveform - ' room_names{roomIdx}])
xlabel('Time (s)')
ylabel('Amplitude')

grid on
box on

% Display only the useful portion of the RIR
xlim([0 maxTime])
ylim([-0.10 1.05])

% Save the RIR waveform plot
savefig(fig,...
    fullfile(rirplot_folder,...
    ['RIR_' room_names{roomIdx} '.fig']));

close(fig);

%% Generate echo signal

% Generate the echo using the Room Impulse Response
echo_scale = 0.8;

d_true = conv(x,h);
d_true = d_true(1:L);

% Scale the echo signal
d_true = echo_scale * d_true;

%% Save echo audio

d_save = d_true;

% Prevent clipping before saving
if max(abs(d_save)) > 0.99
    d_save = 0.99 * d_save / max(abs(d_save));
end

% Save the echo signal
audiowrite( ...
    fullfile(echo_folder,...
    ['echo_',room_names{roomIdx},'.wav']), ...
    d_save, fs);

%% Process each noise type

for k = 1:length(noise_files)

    %% Process each input SNR

    for snrIdx = 1:length(snr_list)

        % Current input SNR
        targetSNR = snr_list(snrIdx);

        % fprintf('\nProcessing %s noise at %d dB SNR...\n',...
        % noise_names{k},targetSNR);

   %% Load noise signal

% Read the selected noise file
[noise,fsn] = audioread(noise_files{k});

% Convert stereo noise to mono
noise = mean(noise,2);

% Resample the noise if the sampling rates are different
if fsn ~= fs
    noise = resample(noise,fs,fsn);
end

noise = noise(:);

% Repeat the noise if it is shorter than the speech signal
if length(noise) < L

    rep = ceil(L/length(noise));

    noise = repmat(noise,rep,1);

end

% Match the noise length with the speech signal
noise = noise(1:L);

%% Adjust noise to the target SNR

% Signal power
Ps = mean((s + d_true).^2);

% Noise power
Pn = mean(noise.^2);

% Scale the noise to obtain the required input SNR
scale = sqrt(Ps/(Pn*10^(targetSNR/10)));

noise = noise * scale;

%% Generate microphone signal

% Microphone signal = Near-end Speech + Echo + Noise
y = s + d_true + noise;

%% Calculate error before NLMS

Before_NLMS_MSE = mean((s - y).^2);

%% Save microphone signal

% Normalize the microphone signal before saving
y_save = y/(max(abs(y))+eps);
y_save = 0.95*y_save;

audiowrite( ...
    fullfile(mic_folder,...
    ['mic_',noise_names{k},'_',num2str(targetSNR),'dB.wav']),...
    y_save,fs);

 %% Train NLMS filter

% Use the true echo signal for NLMS training
y_train = d_true;
  
% NLMS filter length
M = 1024;

% NLMS step size
mu = 0.05;

% Train the NLMS filter
w = nlms_train_weights(x,y_train,mu,M);

%% Apply NLMS filter

% Estimate the echo and calculate the residual signal
[e,d_hat] = nlms_apply_weights(x,y,w);


%% Save estimated echo

% Normalize the estimated echo before saving
dhat_save = d_hat/(max(abs(d_hat))+eps);

audiowrite( ...
    fullfile(estecho_folder,...
    ['EstimatedEcho_',...
    noise_names{k},'_',...
    num2str(targetSNR),'dB.wav']),...
    dhat_save,fs);

% NLMS output signal
e_nlms = e;

%% Calculate NLMS output error

% Ensure the NLMS output has the correct length
e_nlms = e_nlms(:);

if length(e_nlms) > L

    e_nlms = e_nlms(1:L);

elseif length(e_nlms) < L

    e_nlms(end+1:L) = 0;

end

% Calculate the error after NLMS
NLMS_Output_MSE = mean((s - e_nlms).^2);

%% Save NLMS output

% Normalize the NLMS output before saving
e_save = e_nlms/(max(abs(e_nlms))+eps);
e_save = 0.95*e_save;

audiowrite( ...
    fullfile(nlms_folder,...
    ['nlms_',noise_names{k},'_',num2str(targetSNR),'dB.wav']),...
    e_save,fs);

%% Modulation domain suppression

% Enhance the NLMS output using modulation domain processing
s_hat = modulation_domain_suppression(e_nlms,fs);

%% Match signal lengths

% Match the enhanced signal length with the NLMS output
if length(s_hat) > length(e_nlms)

    s_hat = s_hat(1:length(e_nlms));

elseif length(s_hat) < length(e_nlms)

    s_hat(end+1:length(e_nlms)) = 0;

end

s_hat = s_hat(:);


%% Match final output length

% Ensure the final output has the correct length
if length(s_hat) > L

    s_hat = s_hat(1:L);

elseif length(s_hat) < L

    s_hat(end+1:L) = 0;

end

%% Calculate final output error

% Calculate the error after modulation domain enhancement
s_hat = s_hat(:);
s = s(:);

final_error = s - s_hat;

Final_Output_MSE = mean(final_error.^2);

%% Save final AEC output

% Normalize the final output before saving
s_save = s_hat/(max(abs(s_hat))+eps);
s_save = 0.95*s_save;

audiowrite( ...
    fullfile(aec_folder,...
    ['aec_',noise_names{k},'_',num2str(targetSNR),'dB.wav']),...
    s_save,fs);

%% Calculate performance metrics

%% Echo Return Loss Enhancement (ERLE)

% Calculate the residual echo after NLMS
residual_echo = d_true - d_hat;

% Calculate ERLE
ERLE = 10*log10( ...
    mean(d_true.^2) / ...
    (mean(residual_echo.^2) + eps));

%% Output SNR

% Calculate the residual noise after AEC
noise_residual = s_hat - s;

% Calculate the output SNR
SNRout = 10*log10( ...
    mean(s.^2) / ...
    (mean(noise_residual.^2) + eps));

%% Calculate SI-SDR

% Calculate the scaling factor
alpha_si = (s' * s_hat) / (s' * s + eps);

% Calculate the target speech component
target = alpha_si * s;

% Calculate the distortion component
noise_comp = s_hat - target;

% Calculate SI-SDR
SI_SDR = 10 * log10( ...
    sum(target.^2) / (sum(noise_comp.^2) + eps));

%% Calculate STOI

% Calculate speech intelligibility
try
    STOI = stoi(s,s_hat,fs);
catch
    STOI = NaN;
end

%% Store performance metrics

% Store metrics for plotting
metrics_table = [metrics_table;
    roomIdx ...
    k ...
    targetSNR ...
    ERLE ...
    SNRout ...
    SI_SDR ...
    STOI];

% Store NLMS error values
error_table = [error_table;
    roomIdx ...
    k ...
    targetSNR ...
    Before_NLMS_MSE ...
    NLMS_Output_MSE ...
    Final_Output_MSE];

%% Display plots only for 10 dB

if targetSNR == 10

%% Waveform comparison

fig = figure(figNum);
figNum = figNum + 1;

set(fig,...
    'Name',['Waveform_' room_names{roomIdx} '_' noise_names{k}],...
    'Color','w');

A1 = max(abs(s)) + eps;
A3 = max(abs(y)) + eps;
A4 = max(abs(e_nlms)) + eps;
A5 = max(abs(s_hat)) + eps;

subplot(4,1,1)
plot(t,s)
ylim([-A1 A1])
title('Near-End Speech','FontSize',14,'FontWeight','bold')
xlabel('Time (s)')
ylabel('Amplitude')
grid on

subplot(4,1,2)
plot(t,y)
ylim([-A3 A3])
title(['Microphone Signal - ',noise_names{k}],...
    'FontSize',14,'FontWeight','bold')
xlabel('Time (s)')
ylabel('Amplitude')
grid on

subplot(4,1,3)
plot(t,e_nlms)
ylim([-A4 A4])
title('NLMS Output',...
    'FontSize',14,'FontWeight','bold')
xlabel('Time (s)')
ylabel('Amplitude')
grid on

subplot(4,1,4)
plot(t,s_hat)
ylim([-A5 A5])
title('Proposed AEC Output',...
    'FontSize',14,'FontWeight','bold')
xlabel('Time (s)')
ylabel('Amplitude')
grid on

drawnow

waveFigName = sprintf('Waveform_%s_%s', ...
    room_names{roomIdx}, noise_names{k});

savefig(fig,...
    fullfile(waveplot_folder,[waveFigName '.fig']));

drawnow
pause(1)

%% Spectrogram comparison

fig = figure(figNum);
figNum = figNum + 1;

set(fig,...
    'Name',['Spectrogram_' room_names{roomIdx} '_' noise_names{k}],...
    'Color','w');

subplot(4,1,1)
spectrogram(s,256,128,256,fs,'yaxis')
title('Near-End Speech',...
    'FontSize',14,'FontWeight','bold')

subplot(4,1,2)
spectrogram(y,256,128,256,fs,'yaxis')
title(['Microphone Signal - ',noise_names{k}],...
    'FontSize',14,'FontWeight','bold')

subplot(4,1,3)
spectrogram(e_nlms,256,128,256,fs,'yaxis')
title('NLMS Output',...
    'FontSize',14,'FontWeight','bold')

subplot(4,1,4)
spectrogram(s_hat,256,128,256,fs,'yaxis')
title('Proposed AEC Output',...
    'FontSize',14,'FontWeight','bold')
drawnow

specFigName = sprintf('Spectrogram_%s_%s', ...
    room_names{roomIdx}, noise_names{k});

savefig(fig,...
    fullfile(specplot_folder,[specFigName '.fig']));

drawnow
pause(1)

end

end      % End of SNR loop

end      % End of Noise loop

end      % End of Room loop

%% Display performance results

fprintf('\n\n============================================================\n');
fprintf('                 PERFORMANCE RESULTS\n');
fprintf('============================================================\n');

% Display results for each room
for rirIdx = 1:length(room_names)

    fprintf('\n============================================================\n');
    fprintf('%s ROOM (RT60 = %.1f s)\n', upper(rir_names{rirIdx}), rt60_list(rirIdx));
    fprintf('============================================================\n');

    % Display results for each noise type
    for noiseIdx = 1:length(noise_names)

        fprintf('\nNoise : %s\n', upper(noise_names{noiseIdx}));
        fprintf('------------------------------------------------------------\n');
        fprintf('SNRin    ERLE     SNRout    SI-SDR    STOI\n');
        fprintf('------------------------------------------------------------\n');

        % Get the rows corresponding to the current room and noise
        rows = metrics_table(:,1)==rirIdx & ...
               metrics_table(:,2)==noiseIdx;

        data = metrics_table(rows,:);

        % Print the performance metrics
        for i = 1:size(data,1)

            fprintf('%5.0f %10.2f %10.2f %10.2f %9.3f\n',...
                data(i,3),...
                data(i,4),...
                data(i,5),...
                data(i,6),...
                data(i,7));

        end

    end

end

fprintf('\n============================================================\n');
fprintf('Simulation completed successfully.\n');
fprintf('============================================================\n');

%% Save NLMS error table

% Create a table with the NLMS error values
error_tbl = array2table(error_table,...
    'VariableNames',...
    {'Room',...
     'Noise',...
     'SNRin',...
     'BeforeNLMS_MSE',...
     'AfterNLMS_MSE',...
     'FinalOutput_MSE'});

% Save the table as an Excel file
writetable(error_tbl,...
    fullfile(nlmsmetrics_folder,...
    'NLMS_Error_Table.xlsx'));

%% SI-SDR vs Input SNR (White Noise)

% White noise index
noiseIdx = 1;

% Store SI-SDR values for each room
SDR_small  = zeros(1,length(snr_list));
SDR_medium = zeros(1,length(snr_list));
SDR_large  = zeros(1,length(snr_list));

% Extract SI-SDR values from the metrics table
for sIdx = 1:length(snr_list)

    rows = metrics_table(:,1)==1 & ...
           metrics_table(:,2)==noiseIdx & ...
           metrics_table(:,3)==snr_list(sIdx);
    SDR_small(sIdx) = mean(metrics_table(rows,6));

    rows = metrics_table(:,1)==2 & ...
           metrics_table(:,2)==noiseIdx & ...
           metrics_table(:,3)==snr_list(sIdx);
    SDR_medium(sIdx) = mean(metrics_table(rows,6));

    rows = metrics_table(:,1)==3 & ...
           metrics_table(:,2)==noiseIdx & ...
           metrics_table(:,3)==snr_list(sIdx);
    SDR_large(sIdx) = mean(metrics_table(rows,6));

end

%% Plot SI-SDR

fig = figure('Visible','off',...
             'Color','w',...
             'Units','pixels',...
             'Position',[150 100 1000 700]);

ax = axes('Parent',fig);

hold(ax,'on')

plot(ax,snr_list,SDR_small,...
    '-o','LineWidth',2.5,'MarkerSize',10,...
    'DisplayName','Small Room');

plot(ax,snr_list,SDR_medium,...
    '--s','LineWidth',2.5,'MarkerSize',10,...
    'DisplayName','Medium Room');

plot(ax,snr_list,SDR_large,...
    '-^','LineWidth',2.5,'MarkerSize',10,...
    'DisplayName','Large Room');

grid(ax,'on')
box(ax,'on')

ax.FontSize = 14;
ax.FontWeight = 'bold';
ax.LineWidth = 1.5;

ax.XLim = [-10 20];
ax.XTick = snr_list;

ax.YLim = [floor(min([SDR_small SDR_medium SDR_large]))-1,...
           ceil(max([SDR_small SDR_medium SDR_large]))+1];

xlabel(ax,'Input SNR (dB)','FontSize',15,'FontWeight','bold')
ylabel(ax,'SI-SDR (dB)','FontSize',15,'FontWeight','bold')

title(ax,'SI-SDR vs Input SNR','FontSize',16,'FontWeight','bold')

lgd = legend(ax,...
    {'Small Room','Medium Room','Large Room'},...
    'Location','northwest');

lgd.FontSize = 12;
lgd.Box = 'on';

% Save the figure
savefig(fig,...
    fullfile(metricsplot_folder,...
    'SISDR_vs_InputSNR.fig'));

close(fig);

%% STOI vs Input SNR (White Noise)

% White noise index
noiseIdx = 1;

% Store STOI values for each room
STOI_small  = zeros(1,length(snr_list));
STOI_medium = zeros(1,length(snr_list));
STOI_large  = zeros(1,length(snr_list));

% Extract STOI values from the metrics table
for sIdx = 1:length(snr_list)

    rows = metrics_table(:,1)==1 & ...
           metrics_table(:,2)==noiseIdx & ...
           metrics_table(:,3)==snr_list(sIdx);
    STOI_small(sIdx) = mean(metrics_table(rows,7));

    rows = metrics_table(:,1)==2 & ...
           metrics_table(:,2)==noiseIdx & ...
           metrics_table(:,3)==snr_list(sIdx);
    STOI_medium(sIdx) = mean(metrics_table(rows,7));

    rows = metrics_table(:,1)==3 & ...
           metrics_table(:,2)==noiseIdx & ...
           metrics_table(:,3)==snr_list(sIdx);
    STOI_large(sIdx) = mean(metrics_table(rows,7));

end

%% Plot STOI

fig = figure('Visible','off',...
             'Color','w',...
             'Units','pixels',...
             'Position',[150 100 1000 700]);

ax = axes('Parent',fig);

hold(ax,'on')

plot(ax,snr_list,STOI_small,...
    '-o','LineWidth',2.5,'MarkerSize',10,...
    'DisplayName','Small Room');

plot(ax,snr_list,STOI_medium,...
    '--s','LineWidth',2.5,'MarkerSize',10,...
    'DisplayName','Medium Room');

plot(ax,snr_list,STOI_large,...
    '-^','LineWidth',2.5,'MarkerSize',10,...
    'DisplayName','Large Room');

grid(ax,'on')
box(ax,'on')

ax.FontSize = 14;
ax.FontWeight = 'bold';
ax.LineWidth = 1.5;

ax.XLim = [-10 20];
ax.XTick = snr_list;
ax.YLim = [0 1];

xlabel(ax,'Input SNR (dB)','FontSize',15,'FontWeight','bold')
ylabel(ax,'STOI','FontSize',15,'FontWeight','bold')

title(ax,'STOI vs Input SNR','FontSize',16,'FontWeight','bold')

lgd = legend(ax,...
    {'Small Room','Medium Room','Large Room'},...
    'Location','southeast');

lgd.FontSize = 12;
lgd.Box = 'on';

% Save the figure
savefig(fig,...
    fullfile(metricsplot_folder,...
    'STOI_vs_InputSNR.fig'));

close(fig);

%% Output SNR vs Input SNR (White Noise)

% White noise index
noiseIdx = 1;

% Store Output SNR values for each room
SNR_small  = zeros(1,length(snr_list));
SNR_medium = zeros(1,length(snr_list));
SNR_large  = zeros(1,length(snr_list));

% Extract Output SNR values from the metrics table
for sIdx = 1:length(snr_list)

    rows = metrics_table(:,1)==1 & ...
           metrics_table(:,2)==noiseIdx & ...
           metrics_table(:,3)==snr_list(sIdx);
    SNR_small(sIdx) = mean(metrics_table(rows,5));

    rows = metrics_table(:,1)==2 & ...
           metrics_table(:,2)==noiseIdx & ...
           metrics_table(:,3)==snr_list(sIdx);
    SNR_medium(sIdx) = mean(metrics_table(rows,5));

    rows = metrics_table(:,1)==3 & ...
           metrics_table(:,2)==noiseIdx & ...
           metrics_table(:,3)==snr_list(sIdx);
    SNR_large(sIdx) = mean(metrics_table(rows,5));

end

%% Plot Output SNR

fig = figure('Visible','off',...
             'Color','w',...
             'Units','pixels',...
             'Position',[150 100 1000 700]);

ax = axes('Parent',fig);

hold(ax,'on')

plot(ax,snr_list,SNR_small,...
    '-o','LineWidth',2.5,'MarkerSize',10,...
    'DisplayName','Small Room');

plot(ax,snr_list,SNR_medium,...
    '--s','LineWidth',2.5,'MarkerSize',10,...
    'DisplayName','Medium Room');

plot(ax,snr_list,SNR_large,...
    '-^','LineWidth',2.5,'MarkerSize',10,...
    'DisplayName','Large Room');

grid(ax,'on')
box(ax,'on')

ax.FontSize = 14;
ax.FontWeight = 'bold';
ax.LineWidth = 1.5;

ax.XLim = [-10 20];
ax.XTick = snr_list;

ax.YLim = [floor(min([SNR_small SNR_medium SNR_large]))-1,...
           ceil(max([SNR_small SNR_medium SNR_large]))+1];

xlabel(ax,'Input SNR (dB)',...
    'FontSize',15,...
    'FontWeight','bold')

ylabel(ax,'Output SNR (dB)',...
    'FontSize',15,...
    'FontWeight','bold')

title(ax,'Output SNR vs Input SNR',...
    'FontSize',16,...
    'FontWeight','bold')

lgd = legend(ax,...
    {'Small Room','Medium Room','Large Room'},...
    'Location','northwest');

lgd.FontSize = 12;
lgd.Box = 'on';

% Save the figure
savefig(fig,...
    fullfile(metricsplot_folder,...
    'SNRout_vs_InputSNR.fig'));

close(fig);