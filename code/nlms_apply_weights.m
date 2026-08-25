function [e,d_hat] = nlms_apply_weights(x,y,w)

% Convert the input signals to column vectors
x = x(:);
y = y(:);

%% Initialize variables

% Filter length
M = length(w);

% Signal length
N = length(y);

% Allocate memory for estimated echo and residual signal
d_hat = zeros(N,1);
e = zeros(N,1);

%% Apply the trained NLMS filter

for n = M:N

    % Create the reference input vector
    xvec = x(n:-1:n-M+1);

    % Estimate the echo signal
    d_hat(n) = w' * xvec;

    % Calculate the residual signal
    e(n) = y(n) - d_hat(n);

end

end