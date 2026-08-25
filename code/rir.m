function h = rir(fs,mic_pos,refl_order,rt60,room_dim,src_pos)

% Speed of sound (m/s)
c = 343;

%% Room parameters

% Room volume
V = prod(room_dim);

% Total surface area
S = 2 * ( ...
    room_dim(1)*room_dim(2) + ...
    room_dim(1)*room_dim(3) + ...
    room_dim(2)*room_dim(3));

%% Calculate absorption coefficient

alpha = ...
    24*log(10)*V / ...
    (c*S*rt60);

%% Initialize RIR

% Impulse response length
N = ceil(rt60 * fs);

h = zeros(N,1);

%% Generate direct path

dist = norm(src_pos - mic_pos);

delay = round(dist/c * fs);

if delay < N

    h(delay+1) = 1/(dist + eps);

end

%% Generate image source reflections

for nx = -refl_order:refl_order

    for ny = -refl_order:refl_order

        for nz = -refl_order:refl_order

            % Skip the direct path
            if nx==0 && ny==0 && nz==0
                continue
            end

            % Calculate image source position
            image = src_pos;

            image(1) = ...
                (-1)^nx * src_pos(1) + ...
                2 * nx * room_dim(1);

            image(2) = ...
                (-1)^ny * src_pos(2) + ...
                2 * ny * room_dim(2);

            image(3) = ...
                (-1)^nz * src_pos(3) + ...
                2 * nz * room_dim(3);

            % Calculate reflection delay
            dist_img = norm(image - mic_pos);

            delay_img = round(dist_img/c * fs);

            if delay_img < N

                order = abs(nx) + abs(ny) + abs(nz);

                reflection_gain = ...
                    (alpha^order) / (dist_img + eps);

                h(delay_img+1) = ...
                    h(delay_img+1) + reflection_gain;

            end

        end

    end

end

%% Apply reverberation decay

t = (0:N-1)' / fs;

decay = exp(-6.91 * t / rt60);

h = h .* decay;

%% Normalize the impulse response

h = h / (norm(h) + eps);

h = h / (max(abs(h)) + eps);

end