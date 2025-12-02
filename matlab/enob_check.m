% enob_check_multi_bit.m
clear; clc;

% Load multi-bit output
if exist('analog_out.mem', 'file')
    fprintf('Loading analog output...\n');
    x = load('analog_out.mem');
elseif exist('bitstream_multi.mem', 'file')
    fprintf('Loading multi-bit indices, converting to analog...\n');
    indices = load('bitstream_multi.mem');
    
    % Convert indices to analog values
    nbits = 4;
    nlevels = 2^nbits;
    q_step = 2/(nlevels-1);
    
    x = indices * q_step - 1;  % Convert to range [-1, 1]
else
    error('No output file found. Run multi_bit_sigma_delta.m first.');
end

% Parameters (must match modulator)
OSR = 64;                    % Oversampling ratio
Fs_target = 1000;            % Output sampling rate
Fs_high = Fs_target * OSR;   % High sampling rate (64 kHz)
f_sig = 30.123;              % Signal frequency

N = length(x);
fprintf('Processing %d samples at %.1f kHz\n', N, Fs_high/1000);

%% Method 1: Decimation with proper anti-aliasing filter
dec_factor = OSR;

% Design a decimation filter
taps = 101;  % Number of filter taps
cutoff_freq = 0.9 * (Fs_target/2) / (Fs_high/2);  % Normalized cutoff

% FIR low-pass filter for decimation
h = fir1(taps-1, cutoff_freq);

% Apply filter
filtered = filter(h, 1, x);

% Decimate (skip initial transient)
start_idx = taps;  % Skip filter transient
decimated = filtered(start_idx:dec_factor:end);

% Remove any remaining DC
decimated = decimated - mean(decimated);

%% Method 2: Advanced ENOB calculation with windowing
N_dec = length(decimated);
fprintf('After decimation: %d samples at %d Hz\n', N_dec, Fs_target);

% Use a high-performance window (Chebyshev or Kaiser)
window = kaiser(N_dec, 10)';  % Beta = 10 for good side lobe suppression
x_windowed = decimated .* window;

% FFT
NFFT = 2^nextpow2(N_dec);
X = fft(x_windowed, NFFT);
Pxx = (abs(X(1:NFFT/2)).^2) / (sum(window.^2));
f = (0:NFFT/2-1) * (Fs_target/NFFT);

% Find signal bin
[~, sig_bin] = min(abs(f - f_sig));

% Calculate noise floor using multiple methods
fprintf('\n=== ENOB Calculation Methods ===\n');

% Method A: Traditional signal vs noise bins
sig_bins = max(sig_bin-5, 1):min(sig_bin+5, length(Pxx));
signal_power = sum(Pxx(sig_bins));

noise_bins = setdiff(2:length(Pxx), sig_bins);  % Exclude DC
noise_power = sum(Pxx(noise_bins));

SNR_A = 10*log10(signal_power / noise_power);
ENOB_A = (SNR_A - 1.76) / 6.02;

fprintf('Method A (Traditional):\n');
fprintf('  Signal power: %.2e\n', signal_power);
fprintf('  Noise power: %.2e\n', noise_power);
fprintf('  SNR: %.2f dB\n', SNR_A);
fprintf('  ENOB: %.2f bits\n', ENOB_A);

% Method B: Using noise floor estimation (more accurate)
noise_floor = median(Pxx(noise_bins));  % Median is robust to outliers
effective_noise_power = noise_floor * length(noise_bins);
SNR_B = 10*log10(signal_power / effective_noise_power);
ENOB_B = (SNR_B - 1.76) / 6.02;

fprintf('\nMethod B (Noise floor estimation):\n');
fprintf('  Noise floor: %.2e\n', noise_floor);
fprintf('  Effective noise power: %.2e\n', effective_noise_power);
fprintf('  SNR: %.2f dB\n', SNR_B);
fprintf('  ENOB: %.2f bits\n', ENOB_B);

% Method C: Using multi-tone analysis (if available)
% For single tone, calculate THD+N
harmonic_bins = [];
for h = 2:5  % Look at 2nd to 5th harmonics
    harm_freq = f_sig * h;
    if harm_freq <= Fs_target/2
        [~, harm_bin] = min(abs(f - harm_freq));
        harmonic_bins = [harmonic_bins, max(harm_bin-2,1):min(harm_bin+2,length(Pxx))];
    end
end

% Signal + harmonics power
all_sig_bins = union(sig_bins, harmonic_bins);
total_signal_power = sum(Pxx(all_sig_bins));

% Noise (everything else)
total_noise_bins = setdiff(2:length(Pxx), all_sig_bins);
total_noise_power = sum(Pxx(total_noise_bins));

SNR_C = 10*log10(total_signal_power / total_noise_power);
ENOB_C = (SNR_C - 1.76) / 6.02;

fprintf('\nMethod C (Including harmonics):\n');
fprintf('  Total signal+harmonics power: %.2e\n', total_signal_power);
fprintf('  Total noise power: %.2e\n', total_noise_power);
fprintf('  SNR: %.2f dB\n', SNR_C);
fprintf('  ENOB: %.2f bits\n', ENOB_C);

%% Dynamic Range calculation (for ADC characterization)
% Estimate noise floor in dBFS/Hz
noise_density = 10*log10(noise_floor / (Fs_target/2));
fprintf('\n=== Dynamic Range Estimation ===\n');
fprintf('Noise density: %.1f dBFS/Hz\n', noise_density);
fprintf('Dynamic range: %.1f dB\n', -noise_density + 10*log10(Fs_target/2));

%% Plot results
figure('Position', [100, 100, 1200, 600]);

% Spectrum of decimated signal
subplot(1,3,1);
plot(f, 10*log10(Pxx));
xlabel('Frequency (Hz)');
ylabel('PSD (dBFS/Hz)');
title('Spectrum after Decimation');
xlim([0 Fs_target/2]);
grid on;
hold on;
plot([f_sig, f_sig], ylim, 'g--', 'LineWidth', 1.5);
hold off;

% Zoom around signal
subplot(1,3,2);
zoom_range = 5;  % Hz
zoom_idx = (f >= f_sig-zoom_range) & (f <= f_sig+zoom_range);
plot(f(zoom_idx), 10*log10(Pxx(zoom_idx)));
xlabel('Frequency (Hz)');
ylabel('PSD (dBFS/Hz)');
title(sprintf('Zoom around %.3f Hz', f_sig));
grid on;

% Histogram of quantization error (if we have input signal)
subplot(1,3,3);
if exist('u', 'var')
    % Reconstruct quantization error
    % Note: This requires the original input signal
    error_signal = decimated - u(1:dec_factor:end);
    histogram(error_signal, 100);
    xlabel('Quantization Error');
    ylabel('Count');
    title('Histogram of Quantization Error');
    grid on;
else
    % Plot histogram of decimated signal instead
    histogram(decimated, 100);
    xlabel('Amplitude');
    ylabel('Count');
    title('Histogram of Decimated Output');
    grid on;
end