% multi_bit_sigma_delta.m
clear; close all; clc;

%% Parameters for 20+ bits ENOB
Fs_target = 1000;          % Output sampling rate
OSR = 64;                 % Much lower OSR needed with multi-bit
Fs = Fs_target * OSR;     % 64 kHz sampling rate
N = 2^18;                 % 262,144 samples

% Quantizer parameters
nbits = 4;                % 4-bit quantizer (16 levels)
nlevels = 2^nbits;        % Number of quantization levels
q_step = 2/(nlevels-1);   % Step size between levels

% Input signal
amp = 0.9;                % Can use higher amplitude
f_sig = 30.123;           % Non-integer frequency

%% Generate input signal
t = (0:N-1)/Fs;
u = amp * sin(2*pi*f_sig*t);
u = u - mean(u);          % Remove DC

%% 4th-order CIFB SDM with 4-bit quantizer
% Optimized coefficients for 4-bit quantizer
b = [0.25; 0.5; 0.75; 1.0];
a = [0.5; 0.5; 0.5];

% Initialize state variables
v = zeros(4, 1);
q_out = zeros(1, N);        % Quantized output (0 to 15)
analog_out = zeros(1, N);   % Analog equivalent (-1 to 1)

fprintf('Running 4th-order sigma-delta with %d-bit quantizer...\n', nbits);

% Main SDM loop
for n = 1:N
    % Loop filter
    v(1) = v(1) + (u(n) - analog_out(max(n-1,1)));
    v(2) = v(2) + b(1)*v(1) - a(1)*analog_out(max(n-1,1));
    v(3) = v(3) + b(2)*v(2) - a(2)*analog_out(max(n-1,1));
    v(4) = v(4) + b(3)*v(3) - a(3)*analog_out(max(n-1,1));
    
    % 4-bit mid-rise quantizer
    % Scale to [-1, 1] range
    input_quant = v(4);
    
    % Ensure input is within range
    input_quant = max(-1, min(1, input_quant));
    
    % Quantize
    q_index = round((input_quant + 1) / q_step);
    q_index = max(0, min(nlevels-1, q_index));
    
    q_out(n) = q_index;
    
    % Convert back to analog value for feedback
    analog_out(n) = q_index * q_step - 1;
end

%% Save outputs
% Save the quantized indices (0 to 15)
fid = fopen('bitstream_multi.mem', 'w');
fprintf(fid, '%d\n', q_out);
fclose(fid);

% Also save analog values for analysis
fid = fopen('analog_out.mem', 'w');
fprintf(fid, '%.6f\n', analog_out);
fclose(fid);

fprintf('Saved %d samples to bitstream_multi.mem\n', N);
fprintf('Quantizer: %d-bit, %d levels, step size: %.4f\n', nbits, nlevels, q_step);

%% Direct ENOB measurement (no decimation needed)
fprintf('\n=== Direct ENOB Measurement ===\n');

% Use analog output for analysis
x = analog_out;

% Apply windowing for spectral analysis
Nfft = 2^17;  % 131072 points for FFT
if N > Nfft
    x_short = x(1:Nfft);
else
    x_short = x;
end

win = hann(length(x_short))';
x_windowed = x_short .* win;

% FFT
X = fft(x_windowed, Nfft);
P = abs(X(1:Nfft/2)).^2 / (sum(win.^2));
freq = (0:Nfft/2-1) * (Fs/Nfft);

% Find signal bin
[~, sig_bin] = min(abs(freq - f_sig));

% Signal power (include main lobe)
sig_bins = max(sig_bin-10, 1):min(sig_bin+10, length(P));
signal_power = sum(P(sig_bins));

% Noise power in band (exclude DC and signal)
inband = find(freq <= Fs_target/2);
noise_bins = setdiff(inband, [1, sig_bins]);  % Exclude DC and signal
noise_power = sum(P(noise_bins));

if noise_power > 0
    SNR = 10*log10(signal_power / noise_power);
    ENOB = (SNR - 1.76) / 6.02;
    
    fprintf('OSR: %d\n', OSR);
    fprintf('Quantizer bits: %d\n', nbits);
    fprintf('Signal frequency: %.3f Hz\n', f_sig);
    fprintf('Signal power: %.2e\n', signal_power);
    fprintf('Noise power: %.2e\n', noise_power);
    fprintf('SNR: %.2f dB\n', SNR);
    fprintf('ENOB: %.2f bits\n', ENOB);
else
    fprintf('Error: Noise power is zero or negative.\n');
end

%% Plot results
figure('Position', [100, 100, 1200, 800]);

% Time domain (first 200 samples)
subplot(2,2,1);
plot(t(1:200)*1000, u(1:200), 'b-', 'LineWidth', 1.5);
hold on;
stairs(t(1:200)*1000, analog_out(1:200), 'r-', 'LineWidth', 1);
xlabel('Time (ms)');
ylabel('Amplitude');
title('Time Domain: Input (blue) vs Output (red)');
legend('Input', 'SDM Output');
grid on;

% Histogram of quantizer output
subplot(2,2,2);
histogram(analog_out, 50);
xlabel('Output Value');
ylabel('Count');
title(sprintf('Histogram of %d-bit Quantizer Output', nbits));
grid on;

% Spectrum
subplot(2,2,3);
semilogx(freq, 10*log10(P));
xlabel('Frequency (Hz)');
ylabel('PSD (dB)');
title('Output Spectrum');
xlim([1 Fs/2]);
grid on;
hold on;
plot([Fs_target/2, Fs_target/2], ylim, 'r--', 'LineWidth', 1.5);
hold off;

% In-band spectrum
subplot(2,2,4);
inband_idx = freq <= Fs_target/2;
plot(freq(inband_idx), 10*log10(P(inband_idx)));
xlabel('Frequency (Hz)');
ylabel('PSD (dB)');
title('In-band Spectrum (0-500 Hz)');
grid on;
hold on;
plot([f_sig, f_sig], ylim, 'g--', 'LineWidth', 1.5);
hold off;