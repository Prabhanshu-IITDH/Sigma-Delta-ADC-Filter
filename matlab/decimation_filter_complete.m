%% Multi-Stage Decimation Filter Design
% Requirements:
% - Input: 5-bit signed stream
% - Output ENOB: > 18 bits
% - Nyquist Frequency: 1 kHz (Fs_out = 2 kHz)
% - Filter Types: CIC, FIR, Half-Band

close all;


%% System Parameters
% Input specifications
input_bits = 5;
input_levels = 2^(input_bits-1);  % Signed: -16 to +15

% Output specifications
target_ENOB = 18;
f_nyquist = 1e3;  % 1 kHz
Fs_out = 2 * f_nyquist;  % Output sampling rate: 2 kHz

% Input sampling rate (as specified)
Fs_in = 128e3;  % 128 kHz

% Calculate required decimation factor
R_total = Fs_in / Fs_out;  % 128000 / 2000 = 64

% Decimation stages to achieve R_total = 64
R_CIC = 8;      % CIC decimation factor
R_FIR = 2;      % FIR decimation factor
R_HB1 = 2;      % First Half-Band decimation
R_HB2 = 2;      % Second Half-Band decimation

% Verify total decimation
calculated_R_total = R_CIC * R_FIR * R_HB1 * R_HB2;
if calculated_R_total ~= R_total
    error('Decimation stages do not match required total: %d vs %d', calculated_R_total, R_total);
end

fprintf('=== Decimation Filter System ===\n');
fprintf('Input Sampling Rate: %.1f kHz\n', Fs_in/1e3);
fprintf('Output Sampling Rate: %.1f kHz\n', Fs_out/1e3);
fprintf('Total Decimation Factor: %d\n', R_total);
fprintf('CIC Decimation: %d\n', R_CIC);
fprintf('FIR Decimation: %d\n', R_FIR);
fprintf('HB1 Decimation: %d\n', R_HB1);
fprintf('HB2 Decimation: %d\n\n', R_HB2);

%% Load 5-bit Signed Input Stream from File
fprintf('Loading input stream from file...\n');

% Load the input file
input_stream = load('input_stream1.txt');

fprintf('Successfully loaded %d samples\n', length(input_stream));

% Validate 5-bit range
if max(input_stream) > (input_levels-1) || min(input_stream) < -input_levels
    fprintf('Warning: Input values outside 5-bit signed range [-16 to 15], clipping...\n');
    input_stream = max(min(input_stream, input_levels-1), -input_levels);
end

% Ensure input length is compatible with total decimation factor
samples_needed = ceil(length(input_stream) / R_total) * R_total;
if length(input_stream) < samples_needed
    % Pad with zeros if needed
    original_length = length(input_stream);
    input_stream = [input_stream; zeros(samples_needed - length(input_stream), 1)];
    fprintf('Padded input stream from %d to %d samples\n', original_length, samples_needed);
elseif length(input_stream) > samples_needed
    % Truncate to nearest multiple
    original_length = length(input_stream);
    input_stream = input_stream(1:samples_needed);
    fprintf('Truncated input stream from %d to %d samples\n', original_length, samples_needed);
end

% Ensure input_stream is a column vector
input_stream = input_stream(:);

%{
fprintf('Input signal statistics:\n');
fprintf('  Length: %d samples\n', length(input_stream));
fprintf('  Min: %d, Max: %d\n', min(input_stream), max(input_stream));
fprintf('  Mean: %.2f, Std: %.2f\n\n', mean(input_stream), std(input_stream));
%}

%% Stage 1: CIC Filter
fprintf('Stage 1: CIC Filter (R=%d)\n', R_CIC);

% CIC parameters
N_stages = 15;  % Number of CIC stages (order)
M = 1;         % Differential delay

% Design CIC decimator
hcic = dsp.CICDecimator(R_CIC, M, N_stages);

% Process through CIC
cic_out = double(hcic(int32(input_stream)));

% Calculate CIC gain
CIC_gain = (R_CIC * M)^N_stages;
fprintf('  CIC Gain: %d (%.1f dB)\n', CIC_gain, 20*log10(CIC_gain));
fprintf('  Output samples: %d\n', length(cic_out));

% Update sampling rate
Fs_cic = Fs_in / R_CIC;

%% Stage 2: Compensating FIR Filter with Decimation
fprintf('\nStage 2: FIR Compensation Filter (R=%d)\n', R_FIR);

% Design FIR filter to compensate CIC droop
% Use equiripple design
Fpass = 0.4 / R_FIR;  % Passband edge (normalized)
Fstop = 0.5 / R_FIR;  % Stopband edge
Apass = 0.1;          % Passband ripple (dB)
Astop = 80;           % Stopband attenuation (dB)

% Design the filter
fir_order = 25;
f_edges = [0 Fpass Fstop 1];
a_desired = [1 1 0 0];

% Add inverse sinc compensation for CIC droop
weights = [10 1];  % Weight passband more

