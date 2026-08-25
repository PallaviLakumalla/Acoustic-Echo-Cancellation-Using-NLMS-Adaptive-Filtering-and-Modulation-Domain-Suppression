function w = nlms_train_weights(x,d,mu,M)

% Convert the input signals to column vectors
x = x(:);
d = d(:);

%% Initialize variables

% Signal length
N = length(x);

% Initialize the filter coefficients
w = zeros(M,1);

% Small constant to avoid division by zero
delta = 1e-6;

%% Train the NLMS filter

for n = M:N

    % Create the reference input vector
    xvec = x(n:-1:n-M+1);

    % Estimate the echo signal
    yhat = w' * xvec;

    % Calculate the estimation error
    e = d(n) - yhat;

    % Calculate the input signal power
    normx = xvec' * xvec + delta;

    % Update the filter coefficients
    w = w + (mu / normx) * e * xvec;

end

end