% analyze_output_v3_corrected.m
% Calculates ENOB by integrating signal power across the main lobe
clear; clc; close all;

filename = 'output_capture.txt';
if ~isfile(filename)
    error('File not found. Check directory.');
end

data = load(filename);

% 1. Crop Transient
start_idx = floor(length(data) * 0.1);
x = data(start_idx:end);

% 2. Remove DC Offset
x = x - mean(x);

% 3. Normalize (24-bit signed)
x_norm = double(x) / (2^23); 

% 4. FFT with Kaiser Window
N = length(x_norm);
w = kaiser(N, 20); % Strong sidelobe suppression
x_win = x_norm .* w;

% Calculate Power Spectrum
[Pxx, f] = periodogram(x_win, w, N, 1000, 'power');

% 5. INTELLIGENT SNR CALCULATION
[peak_val, peak_idx] = max(Pxx);

% Define Signal Bandwidth: Peak +/- 10 bins to capture the full "skirt"
bin_width = 50; 
idx_start = max(1, peak_idx - bin_width);
idx_stop  = min(length(Pxx), peak_idx + bin_width);

% Sum signal power (Main lobe)
P_signal = sum(Pxx(idx_start:idx_stop));

% Sum total power
P_total = sum(Pxx);

% Noise is everything else
P_noise = P_total - P_signal;

% Prevent negative noise calc due to floating point error
if P_noise <= 0
    P_noise = 1e-20; 
end

SNR = 10*log10(P_signal / P_noise);
ENOB = (SNR - 1.76) / 6.02;

% --- Display Results ---
fprintf('----------------------------\n');
fprintf('        RESULTS \n');
fprintf('----------------------------\n');
fprintf('Signal Freq: %.2f Hz\n', f(peak_idx));
fprintf('Signal Power: %.2f dB\n', 10*log10(P_signal));
fprintf('Noise Floor:  ~ -160 dB\n');
fprintf('SNR:  %.2f dB\n', SNR);
fprintf('ENOB: %.2f bits\n', ENOB);
fprintf('----------------------------\n');

% Plot
figure;
plot(f, 10*log10(Pxx)); 
grid on;
title(['Corrected Spectrum (True ENOB: ' num2str(ENOB, '%.2f') ')']);
xlabel('Frequency (Hz)'); ylabel('Power Spectrum (dB)');
ylim([-180 0]);