fir_coeffs = firpm(fir_order, f_edges, a_desired, weights);

% Apply FIR filter with decimation
fir_out = filter(fir_coeffs, 1, cic_out);
fir_out = fir_out(1:R_FIR:end);  % Decimate

fprintf('  FIR Order: %d\n', fir_order);
fprintf('  Output samples: %d\n', length(fir_out));

% Update sampling rate
Fs_fir = Fs_cic / R_FIR;

%% Stage 3: First Half-Band Filter
fprintf('\nStage 3: Half-Band Filter 1 (R=%d)\n', R_HB1);

% Design half-band filter (order must be even)
% Use higher order for better convergence
hb1_order = 6;
hb1_coeffs = firhalfband(hb1_order, 0.25);  % Relaxed transition width

% Apply filter with decimation
hb1_out = filter(hb1_coeffs, 1, fir_out);
hb1_out = hb1_out(1:R_HB1:end);  % Decimate

fprintf('  Half-Band Order: %d\n', hb1_order);
fprintf('  Output samples: %d\n', length(hb1_out));

% Update sampling rate
Fs_hb1 = Fs_fir / R_HB1;

%% Stage 4: Second Half-Band Filter
fprintf('\nStage 4: Half-Band Filter 2 (R=%d)\n', R_HB2);

% Design second half-band filter (order must be even)
% Use higher order for better convergence
hb2_order = 6;
hb2_coeffs = firhalfband(hb2_order, 0.25);  % Relaxed transition width

% Apply filter with decimation
hb2_out = filter(hb2_coeffs, 1, hb1_out);
output_stream = hb2_out(1:R_HB2:end);  % Decimate

fprintf('  Half-Band Order: %d\n', hb2_order);
fprintf('  Output samples: %d\n\n', length(output_stream));

% Update sampling rate
Fs_final = Fs_hb1 / R_HB2;

%% Calculate Output ENOB
%{
Remove transient samples
transient_samples = 100;
if length(output_stream) > transient_samples
    output_steady = output_stream(transient_samples+1:end);
else
    output_steady = output_stream;
    transient_samples = 0;
end
t_out = (0:length(output_steady)-1) / Fs_final;

% Calculate Signal and Noise
% For unknown input signals, estimate SNR from spectrum
NFFT = 2^nextpow2(length(output_steady));
Y = fft(output_steady, NFFT);
Pyy = abs(Y).^2 / length(output_steady);
f = Fs_final * (0:(NFFT/2)) / NFFT;

% Find peaks in spectrum (signal components)
Pyy_half = Pyy(1:NFFT/2+1);
[pks, locs] = findpeaks(Pyy_half, 'MinPeakHeight', max(Pyy_half)/100, 'NPeaks', 10);

% Signal power (sum of significant peaks with surrounding bins)
signal_power = 0;
bin_width = 3;
for i = 1:length(locs)
    idx_start = max(1, locs(i) - bin_width);
    idx_end = min(length(Pyy_half), locs(i) + bin_width);
    signal_power = signal_power + sum(Pyy(idx_start:idx_end));
end

% Total power
total_power = sum(Pyy(1:NFFT/2));

% Noise power
noise_power = max(total_power - signal_power, eps);  % Avoid division by zero

% SNR and ENOB
SNR_dB = 10*log10(signal_power / noise_power);
ENOB = (SNR_dB - 1.76) / 6.02;

fprintf('=== Output Performance ===\n');
fprintf('Actual Output Fs: %.1f kHz\n', Fs_final/1e3);
fprintf('Nyquist Frequency: %.1f kHz\n', Fs_final/2e3);
fprintf('Signal Power: %.2f dB\n', 10*log10(signal_power));
fprintf('Noise Power: %.2f dB\n', 10*log10(noise_power));
fprintf('SNR: %.2f dB\n', SNR_dB);
fprintf('ENOB: %.2f bits\n', ENOB);

if ENOB > target_ENOB
    fprintf('✓ ENOB requirement MET (%.2f > %d bits)\n\n', ENOB, target_ENOB);
else
    fprintf('✗ ENOB requirement NOT MET (%.2f < %d bits)\n\n', ENOB, target_ENOB);
end

%% Display Output Stream Statistics
fprintf('=== Output Stream ===\n');
fprintf('Length: %d samples\n', length(output_stream));
fprintf('Min: %.6f, Max: %.6f\n', min(output_stream), max(output_stream));
fprintf('Mean: %.6f, Std: %.6f\n', mean(output_stream), std(output_stream));
fprintf('Bit depth (by range): %.2f bits\n\n', log2(max(output_stream)-min(output_stream)));
%}

% Store output in a clearly named variable for easy access
final_output_stream = output_stream;

% Display the complete output stream in command window
%fprintf('=== COMPLETE OUTPUT STREAM (All %d samples) ===\n', length(final_output_stream));
%fprintf('Sample#\t\tValue\n');
%fprintf('-------\t\t-----------\n');
%for i = 1:length(final_output_stream)
%    fprintf('%d\t\t%.8f\n', i, final_output_stream(i));
%end
%fprintf('\n=== End of Output Stream ===\n\n');

