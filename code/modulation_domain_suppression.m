function s_hat = modulation_domain_suppression(e,fs)

% Convert the input signal to a column vector
e = e(:);

%% STFT parameters

N = 1024;
hop = 512;

win = hamming(N,'periodic');

%% Compute STFT

[S,~,~] = stft(e,fs,...
    'Window',win,...
    'OverlapLength',N-hop,...
    'FFTLength',N);

Mag = abs(S);
Phase = angle(S);

[numFreq,numFrames] = size(Mag);

%% Estimate noise power

initFrames = min(10,numFrames);

NoisePSD_init = mean(Mag(:,1:initFrames).^2,2);

NoisePSD = repmat(NoisePSD_init,1,numFrames);

lambda = 0.98;

for k = 2:numFrames

    currentPSD = Mag(:,k).^2;

    NoisePSD(:,k) = ...
        lambda*NoisePSD(:,k-1) + ...
        (1-lambda)*min(currentPSD,...
                       2*NoisePSD(:,k-1));

end

%% Calculate a-posteriori SNR

gamma = Mag.^2 ./ (NoisePSD + eps);

gamma = min(gamma,100);

%% Estimate a-priori SNR

xi = zeros(size(gamma));

xi(:,1) = max(gamma(:,1)-1,0);

Gain_prev = ones(numFreq,1);

alpha = 0.90;

for k = 2:numFrames

    xi(:,k) = ...
        alpha*(Gain_prev.^2).*gamma(:,k-1) + ...
        (1-alpha)*max(gamma(:,k)-1,0);

    xi(:,k) = max(xi(:,k),0);

    Gain_prev = xi(:,k)./(1+xi(:,k));

end

%% Calculate Wiener gain

Gain = xi./(1+xi);

%% Speech presence probability

% Disabled to preserve the desired speech after NLMS.

% q = 0.5;
%
% phi = (1./(1+xi)).*exp((gamma.*xi)./(1+xi));
%
% pH0 = 1./(1+q.*phi);
%
% Gain = Gain.*(1-pH0);

%% Smooth the gain

Gain = movmean(Gain,5,2);

%% Apply gain limits

Gain = max(Gain,0.65);

Gain = min(Gain,1.0);

%% Reconstruct the signal

Srec = Gain.*Mag.*exp(1i*Phase);

s_hat = istft(Srec,fs,...
    'Window',win,...
    'OverlapLength',N-hop,...
    'FFTLength',N);

%% Return enhanced signal

s_hat = real(s_hat(:));

end