%% Plotting
%{
figure('Position', [100 100 1200 900]);

% Input signal (time domain)
subplot(4,2,1);
t_in = (0:length(input_stream)-1) / Fs_in;
plot(t_in(1:min(1000,length(input_stream)))*1e3, input_stream(1:min(1000,length(input_stream))));
grid on;
xlabel('Time (ms)');
ylabel('Amplitude');
title('Input: 5-bit Signed Stream (First 1000 samples)');

% Input spectrum
subplot(4,2,2);
[Pxx, F] = pwelch(input_stream, [], [], [], Fs_in);
plot(F/1e3, 10*log10(Pxx));
grid on;
xlabel('Frequency (kHz)');
ylabel('Power (dB)');
title('Input Spectrum');
xlim([0 Fs_in/2e3]);

% CIC output
subplot(4,2,3);
plot((0:length(cic_out)-1)/Fs_cic*1e3, cic_out);
grid on;
xlabel('Time (ms)');
ylabel('Amplitude');
title(sprintf('After CIC (Fs=%.1f kHz)', Fs_cic/1e3));

% CIC spectrum
subplot(4,2,4);
[Pxx, F] = pwelch(cic_out, [], [], [], Fs_cic);
plot(F/1e3, 10*log10(Pxx));
grid on;
xlabel('Frequency (kHz)');
ylabel('Power (dB)');
title('CIC Output Spectrum');
xlim([0 Fs_cic/2e3]);

% FIR output
subplot(4,2,5);
plot((0:length(fir_out)-1)/Fs_fir*1e3, fir_out);
grid on;
xlabel('Time (ms)');
ylabel('Amplitude');
title(sprintf('After FIR (Fs=%.1f kHz)', Fs_fir/1e3));

% FIR spectrum
subplot(4,2,6);
[Pxx, F] = pwelch(fir_out, [], [], [], Fs_fir);
plot(F/1e3, 10*log10(Pxx));
grid on;
xlabel('Frequency (kHz)');
ylabel('Power (dB)');
title('FIR Output Spectrum');
xlim([0 Fs_fir/2e3]);

% Final output
subplot(4,2,7);
plot(t_out(1:min(500,length(t_out)))*1e3, output_steady(1:min(500,length(t_out))));
grid on;
xlabel('Time (ms)');
ylabel('Amplitude');
title(sprintf('Final Output (Fs=%.1f kHz)', Fs_final/1e3));

% Final spectrum
subplot(4,2,8);
[Pxx, F] = pwelch(output_steady, [], [], [], Fs_final);
plot(F, 10*log10(Pxx));
grid on;
xlabel('Frequency (Hz)');
ylabel('Power (dB)');
title(sprintf('Final Spectrum (ENOB=%.2f bits)', ENOB));
xlim([0 f_nyquist]);

sgtitle('Multi-Stage Decimation Filter System');

%% Frequency Response of Each Filter Stage
figure('Position', [100 100 1200 600]);

% CIC Response
subplot(2,2,1);
[H_cic, W_cic] = freqz(ones(1,N_stages), 1, 2048, Fs_in);
H_cic_cascade = H_cic.^N_stages ./ (R_CIC^N_stages);
for k = 1:N_stages
    H_cic_cascade = H_cic_cascade .* sinc(W_cic*R_CIC/(2*pi*Fs_in));
end
plot(W_cic/1e3, 20*log10(abs(H_cic_cascade)));
grid on;
xlabel('Frequency (kHz)');
ylabel('Magnitude (dB)');
title('CIC Filter Response');
ylim([-100 10]);

% FIR Response
subplot(2,2,2);
[H_fir, W_fir] = freqz(fir_coeffs, 1, 2048, Fs_cic);
plot(W_fir/1e3, 20*log10(abs(H_fir)));
grid on;
xlabel('Frequency (kHz)');
ylabel('Magnitude (dB)');
title('FIR Compensation Filter Response');
ylim([-100 10]);

% Half-Band 1 Response
subplot(2,2,3);
[H_hb1, W_hb1] = freqz(hb1_coeffs, 1, 2048, Fs_fir);
plot(W_hb1/1e3, 20*log10(abs(H_hb1)));
grid on;
xlabel('Frequency (kHz)');
ylabel('Magnitude (dB)');
title('Half-Band Filter 1 Response');
ylim([-100 10]);

% Half-Band 2 Response
subplot(2,2,4);
[H_hb2, W_hb2] = freqz(hb2_coeffs, 1, 2048, Fs_hb1);
plot(W_hb2, 20*log10(abs(H_hb2)));
grid on;
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
title('Half-Band Filter 2 Response');
ylim([-100 10]);

sgtitle('Individual Filter Stage Frequency Responses');

fprintf('Decimation filter design complete!\n');
%}